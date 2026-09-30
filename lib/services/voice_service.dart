import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/character.dart';
import '../models/emotion_state.dart';
import 'api_service.dart';
import 'storage_service.dart';

enum VoiceCallStatus { idle, connecting, listening, thinking, speaking }

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _neuralAudioCache = {};
  StorageService? _storageService;

  void setStorageService(StorageService service) {
    _storageService = service;
  }

  bool _isTtsInitialized = false;
  bool _isSttAvailable = false;
  bool _isSpeaking = false;
  bool _hasMicPermission = false;
  Completer<bool>? _activeSpeechCompleter;

  final List<Map<String, String>> _femaleVoicePool = [];
  final List<Map<String, String>> _maleVoicePool = [];
  final Map<String, Map<String, String>> _characterAssignedVoice = {};

  final StreamController<bool> _speakingStateController = StreamController<bool>.broadcast();
  Stream<bool> get speakingStateStream => _speakingStateController.stream;

  bool get isSpeaking => _isSpeaking;
  bool get isSttAvailable => _isSttAvailable;
  bool get hasMicPermission => _hasMicPermission;

  Future<void> init() async {
    if (_isTtsInitialized) return;

    try {
      // Configure audio session for simultaneous two-way VoIP / play & record
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.allowBluetoothA2DP,
              AVAudioSessionOptions.duckOthers,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
    } catch (e) {
      debugPrint("AudioContext setup notice: $e");
    }

    try {
      // Check microphone permission silently so UI reflects reality without premature popup
      final micStatus = await Permission.microphone.status;
      _hasMicPermission = micStatus.isGranted;
    } catch (_) {}

    try {
      await _tts.setLanguage("en-US");
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.42);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        _speakingStateController.add(true);
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingStateController.add(false);
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _speakingStateController.add(false);
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        _isSpeaking = false;
        _speakingStateController.add(false);
      });

      // Discover and catalog available high-quality voices per gender
      await _discoverNaturalHumanVoices();
      _assignUniqueVoicesToCharacters();

      _isTtsInitialized = true;
    } catch (e) {
      debugPrint("TTS init error: $e");
    }
  }

  /// Automatically discover and classify all system voices into high quality female and male pools
  Future<void> _discoverNaturalHumanVoices() async {
    try {
      final voices = await _tts.getVoices;
      _femaleVoicePool.clear();
      _maleVoicePool.clear();

      if (voices is List) {
        for (final v in voices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();

            // English locales
            if (locale.contains('en-us') ||
                locale.contains('en_us') ||
                locale.contains('en-gb') ||
                locale.contains('en-au') ||
                locale.contains('en')) {
              final voiceEntry = {
                "name": v['name'].toString(),
                "locale": v['locale']?.toString() ?? "en-US",
              };

              // Identify female voices
              final isFemale = name.contains('female') ||
                  name.contains('sfg') ||
                  name.contains('tpf') ||
                  name.contains('samantha') ||
                  name.contains('ava') ||
                  name.contains('zira') ||
                  name.contains('victoria') ||
                  name.contains('karen') ||
                  name.contains('hazel') ||
                  name.contains('susan') ||
                  name.contains('neural2-f') ||
                  name.contains('wavenet-f') ||
                  name.contains('smf');

              // Identify male voices
              final isMale = name.contains('male') ||
                  name.contains('iol') ||
                  name.contains('iom') ||
                  name.contains('iob') ||
                  name.contains('daniel') ||
                  name.contains('oliver') ||
                  name.contains('david') ||
                  name.contains('george') ||
                  name.contains('alex') ||
                  name.contains('fred') ||
                  name.contains('neural2-d') ||
                  name.contains('wavenet-d');

              if (isFemale && !_femaleVoicePool.any((x) => x['name'] == voiceEntry['name'])) {
                _femaleVoicePool.add(voiceEntry);
              } else if (isMale && !_maleVoicePool.any((x) => x['name'] == voiceEntry['name'])) {
                _maleVoicePool.add(voiceEntry);
              } else {
                // Fallback distribution if not explicitly labeled
                if (!_femaleVoicePool.any((x) => x['name'] == voiceEntry['name'])) {
                  _femaleVoicePool.add(voiceEntry);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Could not discover TTS voices: $e");
    }
  }

  /// Assign each character a distinct voice from the available pool
  void _assignUniqueVoicesToCharacters() {
    final femaleChars = Character.allCharacters.where((c) => c.gender == Gender.female).toList();
    final maleChars = Character.allCharacters.where((c) => c.gender == Gender.male).toList();

    // Distribute female voices
    for (int i = 0; i < femaleChars.length; i++) {
      final char = femaleChars[i];
      Map<String, String>? matched;

      // Try keyword match first
      for (final kw in char.voiceProfile.preferredVoiceKeywords) {
        final found = _femaleVoicePool.where((v) => v['name']!.toLowerCase().contains(kw.toLowerCase()));
        if (found.isNotEmpty) {
          matched = found.first;
          break;
        }
      }

      // If no keyword match or already assigned, pick round-robin from pool
      if (matched == null && _femaleVoicePool.isNotEmpty) {
        matched = _femaleVoicePool[i % _femaleVoicePool.length];
      }

      if (matched != null) {
        _characterAssignedVoice[char.id] = matched;
      }
    }

    // Distribute male voices
    for (int i = 0; i < maleChars.length; i++) {
      final char = maleChars[i];
      Map<String, String>? matched;

      // Try keyword match first
      for (final kw in char.voiceProfile.preferredVoiceKeywords) {
        final found = _maleVoicePool.where((v) => v['name']!.toLowerCase().contains(kw.toLowerCase()));
        if (found.isNotEmpty) {
          matched = found.first;
          break;
        }
      }

      // If no keyword match, pick round-robin from pool
      if (matched == null && _maleVoicePool.isNotEmpty) {
        matched = _maleVoicePool[i % _maleVoicePool.length];
      }

      if (matched != null) {
        _characterAssignedVoice[char.id] = matched;
      }
    }
  }

  /// Get the assigned voice map for a specific character
  Map<String, String>? getVoiceForCharacter(Character character) {
    return _characterAssignedVoice[character.id];
  }

  /// Format text with human emotional pauses, breath marks, and hesitation contours
  static String formatEmotionalText(String text, EmotionState emotion, {double intensity = 1.0}) {
    String clean = text.replaceAll(RegExp(r'\*[^*]*\*'), '').replaceAll('"', '').trim();
    if (clean.isEmpty) clean = text.replaceAll('*', '').replaceAll('"', '').trim();
    if (intensity <= 0.2) return clean;

    switch (emotion) {
      case EmotionState.romantic:
        // Slow intimate cadence with tender lingering pauses
        var res = clean
            .replaceAll(', ', '... ')
            .replaceAll('. ', '... ')
            .replaceAll('!', '... ');
        if (!res.endsWith('...')) {
          res = '$res...';
        }
        return res;

      case EmotionState.shy:
        // Soft breath pauses and timid hesitations
        var modified = clean;
        if (!modified.startsWith('U-um') && !modified.startsWith('I-I') && !modified.startsWith('O-oh')) {
          modified = 'U-um... $modified';
        }
        return modified.replaceAll(', ', '... ');

      case EmotionState.excited:
        // Energetic exclamation bursts
        return clean.replaceAll('.', '!');

      case EmotionState.sad:
      case EmotionState.emotional:
        // Descending cadence with trailing pauses
        var res = clean.replaceAll('. ', '... ').replaceAll(', ', '... ');
        if (!res.endsWith('...')) {
          res = '$res...';
        }
        return res;

      case EmotionState.thinking:
        return 'Hmm... $clean';

      case EmotionState.angry:
        return clean.replaceAll(',', '!');

      case EmotionState.playful:
      case EmotionState.laughing:
      case EmotionState.surprised:
      case EmotionState.happy:
        return clean;
    }
  }

  final StreamController<String> _errorMessageController = StreamController<String>.broadcast();
  Stream<String> get errorMessageStream => _errorMessageController.stream;

  void _notifyError(String message) {
    debugPrint("Voice notice: $message");
    _errorMessageController.add(message);

    try {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1724),
            behavior: SnackBarBehavior.floating,
            elevation: 8,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFFF4B72), width: 1.2),
            ),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2.0),
                  child: Icon(Icons.error_outline_rounded, color: Color(0xFFFF4B72), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Voice Studio Notice",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error showing snackbar: $e");
    }
  }

  /// Format dialogue text with emotional pauses, breath marks, and inflection for ElevenLabs
  String _formatEmotionalText(String text, EmotionState emotion) {
    String formatted = text.trim();
    // Clean out any leftover markdown or brackets (closed or unclosed)
    formatted = formatted.replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '').trim();
    formatted = formatted.replaceAll(RegExp(r'\*[^*]*\*'), '').trim();
    formatted = formatted.replaceAll(RegExp(r'""+'), '"').replaceAll('"', '').trim();

    switch (emotion) {
      case EmotionState.romantic:
        // Slower, intimate, breathy pauses
        formatted = formatted.replaceAll(', ', '... ');
        if (!formatted.endsWith('...') && !formatted.endsWith('.')) formatted += '...';
        break;
      case EmotionState.shy:
        // Hesitant, delicate pauses
        formatted = formatted.replaceAll('. ', '... ');
        break;
      case EmotionState.sad:
      case EmotionState.emotional:
        // Tender, trailing off softly
        formatted = formatted.replaceAll(', ', '... ');
        break;
      case EmotionState.happy:
      case EmotionState.excited:
        // Vibrant, energetic
        if (formatted.endsWith('.')) formatted = '${formatted.substring(0, formatted.length - 1)}!';
        break;
      case EmotionState.playful:
      case EmotionState.laughing:
        // Playful cadence
        break;
      case EmotionState.angry:
        // Sharp, decisive
        break;
      default:
        break;
    }
    return formatted.isNotEmpty ? formatted : text;
  }

  /// Synthesize ultra-realistic human voice with emotional nuance via ElevenLabs API
  /// Synthesize ultra-realistic human voice with emotional nuance via ElevenLabs API
  Future<bool> _speakWithElevenLabs({
    required String text,
    required String voiceId,
    required String apiKey,
    EmotionState emotion = EmotionState.happy,
    double speed = 1.0,
    double emotionIntensity = 1.0,
  }) async {
    if (apiKey.trim().isEmpty || voiceId.trim().isEmpty) {
      debugPrint("ℹ️ ElevenLabs API key or voiceId is empty; using local device voice engine.");
      return false;
    }

    try {
      final cacheKey = 'eleven-$voiceId-$speed-$emotionIntensity-${emotion.name}-$text';
      Uint8List? audioBytes = _neuralAudioCache[cacheKey];

      if (audioBytes == null) {
        double baseStability;
        double baseStyle;

        switch (emotion) {
          case EmotionState.romantic:
            baseStability = 0.28;
            baseStyle = 0.68;
            break;
          case EmotionState.shy:
            baseStability = 0.35;
            baseStyle = 0.50;
            break;
          case EmotionState.excited:
            baseStability = 0.32;
            baseStyle = 0.72;
            break;
          case EmotionState.happy:
          case EmotionState.playful:
          case EmotionState.laughing:
            baseStability = 0.35;
            baseStyle = 0.60;
            break;
          case EmotionState.sad:
          case EmotionState.emotional:
            baseStability = 0.26;
            baseStyle = 0.62;
            break;
          case EmotionState.angry:
            baseStability = 0.30;
            baseStyle = 0.75;
            break;
          case EmotionState.thinking:
          case EmotionState.surprised:
            baseStability = 0.38;
            baseStyle = 0.55;
            break;
        }

        final stability = (baseStability - (emotionIntensity - 1.0) * 0.08).clamp(0.18, 0.65);
        final style = (baseStyle + (emotionIntensity - 1.0) * 0.12).clamp(0.15, 0.90);

        http.Response? response;
        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            response = await http.post(
              Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId?output_format=mp3_44100_128'),
              headers: {
                'xi-api-key': apiKey.trim(),
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'text': text,
                'model_id': 'eleven_turbo_v2_5',
                'voice_settings': {
                  'stability': stability,
                  'similarity_boost': 0.80,
                  'style': style,
                  'use_speaker_boost': true,
                },
              }),
            ).timeout(const Duration(seconds: 15));

            if (response.statusCode == 200) {
              break;
            } else if (response.statusCode == 429 && attempt == 0) {
              await Future.delayed(const Duration(milliseconds: 600));
              continue;
            } else {
              break;
            }
          } catch (e) {
            if (attempt == 0) {
              await Future.delayed(const Duration(milliseconds: 400));
              continue;
            }
            debugPrint("ElevenLabs request attempt failed: $e");
            return false;
          }
        }

        if (response != null && response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          audioBytes = response.bodyBytes;
          _neuralAudioCache[cacheKey] = audioBytes;
        } else {
          debugPrint("ElevenLabs response: ${response?.statusCode}");
          return false;
        }
      }

      _isSpeaking = true;
      _speakingStateController.add(true);
      await _audioPlayer.play(BytesSource(audioBytes));
      return true;
    } catch (e) {
      debugPrint("ElevenLabs audio player exception: $e");
      return false;
    }
  }

  /// Synthesize voice using local device TTS engine as reliable zero-latency fallback
  Future<bool> _speakWithLocalTts({
    required Character character,
    required EmotionState emotion,
    required String text,
    double? customPitch,
    double? customRate,
    double userSpeedMultiplier = 1.0,
  }) async {
    try {
      if (!_isTtsInitialized) {
        await init();
      }
      final assignedVoice = getVoiceForCharacter(character);
      if (assignedVoice != null) {
        try {
          await _tts.setVoice({
            "name": assignedVoice['name']!,
            "locale": assignedVoice['locale']!,
          });
        } catch (_) {}
      }

      final pitch = (customPitch ?? character.voiceProfile.defaultPitch).clamp(0.5, 1.8);
      final rate = ((customRate ?? character.voiceProfile.defaultRate) * userSpeedMultiplier).clamp(0.2, 1.0);

      try {
        await _tts.setPitch(pitch);
        await _tts.setSpeechRate(rate);
      } catch (_) {}

      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        _isSpeaking = true;
        _speakingStateController.add(true);
        Future.delayed(const Duration(milliseconds: 50), () {
          _isSpeaking = false;
          _speakingStateController.add(false);
        });
        return true;
      }

      _isSpeaking = true;
      _speakingStateController.add(true);
      await _tts.speak(text);
      return true;
    } catch (e) {
      debugPrint("Local TTS error: $e");
      _isSpeaking = false;
      _speakingStateController.add(false);
      return false;
    }
  }

  /// Internal speech synthesis executor (ElevenLabs with local TTS fallback)
  Future<bool> _executeSpeech({
    required Character character,
    required EmotionState emotion,
    required String text,
    double? customPitch,
    double? customRate,
    double emotionIntensity = 1.0,
    StorageService? storageService,
    double userSpeedMultiplier = 1.0,
  }) async {
    final cleanText = text.replaceAll(RegExp(r'\*[^*]*\*'), '').trim();
    final rawDialogue = cleanText.isNotEmpty ? cleanText : text.replaceAll('*', '');
    final spokenContent = _formatEmotionalText(rawDialogue, emotion);

    final storage = storageService ?? _storageService;
    final elevenLabsKey = storage?.getElevenLabsApiKey() ?? '';

    final customVoiceId = storage?.getCharacterElevenLabsVoice(character.id);
    final voiceId = (customVoiceId != null && customVoiceId.isNotEmpty)
        ? customVoiceId
        : (character.voiceProfile.elevenLabsVoiceId.isNotEmpty
            ? character.voiceProfile.elevenLabsVoiceId
            : (character.gender == Gender.female
                ? '3YXAuwCx7wB8kSkKCqsu' // Intimate Romantic Female
                : '3svOJAOhuPHXwQC2H5eq')); // Friendly / Warm Natural Male

    // 1. Try ElevenLabs neural audio first if API key is provided
    bool played = false;
    if (elevenLabsKey.trim().isNotEmpty) {
      try {
        played = await _speakWithElevenLabs(
          text: spokenContent,
          voiceId: voiceId,
          apiKey: elevenLabsKey,
          emotion: emotion,
          speed: userSpeedMultiplier,
          emotionIntensity: emotionIntensity,
        );
      } catch (e) {
        debugPrint("ElevenLabs playback error: $e");
        played = false;
      }
    }

    // 2. If ElevenLabs is not configured, failed, or timed out, fall back to local device TTS
    if (!played) {
      debugPrint("🔊 Playing voice via local TTS engine for ${character.name}");
      played = await _speakWithLocalTts(
        character: character,
        emotion: emotion,
        text: spokenContent,
        customPitch: customPitch,
        customRate: customRate,
        userSpeedMultiplier: userSpeedMultiplier,
      );
    }

    if (!played) {
      _isSpeaking = false;
      _speakingStateController.add(false);
    }
    return played;
  }

  /// Speak dialogue (stops previous speech first, then plays new speech)
  Future<void> speak({
    required Character character,
    required EmotionState emotion,
    required String text,
    double? customPitch,
    double? customRate,
    double emotionIntensity = 1.0,
    StorageService? storageService,
    double userSpeedMultiplier = 1.0,
  }) async {
    try {
      await stop();
      await _executeSpeech(
        character: character,
        emotion: emotion,
        text: text,
        customPitch: customPitch,
        customRate: customRate,
        emotionIntensity: emotionIntensity,
        storageService: storageService,
        userSpeedMultiplier: userSpeedMultiplier,
      );
    } catch (e) {
      debugPrint("Voice speak error: $e");
      _isSpeaking = false;
      _speakingStateController.add(false);
    }
  }

  /// Plays pre-generated voice preview directly from server via HTTPS (Zero ElevenLabs API cost)
  Future<bool> playVoicePreview({
    required String voiceIdOrUrl,
  }) async {
    try {
      await stop();
      final url = voiceIdOrUrl.startsWith('http')
          ? voiceIdOrUrl
          : '${ApiService().baseUrl}/assets/voices/$voiceIdOrUrl.mp3';

      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        _isSpeaking = true;
        _speakingStateController.add(true);
        Future.delayed(const Duration(milliseconds: 50), () {
          _isSpeaking = false;
          _speakingStateController.add(false);
        });
        return true;
      }

      _isSpeaking = true;
      _speakingStateController.add(true);
      await _audioPlayer.play(UrlSource(url));
      return true;
    } catch (e) {
      debugPrint("Voice preview playback error: $e");
      _isSpeaking = false;
      _speakingStateController.add(false);
      return false;
    }
  }

  /// Quick test method for Voice Studio modal
  Future<void> testVoice({
    required Character character,
    required double pitch,
    required double rate,
    EmotionState emotion = EmotionState.happy,
    double emotionIntensity = 1.0,
    StorageService? storageService,
    String? sampleText,
  }) async {
    await speak(
      character: character,
      emotion: emotion,
      text: sampleText ?? character.voicePreviewQuote,
      customPitch: pitch,
      customRate: rate,
      emotionIntensity: emotionIntensity,
      storageService: storageService ?? _storageService,
    );
  }

  /// Speak dialogue and await audio playback completion
  Future<bool> speakAndWait({
    required Character character,
    required EmotionState emotion,
    required String text,
    double? customPitch,
    double? customRate,
    double emotionIntensity = 1.0,
    StorageService? storageService,
    double userSpeedMultiplier = 1.0,
  }) async {
    // 1. Stop any prior speech BEFORE initializing the completion listener
    await stop();

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isSpeaking = true;
      _speakingStateController.add(true);
      await Future.delayed(const Duration(milliseconds: 50));
      _isSpeaking = false;
      _speakingStateController.add(false);
      return true;
    }

    final completer = Completer<bool>();
    _activeSpeechCompleter = completer;

    late final StreamSubscription playerSub;
    playerSub = _audioPlayer.onPlayerComplete.listen((_) {
      _isSpeaking = false;
      _speakingStateController.add(false);
      if (!completer.isCompleted) completer.complete(true);
      playerSub.cancel();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _speakingStateController.add(false);
      if (!completer.isCompleted) completer.complete(true);
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _speakingStateController.add(false);
      if (!completer.isCompleted) completer.complete(false);
    });

    // 2. Execute speech without calling stop() internally so active completer is preserved
    final started = await _executeSpeech(
      character: character,
      emotion: emotion,
      text: text,
      customPitch: customPitch,
      customRate: customRate,
      emotionIntensity: emotionIntensity,
      storageService: storageService,
      userSpeedMultiplier: userSpeedMultiplier,
    );

    if (!started || !_isSpeaking) {
      playerSub.cancel();
      if (_activeSpeechCompleter == completer) _activeSpeechCompleter = null;
      return false;
    }

    try {
      await completer.future.timeout(const Duration(seconds: 40), onTimeout: () {
        playerSub.cancel();
        return true;
      });
    } catch (_) {
      playerSub.cancel();
    } finally {
      if (_activeSpeechCompleter == completer) {
        _activeSpeechCompleter = null;
      }
      _isSpeaking = false;
      _speakingStateController.add(false);
    }
    return true;
  }

  Future<void> stop() async {
    try {
      if (_activeSpeechCompleter != null && !_activeSpeechCompleter!.isCompleted) {
        _activeSpeechCompleter!.complete(false);
      }
      _activeSpeechCompleter = null;
      await _tts.stop();
      await _audioPlayer.stop();
      _isSpeaking = false;
      _speakingStateController.add(false);
    } catch (_) {}
  }

  bool get isListening => _speech.isListening;
  bool _isListeningSessionActive = false;
  int _activeSessionId = 0;
  VoidCallback? _currentOnDone;

  void _notifySttSessionEnded(int sessionId) {
    if (sessionId == _activeSessionId && _isListeningSessionActive) {
      _isListeningSessionActive = false;
      final cb = _currentOnDone;
      _currentOnDone = null;
      cb?.call();
    }
  }

  /// Initialize speech recognition engine idempotently with proper platform configuration
  Future<bool> initSpeechRecognizer({bool force = false}) async {
    if (_isSttAvailable && _speech.isAvailable && !force) {
      return true;
    }
    try {
      _isSttAvailable = await _speech.initialize(
        onError: (val) {
          debugPrint("STT notice (${val.errorMsg})");
          _notifySttSessionEnded(_activeSessionId);
        },
        onStatus: (status) {
          debugPrint("STT status: $status");
          if (status == 'done' || status == 'notListening' || status == 'doneNoResult') {
            _notifySttSessionEnded(_activeSessionId);
          }
        },
        options: [stt.SpeechToText.androidNoBluetooth],
        debugLogging: false,
      );
      return _isSttAvailable;
    } catch (e) {
      debugPrint("STT initialization error: $e");
      return false;
    }
  }

  /// Explicitly requests microphone (and speech recognition on iOS) permissions
  Future<bool> requestMicrophonePermission() async {
    try {
      // 1. Check & request microphone permission
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      _hasMicPermission = status.isGranted;

      // 2. On iOS, speech recognition is a distinct permission required by speech_to_text
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          var speechStatus = await Permission.speech.status;
          if (!speechStatus.isGranted) {
            speechStatus = await Permission.speech.request();
          }
          if (!speechStatus.isGranted) {
            _hasMicPermission = false;
          }
        } catch (e) {
          debugPrint("iOS speech permission request error: $e");
        }
      }

      if (status.isPermanentlyDenied) {
        _notifyError("Microphone permission denied. Please allow Lovia microphone access in Settings.");
      }

      // 3. Initialize STT engine if permission granted
      if (_hasMicPermission) {
        await initSpeechRecognizer();
      }
      return _hasMicPermission;
    } catch (e) {
      debugPrint("Microphone permission check error: $e");
      // Fallback for environments without permission_handler implementation (desktop/tests)
      try {
        await initSpeechRecognizer();
        _hasMicPermission = _isSttAvailable;
        return _hasMicPermission;
      } catch (_) {
        return false;
      }
    }
  }

  /// Start voice listening with active session isolation
  Future<bool> startListening({
    required Function(String text) onResult,
    required VoidCallback onDone,
    Function(double soundLevel)? onSoundLevelChanged,
  }) async {
    try {
      // 1. Ensure any playing audio or TTS is halted so microphone input is not blocked
      await stop();

      // 2. Check / request permissions
      if (!_hasMicPermission) {
        final hasMic = await requestMicrophonePermission();
        if (!hasMic) {
          debugPrint("Microphone permission not granted");
          return false;
        }
      }

      // 3. Initialize speech recognition engine if not ready
      if (!_isSttAvailable || !_speech.isAvailable) {
        await initSpeechRecognizer();
      }

      if (!_isSttAvailable || !_speech.isAvailable) {
        debugPrint("Speech recognition service not ready on this device/environment");
        return false;
      }

      // 4. Safely stop any previous active listening session to avoid ERROR_RECOGNIZER_BUSY
      if (_speech.isListening) {
        _isListeningSessionActive = false;
        _currentOnDone = null;
        try {
          await _speech.stop();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (_) {}
      }

      final sessionId = ++_activeSessionId;
      _isListeningSessionActive = true;
      _currentOnDone = onDone;

      // Detect system locale if available
      String? localeId;
      try {
        final systemLocale = await _speech.systemLocale();
        localeId = systemLocale?.localeId;
      } catch (_) {}

      await _speech.listen(
        onResult: (result) {
          if (sessionId != _activeSessionId) return;
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        onSoundLevelChange: (level) {
          if (sessionId != _activeSessionId) return;
          onSoundLevelChanged?.call(level);
        },
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        localeId: localeId,
      );
      return true;
    } catch (e) {
      debugPrint("startListening error: $e");
      _isListeningSessionActive = false;
      _currentOnDone = null;
    }
    return false;
  }

  Future<void> stopListening() async {
    _activeSessionId++;
    _isListeningSessionActive = false;
    _currentOnDone = null;
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    _activeSessionId++;
    _isListeningSessionActive = false;
    _currentOnDone = null;
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {}
  }

  /// Fetches all available voices from the user's ElevenLabs account (custom cloned + library voices)
  Future<List<Map<String, String>>> fetchElevenLabsAccountVoices({
    String? apiKey,
    StorageService? storageService,
  }) async {
    try {
      final key = apiKey ??
          (storageService ?? _storageService)?.getElevenLabsApiKey() ??
          '';

      final response = await http.get(
        Uri.parse('https://api.elevenlabs.io/v1/voices'),
        headers: {
          'xi-api-key': key,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final voicesList = data['voices'] as List<dynamic>? ?? [];
        final List<Map<String, String>> result = [];

        for (final v in voicesList) {
          final voiceId = v['voice_id']?.toString() ?? '';
          final name = v['name']?.toString() ?? 'Unnamed Voice';
          final category = v['category']?.toString() ?? 'premade';
          final labels = v['labels'] as Map<String, dynamic>? ?? {};
          final desc = labels.entries.map((e) => "${e.key}: ${e.value}").join(", ");

          if (voiceId.isNotEmpty) {
            result.add({
              'voice_id': voiceId,
              'name': name,
              'category': category,
              'description': desc,
            });
          }
        }
        return result;
      } else {
        debugPrint("ElevenLabs fetch voices status: ${response.statusCode}");
        return curatedElevenLabsVoices;
      }
    } catch (e) {
      debugPrint("ElevenLabs fetch voices exception: $e");
      return curatedElevenLabsVoices;
    }
  }

  static const List<Map<String, String>> curatedElevenLabsVoices = [
    {
      'voice_id': 'uKGPYP2uuyRQv8SeFre0',
      'name': 'Natural Male',
      'category': 'curated',
      'description': 'Natural, warm, grounded male voice',
    },
    {
      'voice_id': '3svOJAOhuPHXwQC2H5eq',
      'name': 'Friendly Male',
      'category': 'curated',
      'description': 'Warm, approachable, friendly companion',
    },
    {
      'voice_id': 'Vep3bcB7LhKa3wfjMiI6',
      'name': 'Deep Male',
      'category': 'curated',
      'description': 'Deep resonance, authoritative and calm',
    },
    {
      'voice_id': '7WggD3IoWTIPT19PNyrW',
      'name': 'Effortless Male',
      'category': 'curated',
      'description': 'Relaxed, smooth, effortless conversationalist',
    },
    {
      'voice_id': 'Myap7vX7L9ipoJVdyOVZ',
      'name': 'Intimate Male',
      'category': 'curated',
      'description': 'Sensual whisper, heartfelt romantic intimacy',
    },
    {
      'voice_id': 'EozfaQ3ZX0esAp1cW5nG',
      'name': 'Deep Resonant Male',
      'category': 'curated',
      'description': 'Low timbre, magnetic presence',
    },
    {
      'voice_id': 'oaLGpwm7fYWDEFmlRuQk',
      'name': 'Intimate Soft Male',
      'category': 'curated',
      'description': 'Tender, breathy, late-night companion',
    },
    {
      'voice_id': 'hYZHGYzFnp1GKImhQtGi',
      'name': 'Funny Male',
      'category': 'curated',
      'description': 'Playful, lively, spirited laughter',
    },
    {
      'voice_id': 'LyZq9ggDlPpK7b17wpjG',
      'name': 'Deep Velvet Male',
      'category': 'curated',
      'description': 'Smooth baritone, mysterious and steady',
    },
    {
      'voice_id': 'inGcvmoPgbvKUk9uCvHu',
      'name': 'Sad / Tender Male',
      'category': 'curated',
      'description': 'Melancholic, gentle, emotionally vulnerable',
    },
    {
      'voice_id': '4NejU5DwQjevnR6mh3mb',
      'name': 'Expressive Female',
      'category': 'curated',
      'description': 'Lively, dynamic, rich theatrical emotional range',
    },
    {
      'voice_id': 'uYXf8XasLslADfZ2MB4u',
      'name': 'Gossip Female',
      'category': 'curated',
      'description': 'Playful whisper, conspiratorial banter',
    },
    {
      'voice_id': '0zj1iWvloMkAXydIFsJR',
      'name': 'Sweet Female',
      'category': 'curated',
      'description': 'Gentle, nurturing, innocent melody',
    },
    {
      'voice_id': '3YXAuwCx7wB8kSkKCqsu',
      'name': 'Intimate Romantic Female',
      'category': 'curated',
      'description': 'Soft breath, captivating romantic closeness',
    },
    {
      'voice_id': 'xYa75LlayhWHCRl1yJSH',
      'name': 'Intimate Sensual Female',
      'category': 'curated',
      'description': 'Deep emotional warmth, delicate whispering',
    },
    {
      'voice_id': 'h61MhzGbN77HK91UuRr8',
      'name': 'Intimate Alluring Female',
      'category': 'curated',
      'description': 'Hypnotic, magnetic, close emotional presence',
    },
    {
      'voice_id': '2NzqTfQARqdn4tcBKTSh',
      'name': 'Talkative Female',
      'category': 'curated',
      'description': 'Energetic, cheerful, upbeat storytelling',
    },
    {
      'voice_id': 'CyHwTRKhXEYuSd7CbMwI',
      'name': 'Funny Female',
      'category': 'curated',
      'description': 'Bubbly laughter, mischievous, joyful spirit',
    },
    {
      'voice_id': 'm3yAHyFEFKtbCIM5n7GF',
      'name': 'Sad / Gentle Female',
      'category': 'curated',
      'description': 'Soft solace, tender empathy, holding space',
    },
  ];

  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
    _speech.stop();
    _speakingStateController.close();
  }
}
