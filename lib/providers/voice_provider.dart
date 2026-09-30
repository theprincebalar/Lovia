import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/emotion_state.dart';
import '../models/message.dart';
import '../models/mood.dart';
import '../models/relationship.dart';
import '../models/scenario.dart';
import '../services/gemini_ai_service.dart';
import '../services/roleplay_ai_engine.dart';
import '../services/storage_service.dart';
import '../services/voice_service.dart';
import 'coin_provider.dart';
import 'chat_provider.dart';

class VoiceProvider extends ChangeNotifier {
  final VoiceService _voiceService;
  final CoinProvider _coinProvider;
  final StorageService? _storageService;
  ChatProvider? _chatProvider;

  Character? _activeCharacter;
  Scenario? _activeScenario;
  MoodType? _activeMood;
  EmotionState _currentEmotion = EmotionState.happy;
  VoiceCallStatus _status = VoiceCallStatus.idle;
  bool _isMuted = false;
  bool _isCallActive = false;
  String _liveTranscript = "";
  String _characterSpokenText = "";
  Timer? _waveformTimer;
  Timer? _speechSilenceTimer;
  Timer? _errorDismissTimer;
  Timer? _callDurationTimer;
  int _callDurationSeconds = 0;
  bool _isUsingSubscriptionMinutes = false;
  bool _isUserSpeaking = false;
  Timer? _userSpeakingDebounceTimer;
  List<double> _visualizerFrequencies = List.filled(24, 0.05);
  final Random _rng = Random();
  String? _errorMessage;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _speakingSubscription;

  VoiceProvider({
    required VoiceService voiceService,
    required CoinProvider coinProvider,
    StorageService? storageService,
    ChatProvider? chatProvider,
  })  : _voiceService = voiceService,
        _coinProvider = coinProvider,
        _storageService = storageService,
        _chatProvider = chatProvider {
    _errorSubscription = _voiceService.errorMessageStream.listen((msg) {
      _errorMessage = msg;
      notifyListeners();
      _errorDismissTimer?.cancel();
      _errorDismissTimer = Timer(const Duration(seconds: 6), () {
        _errorMessage = null;
        notifyListeners();
      });
    });

    _speakingSubscription = _voiceService.speakingStateStream.listen((_) {
      notifyListeners();
    });
  }

  void _markUserSpeaking() {
    if (!_isUserSpeaking) {
      _isUserSpeaking = true;
      notifyListeners();
    }
    _userSpeakingDebounceTimer?.cancel();
    _userSpeakingDebounceTimer = Timer(const Duration(milliseconds: 700), () {
      if (_isUserSpeaking) {
        _isUserSpeaking = false;
        notifyListeners();
      }
    });
  }

  void _clearUserSpeaking() {
    _userSpeakingDebounceTimer?.cancel();
    if (_isUserSpeaking) {
      _isUserSpeaking = false;
      notifyListeners();
    }
  }

  Character? get activeCharacter => _activeCharacter;
  EmotionState get currentEmotion => _currentEmotion;
  VoiceCallStatus get status => _status;
  bool get isMuted => _isMuted;
  bool get isCallActive => _isCallActive;
  String get liveTranscript => _liveTranscript;
  String get characterSpokenText => _characterSpokenText;
  List<double> get visualizerFrequencies => _visualizerFrequencies;
  String? get errorMessage => _errorMessage;
  bool get isSttAvailable => _voiceService.isSttAvailable;
  bool get hasMicPermission => _voiceService.hasMicPermission;
  int get callDurationSeconds => _callDurationSeconds;
  int get callDurationMinutes => _callDurationSeconds ~/ 60;
  bool get isUsingSubscriptionMinutes => _isUsingSubscriptionMinutes;

  bool get isUserSpeaking => _isUserSpeaking;
  bool get isAgentSpeaking => _status == VoiceCallStatus.speaking && _voiceService.isSpeaking;
  bool get isAnyoneSpeaking => isAgentSpeaking || isUserSpeaking;

  int get subscriptionMinutesRemaining => _coinProvider.voiceMinutesRemaining;
  int get coinMinutesRemaining => _coinProvider.balance ~/ 10;
  int get diamondMinutesRemaining => _coinProvider.balance ~/ 10;
  int get coinBalance => _coinProvider.balance;
  int get diamondBalance => _coinProvider.balance;

  String get remainingMinutesLabel {
    if (_isUsingSubscriptionMinutes || _coinProvider.voiceMinutesRemaining > 0) {
      final mins = _coinProvider.voiceMinutesRemaining;
      return "$mins min${mins == 1 ? '' : 's'} left";
    } else {
      final mins = _coinProvider.balance ~/ 10;
      return "$mins min${mins == 1 ? '' : 's'} left";
    }
  }

  String get formattedCallDuration {
    final mins = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Start Voice Call session (costs 1 subscription voice min, or 10 coins per min)
  Future<bool> startCall({
    required Character character,
    required Scenario scenario,
    required MoodType currentMood,
  }) async {
    // Check if user has subscription voice minutes or at least 10 coins for 1 minute
    if (!_coinProvider.hasVoiceAccess()) {
      return false;
    }

    _isCallActive = true;
    _activeCharacter = character;
    _activeScenario = scenario;
    _activeMood = currentMood;
    _currentEmotion = EmotionState.happy;
    _status = VoiceCallStatus.connecting;
    _characterSpokenText = "";
    _liveTranscript = "";
    _callDurationSeconds = 0;
    notifyListeners();

    // Bill minute 1: consume subscription voice minute if available, otherwise 10 coins
    if (_coinProvider.voiceMinutesRemaining > 0) {
      await _coinProvider.deductVoiceMinutes(1);
      _isUsingSubscriptionMinutes = true;
    } else {
      await _coinProvider.spendCoins(10, 'Voice Call 1 min with ${character.name}');
      _isUsingSubscriptionMinutes = false;
    }

    // Award +25 XP for minute 1 of call
    await _awardCallMinuteAffection();

    // Explicitly prompt/check microphone permission as soon as the call starts
    await _voiceService.requestMicrophonePermission();
    notifyListeners();

    _startWaveformSimulation();
    _startCallDurationTimer();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!_isCallActive) return false;

    // Check existing chat history for conversational continuity
    final existingHistory = _storageService?.getChatHistory(character.id) ?? [];
    final userName = _storageService?.getUserName() ?? "";

    // Continuity is only valid if the user has actually chatted, or prior custom conversation occurred
    // A single initial greeting generated on profile open does NOT constitute an ongoing conversation
    bool hasPriorChat = false;
    if (existingHistory.isNotEmpty) {
      if (existingHistory.any((m) => m.isUser) || existingHistory.length > 1) {
        hasPriorChat = true;
      } else {
        // Single AI message: only treat as prior conversation if it's NOT the static initial greeting
        final firstContent = existingHistory.first.content.trim();
        final rawInit = character.initialGreeting.trim();
        final personalizedInit = RoleplayAiEngine.personalizeWithUserName(rawInit, userName).trim();
        final isDefaultGreeting = firstContent == rawInit ||
            firstContent == personalizedInit ||
            (character.voicePreviewQuote.isNotEmpty && firstContent.contains(character.voicePreviewQuote));
        hasPriorChat = !isDefaultGreeting;
      }
    }

    String openingSpokenText = "";
    if (hasPriorChat) {
      final lastMsg = existingHistory.last;
      if (lastMsg.isUser) {
        // User said something right before calling -> Generate voice reply continuing that thought
        final affection = _storageService?.getAffection(character.id) ?? 60;
        final rel = CharacterRelationship(characterId: character.id)..addAffection(affection);
        final reply = await GeminiAiService().generateRoleplayReply(
          character: character,
          userInput: lastMsg.content,
          scenario: scenario,
          currentMood: currentMood,
          relationshipLevel: rel.level,
          history: existingHistory.sublist(0, existingHistory.length - 1),
          userName: userName,
          isVoiceCall: true,
          storageService: _storageService,
        );
        _currentEmotion = reply.emotion;
        openingSpokenText = reply.spokenText;

        // Persist to history
        final aiMsg = ChatMessage(
          id: const Uuid().v4(),
          characterId: character.id,
          isUser: false,
          content: reply.text,
          emotion: reply.emotion,
        );
        existingHistory.add(aiMsg);
        await _storageService?.saveChatHistory(character.id, existingHistory);
      } else {
        // Last was AI in an ongoing conversation -> Seamlessly pick up the call acknowledging the conversation
        final cleanLast = lastMsg.content
            .replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '')
            .replaceAll(RegExp(r'""+'), '"')
            .trim();
        final lastQuoteMatch = RegExp(r'"([^"]+)"').firstMatch(cleanLast);
        final lastSpoken = (lastQuoteMatch != null && lastQuoteMatch.group(1) != null)
            ? lastQuoteMatch.group(1)!.trim()
            : cleanLast.replaceAll(RegExp(r'\*[^*]*\*'), '').replaceAll('"', '').trim();

        _currentEmotion = lastMsg.emotion;
        if (lastSpoken.isNotEmpty && lastSpoken.length < 80) {
          openingSpokenText = "Hey $userName, I'm so glad you called. Like I was just saying... $lastSpoken";
        } else {
          openingSpokenText = "Hey $userName, I'm so glad you called. I was just thinking about what we were talking about. How are you feeling right now?";
        }
      }
    } else {
      // First time interaction: Generate dynamic, authentic voice call greeting via Gemini AI
      try {
        final affection = _storageService?.getAffection(character.id) ?? 60;
        final rel = CharacterRelationship(characterId: character.id)..addAffection(affection);
        final reply = await GeminiAiService().generateRoleplayReply(
          character: character,
          userInput: "*calls you on the phone*",
          scenario: scenario,
          currentMood: currentMood,
          relationshipLevel: rel.level,
          history: [],
          userName: userName,
          isVoiceCall: true,
          storageService: _storageService,
        );
        _currentEmotion = reply.emotion;
        openingSpokenText = reply.spokenText.isNotEmpty
            ? reply.spokenText
            : reply.text.replaceAll(RegExp(r'\*[^*]*\*'), '').replaceAll('"', '').trim();

        // Save AI call opening to history
        final aiMsg = ChatMessage(
          id: const Uuid().v4(),
          characterId: character.id,
          isUser: false,
          content: reply.text,
          emotion: reply.emotion,
        );
        existingHistory.add(aiMsg);
        await _storageService?.saveChatHistory(character.id, existingHistory);
      } catch (e) {
        debugPrint("Call initial greeting generation note: $e");
        final rawQuote = character.voicePreviewQuote.isNotEmpty
            ? character.voicePreviewQuote
            : character.initialGreeting;
        openingSpokenText = RoleplayAiEngine.personalizeWithUserName(rawQuote, userName);
        final quoteMatch = RegExp(r'"([^"]+)"').firstMatch(openingSpokenText);
        if (quoteMatch != null && quoteMatch.group(1) != null) {
          openingSpokenText = quoteMatch.group(1)!.trim();
        } else {
          openingSpokenText = openingSpokenText.replaceAll(RegExp(r'\*[^*]*\*'), '').replaceAll('"', '').trim();
        }
      }
    }

    if (!_isCallActive) return false;

    // Character speaks opening continuity greeting
    _status = VoiceCallStatus.speaking;
    _characterSpokenText = openingSpokenText;
    notifyListeners();

    final customPitch = _storageService?.getCharacterVoicePitch(
      character.id,
      character.voiceProfile.defaultPitch,
    );
    final customRate = _storageService?.getCharacterVoiceRate(
      character.id,
      character.voiceProfile.defaultRate,
    );

    // Speak greeting and wait until audio completes
    await _voiceService.speakAndWait(
      character: character,
      emotion: _currentEmotion,
      text: _characterSpokenText,
      customPitch: customPitch,
      customRate: customRate,
      storageService: _storageService,
    );

    // After greeting completes, start listening loop
    if (_isCallActive) {
      _status = VoiceCallStatus.listening;
      notifyListeners();
      _startBackgroundListening();
    }

    return true;
  }

  /// Background Speech-To-Text listener that catches user voice input
  Future<void> _startBackgroundListening() async {
    if (!_isCallActive || _isMuted || _status != VoiceCallStatus.listening) return;

    String recognizedBuffer = "";
    _speechSilenceTimer?.cancel();

    final started = await _voiceService.startListening(
      onResult: (text) {
        if (!_isCallActive || _status != VoiceCallStatus.listening) return;
        recognizedBuffer = text;
        _liveTranscript = text;
        if (text.trim().isNotEmpty) {
          _markUserSpeaking();
        }
        notifyListeners();

        // 1.8 seconds pause after speech triggers AI reply
        _speechSilenceTimer?.cancel();
        _speechSilenceTimer = Timer(const Duration(milliseconds: 1800), () {
          if (recognizedBuffer.trim().isNotEmpty && _status == VoiceCallStatus.listening) {
            final speech = recognizedBuffer.trim();
            recognizedBuffer = "";
            _clearUserSpeaking();
            _voiceService.stopListening();
            handleUserSpeech(
              userText: speech,
              scenario: _activeScenario ?? Scenario.allScenarios.first,
              currentMood: _activeMood ?? MoodType.romantic,
            );
          }
        });
      },
      onSoundLevelChanged: (level) {
        if (!_isCallActive || _status != VoiceCallStatus.listening || _isMuted) return;
        if (level > 0.5) {
          _markUserSpeaking();
        }
      },
      onDone: () {
        _speechSilenceTimer?.cancel();
        _clearUserSpeaking();
        if (recognizedBuffer.trim().isNotEmpty && _status == VoiceCallStatus.listening) {
          final speech = recognizedBuffer.trim();
          recognizedBuffer = "";
          handleUserSpeech(
            userText: speech,
            scenario: _activeScenario ?? Scenario.allScenarios.first,
            currentMood: _activeMood ?? MoodType.romantic,
          );
        } else if (_isCallActive && _status == VoiceCallStatus.listening && !_isMuted) {
          // Re-listen with smooth backoff if no words were detected
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_isCallActive && _status == VoiceCallStatus.listening && !_isMuted) {
              _startBackgroundListening();
            }
          });
        }
      },
    );

    if (!started && _isCallActive && _status == VoiceCallStatus.listening) {
      _liveTranscript = "🎤 Tap mic or ⌨️ below to speak";
      notifyListeners();
    }
  }

  void triggerListening() {
    if (!_isCallActive) return;
    _speechSilenceTimer?.cancel();
    _voiceService.stop();
    _isMuted = false;

    // If user tapped the mic while speech was already in live buffer, send it immediately!
    if (_liveTranscript.trim().isNotEmpty &&
        !_liveTranscript.contains("Listening") &&
        !_liveTranscript.contains("Tap mic")) {
      final textToSend = _liveTranscript.trim();
      _liveTranscript = "";
      handleUserSpeech(
        userText: textToSend,
        scenario: _activeScenario ?? Scenario.allScenarios.first,
        currentMood: _activeMood ?? MoodType.romantic,
      );
      return;
    }

    _status = VoiceCallStatus.listening;
    _liveTranscript = "Listening to you...";
    notifyListeners();
    _startBackgroundListening();
  }

  Future<bool> ensureMicrophonePermission() async {
    final granted = await _voiceService.requestMicrophonePermission();
    notifyListeners();
    if (granted && _status == VoiceCallStatus.listening && _isCallActive) {
      _startBackgroundListening();
    }
    return granted;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
    if (_isMuted) {
      _clearUserSpeaking();
      _speechSilenceTimer?.cancel();
      _voiceService.stopListening();
    } else if (_status == VoiceCallStatus.listening) {
      _startBackgroundListening();
    }
  }

  /// Process spoken user input -> generate AI response -> speak with ElevenLabs
  Future<void> handleUserSpeech({
    required String userText,
    required Scenario scenario,
    required MoodType currentMood,
  }) async {
    if (userText.trim().isEmpty || _activeCharacter == null || !_isCallActive) return;

    _clearUserSpeaking();
    _speechSilenceTimer?.cancel();
    await _voiceService.stopListening();

    _liveTranscript = userText;
    _status = VoiceCallStatus.thinking;
    notifyListeners();

    final affection = _storageService?.getAffection(_activeCharacter!.id) ?? 60;
    final rel = CharacterRelationship(characterId: _activeCharacter!.id)..addAffection(affection);
    final relLevel = rel.level;

    // Load conversation history for character so Gemini has multi-turn context
    final history = _storageService?.getChatHistory(_activeCharacter!.id) ?? [];

    final geminiService = GeminiAiService();
    final userName = _storageService?.getUserName() ?? "";
    final response = await geminiService.generateRoleplayReply(
      character: _activeCharacter!,
      userInput: userText,
      scenario: scenario,
      currentMood: currentMood,
      relationshipLevel: relLevel,
      history: history,
      userName: userName,
      isVoiceCall: true,
      storageService: _storageService,
    );

    // Save user speech and AI reply to history so voice calls are permanently remembered!
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      characterId: _activeCharacter!.id,
      isUser: true,
      content: userText.trim(),
    );
    final aiMsg = ChatMessage(
      id: const Uuid().v4(),
      characterId: _activeCharacter!.id,
      isUser: false,
      content: response.text,
      emotion: response.emotion,
    );
    history.add(userMsg);
    history.add(aiMsg);
    await _storageService?.saveChatHistory(_activeCharacter!.id, history);

    if (!_isCallActive) return;

    // 2. Pass response to ElevenLabs for speech synthesis
    _currentEmotion = response.emotion;
    _characterSpokenText = response.spokenText.isNotEmpty
        ? response.spokenText
        : response.text.replaceAll(RegExp(r'\*[^*]*\*'), '').replaceAll('"', '').trim();
    _status = VoiceCallStatus.speaking;
    notifyListeners();

    final customPitch = _storageService?.getCharacterVoicePitch(
      _activeCharacter!.id,
      _activeCharacter!.voiceProfile.defaultPitch,
    );
    final customRate = _storageService?.getCharacterVoiceRate(
      _activeCharacter!.id,
      _activeCharacter!.voiceProfile.defaultRate,
    );

    await _voiceService.speakAndWait(
      character: _activeCharacter!,
      emotion: _currentEmotion,
      text: response.spokenText.isNotEmpty ? response.spokenText : response.text,
      customPitch: customPitch,
      customRate: customRate,
      storageService: _storageService,
    );

    // 3. Audio complete: reset transcript and resume listening loop
    if (_isCallActive) {
      _liveTranscript = "";
      _status = VoiceCallStatus.listening;
      notifyListeners();
      _startBackgroundListening();
    }
  }

  void setChatProvider(ChatProvider cp) {
    _chatProvider = cp;
  }

  void endCall() {
    final characterId = _activeCharacter?.id;
    _isCallActive = false;
    _clearUserSpeaking();
    _speechSilenceTimer?.cancel();
    _callDurationTimer?.cancel();
    _voiceService.stopListening();
    _voiceService.stop();
    _waveformTimer?.cancel();
    _status = VoiceCallStatus.idle;
    _activeCharacter = null;
    _characterSpokenText = "";
    _liveTranscript = "";
    _callDurationSeconds = 0;
    _visualizerFrequencies = List.filled(24, 0.04);
    notifyListeners();
    if (characterId != null) {
      _chatProvider?.refreshRelationship(characterId);
    }
  }

  /// Awards +25 affection XP per minute of voice call to the character's relationship
  Future<void> _awardCallMinuteAffection() async {
    if (_activeCharacter == null) return;
    final affection = _storageService?.getAffection(_activeCharacter!.id) ?? 0;
    final rel = CharacterRelationship(characterId: _activeCharacter!.id, affectionPoints: affection);
    rel.addAffection(25);
    await _storageService?.saveAffection(_activeCharacter!.id, rel.affectionPoints);
    _chatProvider?.syncAffection(_activeCharacter!.id, rel.affectionPoints);
    debugPrint("Awarded +25 call affection XP to ${_activeCharacter!.name} (Total: ${rel.affectionPoints})");
  }

  void _startCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isCallActive) {
        timer.cancel();
        return;
      }
      _callDurationSeconds++;
      notifyListeners();

      // Every 60 seconds elapsed during active call, bill the next minute and award +25 XP
      if (_callDurationSeconds % 60 == 0) {
        if (_coinProvider.voiceMinutesRemaining > 0) {
          await _coinProvider.deductVoiceMinutes(1);
          _isUsingSubscriptionMinutes = true;
          await _awardCallMinuteAffection();
        } else if (_coinProvider.balance >= 10) {
          await _coinProvider.spendCoins(10, 'Voice Call 1 min with ${_activeCharacter?.name ?? "Character"}');
          _isUsingSubscriptionMinutes = false;
          await _awardCallMinuteAffection();
        } else {
          // Out of both subscription voice minutes and diamonds
          _errorMessage = "Voice call ended: Insufficient diamonds/minutes for next minute.";
          notifyListeners();
          endCall();
        }
      }
    });
  }

  void _startWaveformSimulation() {
    _waveformTimer?.cancel();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!_isCallActive) return;

      if (isAnyoneSpeaking) {
        _visualizerFrequencies = List.generate(24, (index) {
          final centerDist = (index - 12).abs() / 12.0;
          final base = (1.0 - centerDist * 0.65);
          final noise = _rng.nextDouble() * 0.55;
          return (base * (0.35 + noise)).clamp(0.12, 1.0);
        });
        notifyListeners();
      } else {
        if (_visualizerFrequencies.any((f) => f > 0.05)) {
          _visualizerFrequencies = List.filled(24, 0.04);
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _isCallActive = false;
    _clearUserSpeaking();
    _speechSilenceTimer?.cancel();
    _callDurationTimer?.cancel();
    _waveformTimer?.cancel();
    _errorSubscription?.cancel();
    _speakingSubscription?.cancel();
    _voiceService.dispose();
    super.dispose();
  }
}
