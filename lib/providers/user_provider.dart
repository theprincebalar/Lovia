import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/relationship.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  final StorageService _storage;

  String _userName = "";
  Set<String> _favoriteCharacterIds = {};
  Set<String> _blockedCharacterIds = {};
  List<MemoryItem> _unlockedMemories = [];
  bool _voiceAutoplay = true;

  UserProvider(this._storage) {
    _loadUserData();
  }

  String get userName => _userName;
  Set<String> get favoriteCharacterIds => _favoriteCharacterIds;
  Set<String> get blockedCharacterIds => _blockedCharacterIds;
  List<MemoryItem> get unlockedMemories => _unlockedMemories;
  bool get voiceAutoplay => _voiceAutoplay;

  void _loadUserData() {
    _userName = _storage.getUserName();
    _favoriteCharacterIds = _storage.getFavorites();
    _blockedCharacterIds = _storage.getBlockedCharacters();
    _unlockedMemories = _storage.getAllMemories();
    _voiceAutoplay = _storage.getVoiceAutoplay();
    if (_storage.hasCompletedNameOnboarding() && _userName.isNotEmpty) {
      for (final legacy in ['Alex', 'Sarah', 'Jake', 'Grace']) {
        if (_userName != legacy) {
          _storage.replaceUserNameInHistory(legacy, _userName);
        }
      }
    }
    notifyListeners();
  }

  bool get hasCompletedNameOnboarding => _storage.hasCompletedNameOnboarding();

  Future<void> setUserName(String name) async {
    final clean = name.trim();
    if (clean.isNotEmpty) {
      final oldName = _userName;
      _userName = clean;
      await _storage.setUserName(clean);
      if (oldName.isNotEmpty && oldName != clean) {
        await _storage.replaceUserNameInHistory(oldName, clean);
      }
      for (final legacy in ['Alex', 'Sarah', 'Jake', 'Grace']) {
        if (clean != legacy) {
          await _storage.replaceUserNameInHistory(legacy, clean);
        }
      }
      notifyListeners();
    }
  }

  Future<void> skipNameOnboarding() async {
    await _storage.setNameOnboardingCompleted(true);
    notifyListeners();
  }

  bool isFavorite(String characterId) {
    return _favoriteCharacterIds.contains(characterId);
  }

  Future<void> toggleFavorite(String characterId) async {
    await _storage.toggleFavorite(characterId);
    _favoriteCharacterIds = _storage.getFavorites();
    notifyListeners();
  }

  bool isCharacterBlocked(String characterId) {
    return _blockedCharacterIds.contains(characterId);
  }

  Future<void> blockCharacter(String characterId) async {
    await _storage.blockCharacter(characterId);
    _blockedCharacterIds = _storage.getBlockedCharacters();
    notifyListeners();
  }

  Future<void> unblockCharacter(String characterId) async {
    await _storage.unblockCharacter(characterId);
    _blockedCharacterIds = _storage.getBlockedCharacters();
    notifyListeners();
  }

  Future<void> reportContent({
    required String characterId,
    String? messageId,
    required String reason,
    String? details,
  }) async {
    await _storage.reportContent(
      characterId: characterId,
      messageId: messageId,
      reason: reason,
      details: details,
    );
  }

  List<Character> get blockedCharacters {
    return Character.allCharacters.where((c) => _blockedCharacterIds.contains(c.id)).toList();
  }

  Future<void> addMemory(MemoryItem memory) async {
    // Avoid duplicates with same title
    if (_unlockedMemories.any((m) => m.title == memory.title && m.characterId == memory.characterId)) {
      return;
    }
    await _storage.addMemory(memory);
    _unlockedMemories.insert(0, memory);
    notifyListeners();
  }

  List<MemoryItem> getMemoriesForCharacter(String characterId) {
    return _unlockedMemories.where((m) => m.characterId == characterId).toList();
  }

  Future<void> setVoiceAutoplay(bool value) async {
    _voiceAutoplay = value;
    await _storage.setVoiceAutoplay(value);
    notifyListeners();
  }

  bool get proactiveNotificationsEnabled => _storage.isProactiveNotificationsEnabled();

  Future<void> setProactiveNotificationsEnabled(bool value) async {
    await _storage.setProactiveNotificationsEnabled(value);
    notifyListeners();
  }

  int get giftsSentCount => _storage.getGiftsSentCount();

  List<Character> get favoriteCharacters {
    return Character.allCharacters
        .where((c) => _favoriteCharacterIds.contains(c.id) && !_blockedCharacterIds.contains(c.id))
        .toList();
  }

  Future<void> deleteAccountAndReset() async {
    await _storage.resetAllData();
    _loadUserData();
  }
}
