import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/emotion_state.dart';
import '../models/message.dart';
import '../models/mood.dart';
import '../models/scenario.dart';
import '../models/relationship.dart';
import '../models/gift_item.dart';
import '../services/gemini_ai_service.dart';
import '../services/roleplay_ai_engine.dart';
import '../services/storage_service.dart';
import '../services/notification_campaign_service.dart';
import 'coin_provider.dart';
import 'user_provider.dart';

class ChatSessionSummary {
  final Character character;
  final ChatMessage lastMessage;
  final int unreadCount;
  final CharacterRelationship relationship;

  ChatSessionSummary({
    required this.character,
    required this.lastMessage,
    required this.unreadCount,
    required this.relationship,
  });
}

class ChatProvider extends ChangeNotifier {
  final StorageService _storage;
  final CoinProvider _coinProvider;
  final UserProvider _userProvider;
  final _uuid = const Uuid();

  Character? _activeCharacter;
  Scenario _activeScenario = Scenario.allScenarios.first;
  EmotionState _currentEmotion = EmotionState.happy;
  List<ChatMessage> _messages = [];
  bool _isAiTyping = false;
  CharacterRelationship _relationship = CharacterRelationship(characterId: '');

  // ignore: prefer_initializing_formals
  ChatProvider({
    required StorageService storage,
    required CoinProvider coinProvider,
    required UserProvider userProvider,
  })  : _storage = storage,
        _coinProvider = coinProvider,
        _userProvider = userProvider;

  Character? get activeCharacter => _activeCharacter;
  Scenario get activeScenario => _activeScenario;
  EmotionState get currentEmotion => _currentEmotion;
  List<ChatMessage> get messages => _messages;
  bool get isAiTyping => _isAiTyping;
  StorageService get storage => _storage;
  CharacterRelationship get relationship => _relationship;

  /// Open or resume conversation with a character
  void openChat({required Character character, Scenario? scenario}) {
    _activeCharacter = character;
    _activeScenario = scenario ?? Scenario.allScenarios.first;

    // Load relationship
    final pts = _storage.getAffection(character.id);
    _relationship = CharacterRelationship(
      characterId: character.id,
      affectionPoints: pts,
    );

    // Load message history
    _messages = _storage.getChatHistory(character.id);

    // Initial greeting if first time
    if (_messages.isEmpty) {
      _currentEmotion = _defaultEmotionForMood(character.primaryMood);
      final name = _userProvider.userName.trim();
      final greetingTemplate = character.initialGreeting;
      final personalizedGreeting = name.isNotEmpty
          ? RoleplayAiEngine.personalizeWithUserName(greetingTemplate, name)
          : greetingTemplate;

      final initialMsg = ChatMessage(
        id: _uuid.v4(),
        characterId: character.id,
        isUser: false,
        content: personalizedGreeting,
        emotion: _currentEmotion,
      );
      _messages.add(initialMsg);
      _storage.saveChatHistory(character.id, _messages);
    } else {
      _currentEmotion = _messages.last.isUser
          ? _defaultEmotionForMood(character.primaryMood)
          : _messages.last.emotion;
    }

    NotificationCampaignService().onChatInitiated(
      character: character,
      storage: _storage,
      isSubscribed: _coinProvider.isSubscribed,
      coinBalance: _coinProvider.balance,
    );

    notifyListeners();
  }

  void setScenario(Scenario scenario) {
    _activeScenario = scenario;
    notifyListeners();
  }

  /// Send message from user
  Future<bool> sendMessage(String text, MoodType currentMood) async {
    if (text.trim().isEmpty || _activeCharacter == null) return false;

    // 1. Check & deduct coins (1 coin per AI response)
    // VIP subscribers enjoy 100% UNLIMITED text chat!
    final isVip = _coinProvider.isSubscribed;
    if (!isVip && !_coinProvider.hasEnoughCoins(1)) {
      return false; // Insufficient coins!
    }

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      characterId: _activeCharacter!.id,
      isUser: true,
      content: text.trim(),
    );

    _messages.add(userMsg);
    _isAiTyping = true;
    notifyListeners();

    // Deduct coin only if user is not a VIP subscriber
    if (!isVip) {
      await _coinProvider.spendCoins(
        1,
        'Chat with ${_activeCharacter!.name}',
      );
    }

    // Generate response using Gemini AI immediately (with fallback to local roleplay engine)
    final geminiService = GeminiAiService();
    final response = await geminiService.generateRoleplayReply(
      character: _activeCharacter!,
      userInput: text,
      scenario: _activeScenario,
      currentMood: currentMood,
      relationshipLevel: _relationship.level,
      history: _messages,
      userName: _userProvider.userName,
      isVoiceCall: false,
      storageService: _storage,
    );

    _currentEmotion = response.emotion;

    final aiMsg = ChatMessage(
      id: _uuid.v4(),
      characterId: _activeCharacter!.id,
      isUser: false,
      content: response.text,
      emotion: response.emotion,
    );

    _messages.add(aiMsg);
    _isAiTyping = false;

    // Increase relationship affection (+5 XP per message)
    _relationship.addAffection(5);
    await _storage.saveAffection(_activeCharacter!.id, _relationship.affectionPoints);

    // Check memory unlock
    if (response.unlockedMemory != null) {
      await _userProvider.addMemory(response.unlockedMemory!);
    }

    // Save history
    await _storage.saveChatHistory(_activeCharacter!.id, _messages);

    notifyListeners();
    return true;
  }

  /// Sends a virtual gift to the active companion, increasing affection and triggering an emotional reaction.
  /// Returns a record with `success` and `leveledUp` status.
  Future<({bool success, bool leveledUp})> sendGift(GiftItem gift) async {
    if (_activeCharacter == null) return (success: false, leveledUp: false);

    // Check coins
    if (!_coinProvider.hasEnoughCoins(gift.coinPrice)) {
      return (success: false, leveledUp: false);
    }

    // Deduct coins
    final deducted = await _coinProvider.spendCoins(
      gift.coinPrice,
      'Gift ${gift.name} ${gift.emoji} to ${_activeCharacter!.name}',
    );
    if (!deducted) return (success: false, leveledUp: false);

    // Increment gifts sent in storage
    await _storage.incrementGiftsSent();

    // 1. Add user gift message
    final giftUserMsg = ChatMessage(
      id: _uuid.v4(),
      characterId: _activeCharacter!.id,
      isUser: true,
      content: '*sent you a ${gift.name} ${gift.emoji}*',
    );
    _messages.add(giftUserMsg);
    _isAiTyping = true;
    notifyListeners();

    // 2. Add affection points to relationship & check level up
    final leveledUp = _relationship.addGift(gift);
    await _storage.saveAffection(_activeCharacter!.id, _relationship.affectionPoints);

    // 3. Generate personality-tailored character reaction
    final reaction = RoleplayAiEngine.generateGiftReaction(
      character: _activeCharacter!,
      gift: gift,
      userName: _userProvider.userName,
      level: _relationship.level,
    );

    _currentEmotion = reaction.emotion;

    final aiReplyMsg = ChatMessage(
      id: _uuid.v4(),
      characterId: _activeCharacter!.id,
      isUser: false,
      content: reaction.text,
      emotion: reaction.emotion,
    );

    _messages.add(aiReplyMsg);
    _isAiTyping = false;

    // Save history
    await _storage.saveChatHistory(_activeCharacter!.id, _messages);

    notifyListeners();
    return (success: true, leveledUp: leveledUp);
  }

  /// Regenerate the last AI response
  Future<bool> regenerateLastResponse(MoodType currentMood) async {
    if (_messages.length < 2 || _activeCharacter == null) return false;

    // Check coins
    if (!_coinProvider.hasEnoughCoins(1)) return false;

    // Remove last AI message
    if (!_messages.last.isUser) {
      _messages.removeLast();
    }

    final lastUserMsg = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(id: '', characterId: '', isUser: true, content: 'Hello'),
    );

    _isAiTyping = true;
    notifyListeners();

    await _coinProvider.spendCoins(1, 'Regenerate reply from ${_activeCharacter!.name}');

    final geminiService = GeminiAiService();
    final response = await geminiService.generateRoleplayReply(
      character: _activeCharacter!,
      userInput: lastUserMsg.content,
      scenario: _activeScenario,
      currentMood: currentMood,
      relationshipLevel: _relationship.level,
      history: _messages,
      userName: _userProvider.userName,
      isVoiceCall: false,
      storageService: _storage,
    );

    _currentEmotion = response.emotion;

    final aiMsg = ChatMessage(
      id: _uuid.v4(),
      characterId: _activeCharacter!.id,
      isUser: false,
      content: response.text,
      emotion: response.emotion,
    );

    _messages.add(aiMsg);
    _isAiTyping = false;
    await _storage.saveChatHistory(_activeCharacter!.id, _messages);

    notifyListeners();
    return true;
  }

  /// Clear current conversation
  Future<void> clearConversation() async {
    if (_activeCharacter == null) return;
    await _storage.clearChatHistory(_activeCharacter!.id);
    _messages.clear();
    openChat(character: _activeCharacter!, scenario: _activeScenario);
  }

  /// Get list of all previous conversations for the Chats Tab
  List<ChatSessionSummary> getAllConversations() {
    final List<ChatSessionSummary> list = [];
    final allChars = [..._storage.getCustomCharacters(), ...Character.allCharacters];
    for (final char in allChars) {
      final history = _storage.getChatHistory(char.id);
      if (history.isNotEmpty) {
        final aff = _storage.getAffection(char.id);
        final rel = CharacterRelationship(characterId: char.id, affectionPoints: aff);
        list.add(
          ChatSessionSummary(
            character: char,
            lastMessage: history.last,
            unreadCount: 0,
            relationship: rel,
          ),
        );
      }
    }
    // Sort by most recent
    list.sort((a, b) => b.lastMessage.timestamp.compareTo(a.lastMessage.timestamp));
    return list;
  }

  EmotionState _defaultEmotionForMood(MoodType mood) {
    switch (mood) {
      case MoodType.romantic:
        return EmotionState.romantic;
      case MoodType.happy:
        return EmotionState.happy;
      case MoodType.sad:
        return EmotionState.sad;
      case MoodType.shy:
        return EmotionState.shy;
      case MoodType.playful:
        return EmotionState.playful;
      case MoodType.angry:
        return EmotionState.angry;
      default:
        return EmotionState.happy;
    }
  }
}
