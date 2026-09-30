import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/character.dart';
import '../models/coin_wallet.dart';
import '../models/subscription_plan.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Strong cryptographically verified client application authentication secret
  static const String _appSecret = "lv_sec_99a87f12e0436d88b4971c26f0ac9e5d4a1b8c7e6d5f0123456789abcdef";

  /// Client application signature identifier
  static const String _clientHeader = "Lovia-Mobile-App/1.0";

  /// Configure your custom server domain here or override at runtime
  String _baseUrl = "https://lovia-api.genxappstudio.cloud";

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Internal helper to generate secure authenticated headers for all POST APIs
  Map<String, String> _getSecurityHeaders({String? deviceId}) {
    return {
      'Content-Type': 'application/json',
      'X-App-Secret': _appSecret,
      'X-Lovia-Client': _clientHeader,
      if (deviceId != null && deviceId.isNotEmpty) 'X-Device-Id': deviceId,
    };
  }

  /// Fetches dynamic characters from your server (only returns active & non-hidden characters)
  Future<List<Character>?> fetchServerCharacters() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/characters'),
        headers: _getSecurityHeaders(),
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((json) => Character.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Server dynamic sync unavailable ($e). Utilizing offline cache.");
    }
    return null;
  }

  /// Fetches dynamic neural AI keys, voice engine keys, and legal URLs configured in Admin Panel
  Future<Map<String, String>?> fetchAppConfig() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/app-config'),
        headers: _getSecurityHeaders(),
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return {
          'geminiApiKey': data['geminiApiKey'] as String? ?? '',
          'elevenLabsApiKey': data['elevenLabsApiKey'] as String? ?? '',
          'privacyPolicyUrl': data['privacyPolicyUrl'] as String? ?? '$_baseUrl/privacy',
          'termsConditionsUrl': data['termsConditionsUrl'] as String? ?? '$_baseUrl/terms',
          'safetyThreshold': data['safetyThreshold'] as String? ?? 'high',
          'playStoreUrl': data['playStoreUrl'] as String? ?? '',
          'appStoreUrl': data['appStoreUrl'] as String? ?? '',
        };
      }
    } catch (e) {
      debugPrint("Server dynamic config fetch error: $e");
    }
    return null;
  }

  /// Fetches dynamic diamond packages and VIP subscription plans configured from Admin Panel
  Future<Map<String, dynamic>?> fetchPackages() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/packages'),
        headers: _getSecurityHeaders(),
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List<dynamic> rawDiamonds = data['diamondPackages'] as List<dynamic>? ?? [];
        final List<dynamic> rawPlans = data['subscriptionPlans'] as List<dynamic>? ?? [];

        final diamondPackages = rawDiamonds
            .map((item) => CoinPackage.fromJson(item as Map<String, dynamic>))
            .toList();

        final subscriptionPlans = rawPlans
            .map((item) => SubscriptionPlan.fromJson(item as Map<String, dynamic>))
            .toList();

        return {
          'diamondPackages': diamondPackages,
          'subscriptionPlans': subscriptionPlans,
        };
      }
    } catch (e) {
      debugPrint("Server dynamic packages fetch error: $e");
    }
    return null;
  }

  /// Proxies roleplay message to server without exposing keys on device
  Future<Map<String, dynamic>?> sendServerChatMessage({
    required String characterId,
    required String userMessage,
    required List<dynamic> history,
    required String userName,
    required String currentMood,
    required String scenario,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/chat'),
        headers: _getSecurityHeaders(),
        body: jsonEncode({
          'characterId': characterId,
          'userMessage': userMessage,
          'history': history,
          'userName': userName,
          'currentMood': currentMood,
          'scenario': scenario,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Server chat proxy error: $e");
    }
    return null;
  }

  /// Syncs FCM device token and campaign eligibility with server
  Future<bool> syncNotificationCampaign({
    required String fcmToken,
    required String characterId,
    required bool isSubscribed,
    required int coinBalance,
    required bool isCampaignActive,
    int? timezoneOffsetMinutes,
    String? timezoneName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/notifications/sync-status'),
        headers: _getSecurityHeaders(),
        body: jsonEncode({
          'fcmToken': fcmToken,
          'characterId': characterId,
          'isSubscribed': isSubscribed,
          'coinBalance': coinBalance,
          'isCampaignActive': isCampaignActive,
          'timezoneOffsetMinutes': timezoneOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes,
          'timezoneName': timezoneName ?? DateTime.now().timeZoneName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Notification campaign server sync notice: $e");
      return false;
    }
  }

  /// Fetches pending balance adjustments (e.g. refunds deducted by store)
  Future<List<Map<String, dynamic>>?> fetchPendingAdjustments(String deviceId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/user/adjustments'),
        headers: _getSecurityHeaders(deviceId: deviceId),
        body: jsonEncode({'deviceId': deviceId}),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List<dynamic> adjustments = data['adjustments'] as List<dynamic>? ?? [];
        return adjustments.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Fetch adjustments error: $e");
    }
    return null;
  }

  /// Acknowledges an adjustment once applied on the local device
  Future<bool> acknowledgeAdjustment(String adjustmentId, String deviceId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/user/ack-adjustment'),
        headers: _getSecurityHeaders(deviceId: deviceId),
        body: jsonEncode({
          'id': adjustmentId,
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Ack adjustment error: $e");
      return false;
    }
  }

  /// Synthesizes real-time high-fidelity studio neural voice audio for live AI voice calls
  Future<String?> generateVoiceAudio({
    required String text,
    required Character character,
    String? archetype,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/voice/speak'),
        headers: _getSecurityHeaders(),
        body: jsonEncode({
          'text': text,
          'gender': character.gender.name,
          'archetype': archetype ?? character.primaryMood.name,
          'characterId': character.id,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final audioUrl = data['audioUrl'] as String?;
        if (audioUrl != null && audioUrl.isNotEmpty) {
          return audioUrl;
        }
      }
    } catch (e) {
      debugPrint("Server neural voice generation error: $e");
    }
    return null;
  }
}

