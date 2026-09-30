import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/mood.dart';
import '../models/scenario.dart';

import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum GenderFilter { all, female, male }

class MoodProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<Character> _customCharacters = [];
  List<Character> _serverCharacters = [];

  MoodProvider([StorageService? storageService])
      : _storageService = storageService ?? StorageService() {
    loadCustomCharacters();
    loadServerCharacters();
    syncServerCharacters();
  }

  void loadServerCharacters() {
    try {
      final cached = _storageService.getServerCharacters();
      if (cached.isNotEmpty) {
        _serverCharacters = cached;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> syncServerCharacters() async {
    try {
      // 1. Sync dynamic characters
      final serverChars = await ApiService().fetchServerCharacters();
      if (serverChars != null && serverChars.isNotEmpty) {
        _serverCharacters = serverChars;
        await _storageService.saveServerCharacters(serverChars);
        notifyListeners();
      }

      // 2. Sync dynamic API keys configured from Admin Panel
      final config = await ApiService().fetchAppConfig();
      if (config != null) {
        final geminiKey = config['geminiApiKey']?.trim() ?? '';
        final elevenLabsKey = config['elevenLabsApiKey']?.trim() ?? '';
        final privacyUrl = config['privacyPolicyUrl']?.trim() ?? '';
        final termsUrl = config['termsConditionsUrl']?.trim() ?? '';
        final safetyThreshold = config['safetyThreshold']?.trim() ?? '';
        final playStoreUrl = config['playStoreUrl']?.trim() ?? '';
        final appStoreUrl = config['appStoreUrl']?.trim() ?? '';
        if (geminiKey.isNotEmpty) {
          await _storageService.setGeminiApiKey(geminiKey);
        }
        if (elevenLabsKey.isNotEmpty) {
          await _storageService.setElevenLabsApiKey(elevenLabsKey);
        }
        if (privacyUrl.isNotEmpty) {
          await _storageService.setPrivacyPolicyUrl(privacyUrl);
        }
        if (termsUrl.isNotEmpty) {
          await _storageService.setTermsConditionsUrl(termsUrl);
        }
        if (safetyThreshold.isNotEmpty) {
          await _storageService.setSafetyThreshold(safetyThreshold);
        }
        if (playStoreUrl.isNotEmpty) {
          await _storageService.setPlayStoreUrl(playStoreUrl);
        }
        if (appStoreUrl.isNotEmpty) {
          await _storageService.setAppStoreUrl(appStoreUrl);
        }
      }
    } catch (_) {}
  }

  Mood _selectedMood = Mood.allMoods.first;
  GenderFilter _genderFilter = GenderFilter.all;
  String _searchQuery = '';
  ScenarioType? _scenarioFilter;

  Mood get selectedMood => _selectedMood;
  GenderFilter get genderFilter => _genderFilter;
  String get searchQuery => _searchQuery;
  ScenarioType? get scenarioFilter => _scenarioFilter;
  List<Character> get customCharacters => _customCharacters;

  void loadCustomCharacters() {
    try {
      _customCharacters = _storageService.getCustomCharacters();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addCustomCharacter(Character character) async {
    await _storageService.saveCustomCharacter(character);
    loadCustomCharacters();
  }

  Future<void> deleteCustomCharacter(String characterId) async {
    await _storageService.deleteCustomCharacter(characterId);
    loadCustomCharacters();
  }

  void selectMood(Mood mood) {
    _selectedMood = mood;
    AnalyticsService().logMoodSelected(moodName: mood.name);
    notifyListeners();
  }

  void setGenderFilter(GenderFilter filter) {
    _genderFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setScenarioFilter(ScenarioType? scenario) {
    _scenarioFilter = scenario;
    notifyListeners();
  }

  Set<String> _blockedCharacterIds = {};

  void updateBlockedCharacters(Set<String> blockedIds) {
    if (_blockedCharacterIds.length != blockedIds.length ||
        !_blockedCharacterIds.containsAll(blockedIds)) {
      _blockedCharacterIds = Set.from(blockedIds);
      notifyListeners();
    }
  }

  List<Character> get _baseCharacters {
    if (_serverCharacters.isNotEmpty) {
      return _serverCharacters;
    }
    return Character.allCharacters;
  }

  /// Characters matching active mood and gender filter (for Home screen)
  List<Character> get charactersForSelectedMood {
    final all = [..._customCharacters, ..._baseCharacters];
    final matched = all.where((c) {
      if (_blockedCharacterIds.contains(c.id)) return false;
      final matchesMood = c.supportedMoods.contains(_selectedMood.type);
      final matchesGender = _matchesGender(c);
      return matchesMood && matchesGender;
    }).toList();

    if (_genderFilter == GenderFilter.all) {
      return _interleaveGenders(matched);
    }
    return matched;
  }

  /// Interleaves male and female characters to ensure a rich, balanced mix in every mood
  List<Character> _interleaveGenders(List<Character> characters) {
    final males = characters.where((c) => c.gender == Gender.male).toList();
    final females = characters.where((c) => c.gender == Gender.female).toList();
    if (males.isEmpty) return females;
    if (females.isEmpty) return males;

    final mixed = <Character>[];
    int m = 0;
    int f = 0;
    bool pickFemale = true;
    while (m < males.length || f < females.length) {
      if (pickFemale && f < females.length) {
        mixed.add(females[f++]);
      } else if (!pickFemale && m < males.length) {
        mixed.add(males[m++]);
      } else if (f < females.length) {
        mixed.add(females[f++]);
      } else if (m < males.length) {
        mixed.add(males[m++]);
      }
      pickFemale = !pickFemale;
    }
    return mixed;
  }

  /// All characters filtered by search, gender, scenario, and mood (for Discover screen)
  List<Character> get filteredCharacters {
    final all = [..._customCharacters, ..._baseCharacters];
    final matched = all.where((c) {
      if (_blockedCharacterIds.contains(c.id)) return false;

      // Gender filter
      if (!_matchesGender(c)) return false;

      // Scenario filter
      if (_scenarioFilter != null && !c.supportedScenarios.contains(_scenarioFilter)) {
        return false;
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = c.name.toLowerCase().contains(query);
        final matchesTagline = c.tagline.toLowerCase().contains(query);
        final matchesBio = c.bio.toLowerCase().contains(query);
        final matchesTags = c.tags.any((t) => t.toLowerCase().contains(query));
        if (!matchesName && !matchesTagline && !matchesBio && !matchesTags) {
          return false;
        }
      }

      return true;
    }).toList();

    if (_genderFilter == GenderFilter.all && _searchQuery.trim().isEmpty) {
      return _interleaveGenders(matched);
    }
    return matched;
  }

  bool _matchesGender(Character c) {
    switch (_genderFilter) {
      case GenderFilter.all:
        return true;
      case GenderFilter.female:
        return c.gender == Gender.female;
      case GenderFilter.male:
        return c.gender == Gender.male;
    }
  }
}
