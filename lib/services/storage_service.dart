import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../models/relationship.dart';
import '../models/coin_wallet.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyCoins = 'lovia_coins';
  static const String _keyTransactions = 'lovia_transactions';
  static const String _keyFavorites = 'lovia_favorites';
  static const String _keyChatPrefix = 'lovia_chat_';
  static const String _keyRelPrefix = 'lovia_rel_';
  static const String _keyMemories = 'lovia_all_memories';
  static const String _keyFirstRun = 'lovia_first_run_done';
  static const String _keyVoiceAutoplay = 'lovia_voice_autoplay';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Welcome gift for new user
    if (!_prefs.containsKey(_keyFirstRun)) {
      await _prefs.setBool(_keyFirstRun, true);
      await _prefs.setInt(_keyCoins, 5); // 5 Free Welcome Coins
      await addTransaction(
        CoinTransaction(
          id: 'tx_welcome',
          description: 'Welcome Gift (New Lover)',
          amount: 5,
          timestamp: DateTime.now(),
        ),
      );
    }

    // Ensure elevenlabs is active if not set or was previously local_prosody
    if (!_prefs.containsKey(_keyVoiceEngineMode) || _prefs.getString(_keyVoiceEngineMode) == 'local_prosody') {
      await _prefs.setString(_keyVoiceEngineMode, 'elevenlabs');
    }
  }

  // Coins / Diamonds
  int getCoins() => _prefs.getInt(_keyCoins) ?? 5;
  int getDiamonds() => getCoins();

  Future<void> setCoins(int coins) async {
    await _prefs.setInt(_keyCoins, coins);
  }
  Future<void> setDiamonds(int diamonds) => setCoins(diamonds);

  static const String _keySubscriptionPlan = 'lovia_sub_plan';
  static const String _keySubscriptionExpiry = 'lovia_sub_expiry';
  static const String _keySubscriptionVoiceMinutes = 'lovia_sub_voice_minutes';
  static const String _keySubscriptionLastRefillExpiry = 'lovia_sub_last_refill_expiry';

  // Subscription
  String? getSubscriptionPlanId() => _prefs.getString(_keySubscriptionPlan);

  Future<void> setSubscriptionPlanId(String? planId) async {
    if (planId == null) {
      await _prefs.remove(_keySubscriptionPlan);
    } else {
      await _prefs.setString(_keySubscriptionPlan, planId);
    }
  }

  DateTime? getSubscriptionExpiry() {
    final str = _prefs.getString(_keySubscriptionExpiry);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<void> setSubscriptionExpiry(DateTime? expiry) async {
    if (expiry == null) {
      await _prefs.remove(_keySubscriptionExpiry);
    } else {
      await _prefs.setString(_keySubscriptionExpiry, expiry.toIso8601String());
    }
  }

  int getSubscriptionVoiceMinutes() => _prefs.getInt(_keySubscriptionVoiceMinutes) ?? 0;

  Future<void> setSubscriptionVoiceMinutes(int minutes) async {
    await _prefs.setInt(_keySubscriptionVoiceMinutes, minutes < 0 ? 0 : minutes);
  }

  DateTime? getSubscriptionLastRefillExpiry() {
    final str = _prefs.getString(_keySubscriptionLastRefillExpiry);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<void> setSubscriptionLastRefillExpiry(DateTime? expiry) async {
    if (expiry == null) {
      await _prefs.remove(_keySubscriptionLastRefillExpiry);
    } else {
      await _prefs.setString(_keySubscriptionLastRefillExpiry, expiry.toIso8601String());
    }
  }

  Future<void> clearSubscription() async {
    await _prefs.remove(_keySubscriptionPlan);
    await _prefs.remove(_keySubscriptionExpiry);
    await _prefs.remove(_keySubscriptionVoiceMinutes);
    await _prefs.remove(_keySubscriptionLastRefillExpiry);
  }

  // Legacy Daily Rewards stubs
  DateTime? getLastDailyClaim() => null;
  Future<void> setLastDailyClaim(DateTime time) async {}
  int getDailyStreak() => 0;
  Future<void> setDailyStreak(int streak) async {}

  // Transactions
  List<CoinTransaction> getTransactions() {
    final raw = _prefs.getStringList(_keyTransactions) ?? [];
    return raw.map((item) {
      try {
        return CoinTransaction.fromJson(jsonDecode(item) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<CoinTransaction>().toList();
  }

  Future<void> addTransaction(CoinTransaction tx) async {
    final list = _prefs.getStringList(_keyTransactions) ?? [];
    list.insert(0, jsonEncode(tx.toJson()));
    if (list.length > 50) list.removeLast();
    await _prefs.setStringList(_keyTransactions, list);
  }

  // Favorites
  Set<String> getFavorites() {
    return (_prefs.getStringList(_keyFavorites) ?? []).toSet();
  }

  Future<void> toggleFavorite(String characterId) async {
    final favs = getFavorites();
    if (favs.contains(characterId)) {
      favs.remove(characterId);
    } else {
      favs.add(characterId);
    }
    await _prefs.setStringList(_keyFavorites, favs.toList());
  }

  // Chat History
  List<ChatMessage> getChatHistory(String characterId) {
    final raw = _prefs.getStringList('$_keyChatPrefix$characterId') ?? [];
    return raw.map((item) {
      try {
        return ChatMessage.fromJson(jsonDecode(item) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<ChatMessage>().toList();
  }

  Future<void> saveChatHistory(String characterId, List<ChatMessage> messages) async {
    final raw = messages.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs.setStringList('$_keyChatPrefix$characterId', raw);
  }

  Future<void> clearChatHistory(String characterId) async {
    await _prefs.remove('$_keyChatPrefix$characterId');
  }

  Future<void> replaceUserNameInHistory(String oldName, String newName) async {
    if (oldName == newName || oldName.isEmpty || newName.isEmpty) return;
    final keys = _prefs.getKeys().where((k) => k.startsWith(_keyChatPrefix)).toList();
    for (final key in keys) {
      final characterId = key.substring(_keyChatPrefix.length);
      final messages = getChatHistory(characterId);
      bool changed = false;
      final updatedMessages = messages.map((m) {
        if (m.content.contains(oldName)) {
          changed = true;
          return ChatMessage(
            id: m.id,
            characterId: m.characterId,
            isUser: m.isUser,
            content: m.content.replaceAll(oldName, newName),
            timestamp: m.timestamp,
            emotion: m.emotion,
            isVoiceMessage: m.isVoiceMessage,
          );
        }
        return m;
      }).toList();

      if (changed) {
        await saveChatHistory(characterId, updatedMessages);
      }
    }
  }

  // Relationship & Affection
  int getAffection(String characterId) {
    return _prefs.getInt('$_keyRelPrefix$characterId') ?? 0;
  }

  Future<void> saveAffection(String characterId, int points) async {
    await _prefs.setInt('$_keyRelPrefix$characterId', points);
  }

  // Memories
  List<MemoryItem> getAllMemories() {
    final raw = _prefs.getStringList(_keyMemories) ?? [];
    return raw.map((m) {
      try {
        return MemoryItem.fromJson(jsonDecode(m) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<MemoryItem>().toList();
  }

  Future<void> addMemory(MemoryItem memory) async {
    final list = _prefs.getStringList(_keyMemories) ?? [];
    list.insert(0, jsonEncode(memory.toJson()));
    await _prefs.setStringList(_keyMemories, list);
  }

  List<MemoryItem> getMemoriesForCharacter(String characterId) {
    return getAllMemories().where((m) => m.characterId == characterId).toList();
  }

  // Settings
  bool getVoiceAutoplay() => _prefs.getBool(_keyVoiceAutoplay) ?? true;

  Future<void> setVoiceAutoplay(bool val) async {
    await _prefs.setBool(_keyVoiceAutoplay, val);
  }

  // User Profile
  static const String _keyUserName = 'lovia_user_name';
  static const String _keyNameOnboardingCompleted = 'lovia_name_onboarding_completed';

  String getUserName() => _prefs.getString(_keyUserName) ?? '';

  bool hasCompletedNameOnboarding() => _prefs.getBool(_keyNameOnboardingCompleted) ?? false;

  Future<void> setNameOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_keyNameOnboardingCompleted, completed);
  }

  Future<void> setUserName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      await _prefs.setString(_keyUserName, trimmed);
      await _prefs.setBool(_keyNameOnboardingCompleted, true);
    }
  }

  // Proactive Notifications & Re-engagement
  static const String _keyProactiveNotifications = 'lovia_proactive_notifications_enabled';
  static const String _keyLastActiveTimestamp = 'lovia_last_active_timestamp';
  static const String _keyGiftsSentCount = 'lovia_gifts_sent_count';

  bool isProactiveNotificationsEnabled() => _prefs.getBool(_keyProactiveNotifications) ?? true;

  Future<void> setProactiveNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyProactiveNotifications, enabled);
  }

  DateTime? getLastActiveTimestamp() {
    final iso = _prefs.getString(_keyLastActiveTimestamp);
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateLastActiveTimestamp() async {
    await _prefs.setString(_keyLastActiveTimestamp, DateTime.now().toIso8601String());
  }

  int getGiftsSentCount() => _prefs.getInt(_keyGiftsSentCount) ?? 0;

  Future<void> incrementGiftsSent() async {
    await _prefs.setInt(_keyGiftsSentCount, getGiftsSentCount() + 1);
  }

  // Voice Customization Settings
  static const String _keyVoicePitchPrefix = 'lovia_voice_pitch_';
  static const String _keyVoiceRatePrefix = 'lovia_voice_rate_';
  static const String _keyVoicePersonaPrefix = 'lovia_voice_persona_';

  double getCharacterVoicePitch(String characterId, double defaultPitch) {
    return _prefs.getDouble('$_keyVoicePitchPrefix$characterId') ?? defaultPitch;
  }

  Future<void> setCharacterVoicePitch(String characterId, double pitch) async {
    await _prefs.setDouble('$_keyVoicePitchPrefix$characterId', pitch);
  }

  double getCharacterVoiceRate(String characterId, double defaultRate) {
    return _prefs.getDouble('$_keyVoiceRatePrefix$characterId') ?? defaultRate;
  }

  Future<void> setCharacterVoiceRate(String characterId, double rate) async {
    await _prefs.setDouble('$_keyVoiceRatePrefix$characterId', rate);
  }

  String? getCharacterVoicePersona(String characterId) {
    return _prefs.getString('$_keyVoicePersonaPrefix$characterId');
  }

  Future<void> setCharacterVoicePersona(String characterId, String persona) async {
    await _prefs.setString('$_keyVoicePersonaPrefix$characterId', persona);
  }

  static const String _keyGeminiApiKey = 'lovia_gemini_api_key';
  static const String _defaultGeminiApiKey = '';
  static const String _keyOpenAiApiKey = 'lovia_openai_api_key';
  static const String _keyElevenLabsApiKey = 'lovia_elevenlabs_api_key';
  static const String _defaultElevenLabsApiKey = 'sk_d7e6649f4f8002aab7ef2ed35748c37b12db4403b5d363e4';
  static const String _keyVoiceEngineMode = 'lovia_voice_engine_mode';
  static const String _keyEmotionIntensityPrefix = 'lovia_emotion_intensity_';
  static const String _keyElevenVoicePrefix = 'lovia_eleven_voice_';
  static const String _keyBlockedCharacters = 'lovia_blocked_characters';
  static const String _keyReportedContent = 'lovia_reported_content';

  String? getGeminiApiKey() {
    final key = _prefs.getString(_keyGeminiApiKey);
    if (key != null && key.isNotEmpty) return key;
    return _defaultGeminiApiKey;
  }

  Future<void> setGeminiApiKey(String key) async {
    await _prefs.setString(_keyGeminiApiKey, key.trim());
  }

  String? getOpenAiApiKey() => _prefs.getString(_keyOpenAiApiKey);

  Future<void> setOpenAiApiKey(String key) async {
    await _prefs.setString(_keyOpenAiApiKey, key.trim());
  }

  String? getElevenLabsApiKey() {
    final key = _prefs.getString(_keyElevenLabsApiKey);
    if (key != null && key.isNotEmpty) return key;
    return _defaultElevenLabsApiKey;
  }

  Future<void> setElevenLabsApiKey(String key) async {
    await _prefs.setString(_keyElevenLabsApiKey, key.trim());
  }

  String getVoiceEngineMode() => _prefs.getString(_keyVoiceEngineMode) ?? 'elevenlabs';

  Future<void> setVoiceEngineMode(String mode) async {
    await _prefs.setString(_keyVoiceEngineMode, mode);
  }

  double getCharacterEmotionIntensity(String characterId) {
    return _prefs.getDouble('$_keyEmotionIntensityPrefix$characterId') ?? 1.0;
  }

  Future<void> setCharacterEmotionIntensity(String characterId, double intensity) async {
    await _prefs.setDouble('$_keyEmotionIntensityPrefix$characterId', intensity);
  }

  String? getCharacterElevenLabsVoice(String characterId) {
    return _prefs.getString('$_keyElevenVoicePrefix$characterId');
  }

  Future<void> setCharacterElevenLabsVoice(String characterId, String voiceId) async {
    await _prefs.setString('$_keyElevenVoicePrefix$characterId', voiceId.trim());
  }

  Future<void> resetCharacterVoice(String characterId) async {
    await _prefs.remove('$_keyVoicePitchPrefix$characterId');
    await _prefs.remove('$_keyVoiceRatePrefix$characterId');
    await _prefs.remove('$_keyVoicePersonaPrefix$characterId');
    await _prefs.remove('$_keyEmotionIntensityPrefix$characterId');
    await _prefs.remove('$_keyElevenVoicePrefix$characterId');
  }

  // Safety & Moderation (Apple Guideline 1.2 & 5.6.4)
  Set<String> getBlockedCharacters() {
    return (_prefs.getStringList(_keyBlockedCharacters) ?? []).toSet();
  }

  Future<void> blockCharacter(String characterId) async {
    final list = getBlockedCharacters();
    list.add(characterId);
    await _prefs.setStringList(_keyBlockedCharacters, list.toList());
  }

  Future<void> unblockCharacter(String characterId) async {
    final list = getBlockedCharacters();
    list.remove(characterId);
    await _prefs.setStringList(_keyBlockedCharacters, list.toList());
  }

  Future<void> reportContent({
    required String characterId,
    String? messageId,
    required String reason,
    String? details,
  }) async {
    final reports = _prefs.getStringList(_keyReportedContent) ?? [];
    reports.add(jsonEncode({
      'characterId': characterId,
      'messageId': messageId,
      'reason': reason,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    await _prefs.setStringList(_keyReportedContent, reports);
  }

  List<Map<String, dynamic>> getReportedContent() {
    final reports = _prefs.getStringList(_keyReportedContent) ?? [];
    return reports.map((r) {
      try {
        return jsonDecode(r) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).toList();
  }

  // Custom AI Characters
  static const String _keyCustomCharacters = 'lovia_custom_characters';
  static const String _keyServerCharacters = 'lovia_server_characters_cache';

  List<Character> getCustomCharacters() {
    final rawList = _prefs.getStringList(_keyCustomCharacters) ?? [];
    final List<Character> results = [];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        results.add(Character.fromJson(map));
      } catch (_) {}
    }
    return results;
  }

  Future<void> saveCustomCharacter(Character character) async {
    final list = getCustomCharacters();
    final index = list.indexWhere((c) => c.id == character.id);
    if (index >= 0) {
      list[index] = character;
    } else {
      list.insert(0, character);
    }
    final rawList = list.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_keyCustomCharacters, rawList);
  }

  Future<void> deleteCustomCharacter(String characterId) async {
    final list = getCustomCharacters();
    list.removeWhere((c) => c.id == characterId);
    final rawList = list.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_keyCustomCharacters, rawList);
  }

  List<Character> getServerCharacters() {
    final rawList = _prefs.getStringList(_keyServerCharacters) ?? [];
    final List<Character> results = [];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        results.add(Character.fromJson(map));
      } catch (_) {}
    }
    return results;
  }

  Future<void> saveServerCharacters(List<Character> characters) async {
    final rawList = characters.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_keyServerCharacters, rawList);
  }

  Character? getCharacterById(String id) {
    final customList = getCustomCharacters();
    final customMatch = customList.where((c) => c.id == id);
    if (customMatch.isNotEmpty) return customMatch.first;

    final serverList = getServerCharacters();
    final serverMatch = serverList.where((c) => c.id == id);
    if (serverMatch.isNotEmpty) return serverMatch.first;

    final standardMatch = Character.allCharacters.where((c) => c.id == id);
    if (standardMatch.isNotEmpty) return standardMatch.first;

    return null;
  }

  // 3x Daily AI Companion Retention Campaign Tracking
  static const String _keyFirstChatInitiated = 'lovia_first_chat_initiated';
  static const String _keyLastChattedCharacterId = 'lovia_last_chatted_character_id';
  static const String _keyHasPurchasedPaidCoins = 'lovia_has_purchased_paid_coins';
  static const String _keyFcmToken = 'lovia_fcm_token';
  static const String _keyRetentionCampaignActive = 'lovia_retention_campaign_active';

  bool hasInitiatedFirstChat() => _prefs.getBool(_keyFirstChatInitiated) ?? false;
  Future<void> setFirstChatInitiated(bool val) async => await _prefs.setBool(_keyFirstChatInitiated, val);

  String? getLastChattedCharacterId() => _prefs.getString(_keyLastChattedCharacterId);
  Future<void> setLastChattedCharacterId(String id) async => await _prefs.setString(_keyLastChattedCharacterId, id);

  bool hasPurchasedPaidCoins() => _prefs.getBool(_keyHasPurchasedPaidCoins) ?? false;
  Future<void> setHasPurchasedPaidCoins(bool val) async => await _prefs.setBool(_keyHasPurchasedPaidCoins, val);

  String? getFcmToken() => _prefs.getString(_keyFcmToken);
  Future<void> setFcmToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keyFcmToken);
    } else {
      await _prefs.setString(_keyFcmToken, token);
    }
  }

  bool isRetentionCampaignActive() => _prefs.getBool(_keyRetentionCampaignActive) ?? false;
  Future<void> setRetentionCampaignActive(bool val) async => await _prefs.setBool(_keyRetentionCampaignActive, val);

  // Persistent Device / User ID for RevenueCat & Analytics
  static const String _keyDeviceId = 'lovia_device_id';

  String getOrCreateDeviceId() {
    String? id = _prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = 'usr_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
      _prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  // Legal & Privacy URLs
  static const String _keyPrivacyPolicyUrl = 'lovia_privacy_policy_url';
  static const String _keyTermsConditionsUrl = 'lovia_terms_conditions_url';

  String getPrivacyPolicyUrl() =>
      _prefs.getString(_keyPrivacyPolicyUrl) ?? 'https://lovia-api.genxappstudio.cloud/privacy';

  Future<void> setPrivacyPolicyUrl(String url) async =>
      await _prefs.setString(_keyPrivacyPolicyUrl, url);

  String getTermsConditionsUrl() =>
      _prefs.getString(_keyTermsConditionsUrl) ?? 'https://lovia-api.genxappstudio.cloud/terms';

  Future<void> setTermsConditionsUrl(String url) async =>
      await _prefs.setString(_keyTermsConditionsUrl, url);

  // App Store & Play Store URLs for Sharing
  static const String _keyPlayStoreUrl = 'lovia_play_store_url';
  static const String _keyAppStoreUrl = 'lovia_app_store_url';

  String getPlayStoreUrl() =>
      _prefs.getString(_keyPlayStoreUrl) ??
      'https://play.google.com/store/apps/details?id=com.lovia.ai.friend.app.lovia';

  Future<void> setPlayStoreUrl(String url) async =>
      await _prefs.setString(_keyPlayStoreUrl, url);

  String getAppStoreUrl() =>
      _prefs.getString(_keyAppStoreUrl) ??
      'https://apps.apple.com/app/id6742517865';

  Future<void> setAppStoreUrl(String url) async =>
      await _prefs.setString(_keyAppStoreUrl, url);

  // Dynamic AI Safety & Content Threshold ('medium' | 'high' | 'none')
  static const String _keySafetyThreshold = 'lovia_safety_threshold';

  String getSafetyThreshold() => _prefs.getString(_keySafetyThreshold) ?? 'high';

  Future<void> setSafetyThreshold(String threshold) async =>
      await _prefs.setString(_keySafetyThreshold, threshold);

  // Dynamic Packages Cache
  static const String _keyCachedPackages = 'lovia_cached_packages_json';

  String? getCachedPackagesJson() => _prefs.getString(_keyCachedPackages);

  Future<void> setCachedPackagesJson(String json) async =>
      await _prefs.setString(_keyCachedPackages, json);

  // In-App Rating & Review Dialog (Official Apple / Google Prompt Tracker)
  static const String _keyLastReviewPromptTime = 'lovia_last_review_prompt_time';
  static const String _keyHasMadeAnyPurchase = 'lovia_has_made_any_purchase';

  int? getLastReviewPromptTime() => _prefs.getInt(_keyLastReviewPromptTime);

  Future<void> setLastReviewPromptTime(int millis) async =>
      await _prefs.setInt(_keyLastReviewPromptTime, millis);

  bool hasMadeAnyPurchase() {
    return (_prefs.getBool(_keyHasMadeAnyPurchase) ?? false) ||
        hasPurchasedPaidCoins() ||
        getSubscriptionPlanId() != null;
  }

  Future<void> setHasMadeAnyPurchase(bool val) async =>
      await _prefs.setBool(_keyHasMadeAnyPurchase, val);

  // Reset / Delete Account
  Future<void> resetAllData() async {
    await _prefs.clear();
    await init();
  }
}
