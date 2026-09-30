import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Unified Analytics Service providing synchronized event tracking via Firebase Analytics (Google Analytics 4).
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _firebaseAnalytics;
  FirebaseAnalyticsObserver? _observer;

  bool _isInitialized = false;

  FirebaseAnalyticsObserver? get navigatorObserver => _observer;
  FirebaseAnalytics? get firebase => _firebaseAnalytics;

  /// Initializes Firebase Analytics
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _firebaseAnalytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _firebaseAnalytics!);
      await _firebaseAnalytics!.setAnalyticsCollectionEnabled(true);
      debugPrint("📊 Firebase Analytics initialized successfully.");
    } catch (e) {
      debugPrint("ℹ️ Firebase Analytics init note: $e");
    }

    _isInitialized = true;
  }

  /// Sets user identity across Firebase
  Future<void> setUserId(String userId) async {
    try {
      await _firebaseAnalytics?.setUserId(id: userId);
    } catch (e) {
      debugPrint("Analytics setUserId note: $e");
    }
  }

  /// Logs screen transitions across the application
  Future<void> logScreenView(String screenName) async {
    try {
      await _firebaseAnalytics?.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint("Analytics logScreenView note: $e");
    }
  }

  /// Logs in-app purchase of Diamond packages for ROAS and campaign optimization
  Future<void> logPurchase({
    required String productId,
    required double priceUsd,
    required int coins,
    String currency = 'USD',
    String? transactionId,
  }) async {
    try {
      await _firebaseAnalytics?.logPurchase(
        currency: currency,
        value: priceUsd,
        transactionId: transactionId,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: '$coins Diamonds',
            itemCategory: 'currency_pack',
            price: priceUsd,
            quantity: 1,
          ),
        ],
      );
      debugPrint("💰 Analytics: Logged purchase $productId (\$$priceUsd)");
    } catch (e) {
      debugPrint("Analytics logPurchase error: $e");
    }
  }

  /// Logs VIP Subscription purchase (Weekly, Monthly, Yearly)
  Future<void> logSubscription({
    required String planId,
    required double priceUsd,
    required String period,
    String currency = 'USD',
  }) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'subscribe',
        parameters: {
          'plan_id': planId,
          'value': priceUsd,
          'currency': currency,
          'period': period,
        },
      );
      debugPrint("👑 Analytics: Logged subscription $planId (\$$priceUsd)");
    } catch (e) {
      debugPrint("Analytics logSubscription error: $e");
    }
  }

  /// Logs initiation of checkout flow when user taps a package
  Future<void> logInitiateCheckout({
    required String itemId,
    required double priceUsd,
    required String itemType, // 'diamond' or 'subscription'
  }) async {
    try {
      await _firebaseAnalytics?.logBeginCheckout(
        value: priceUsd,
        currency: 'USD',
        items: [
          AnalyticsEventItem(
            itemId: itemId,
            itemCategory: itemType,
            price: priceUsd,
          ),
        ],
      );
    } catch (e) {
      debugPrint("Analytics logInitiateCheckout note: $e");
    }
  }

  /// Logs when a paywall or coin store is shown to the user
  Future<void> logViewPaywall({required String source}) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'view_paywall',
        parameters: {'source': source},
      );
    } catch (e) {
      debugPrint("Analytics logViewPaywall note: $e");
    }
  }

  /// Logs chat message sent to an AI companion
  Future<void> logChatMessageSent({
    required String characterId,
    required String characterName,
    bool isGift = false,
    int? diamondCost,
  }) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'chat_message_sent',
        parameters: {
          'character_id': characterId,
          'character_name': characterName,
          'is_gift': isGift,
          'diamond_cost': diamondCost ?? 0,
        },
      );
    } catch (e) {
      debugPrint("Analytics logChatMessageSent note: $e");
    }
  }

  /// Logs virtual gift sent to an AI companion
  Future<void> logGiftSent({
    required String characterId,
    required String giftName,
    required int diamondCost,
  }) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'gift_sent',
        parameters: {
          'character_id': characterId,
          'gift_name': giftName,
          'diamond_cost': diamondCost,
        },
      );
    } catch (e) {
      debugPrint("Analytics logGiftSent note: $e");
    }
  }

  /// Logs voice call start
  Future<void> logVoiceCallStarted({
    required String characterId,
    required String characterName,
    required int voiceQuotaOrDiamonds,
  }) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'voice_call_started',
        parameters: {
          'character_id': characterId,
          'character_name': characterName,
          'quota': voiceQuotaOrDiamonds,
        },
      );
    } catch (e) {
      debugPrint("Analytics logVoiceCallStarted note: $e");
    }
  }

  /// Logs custom AI character creation
  Future<void> logCharacterCreated({
    required String characterName,
    required String gender,
    required String personality,
  }) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'character_created',
        parameters: {
          'character_name': characterName,
          'gender': gender,
          'personality': personality,
        },
      );
    } catch (e) {
      debugPrint("Analytics logCharacterCreated note: $e");
    }
  }

  /// Logs mood filter selected on Home Tab
  Future<void> logMoodSelected({required String moodName}) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'mood_selected',
        parameters: {'mood': moodName},
      );
    } catch (e) {
      debugPrint("Analytics logMoodSelected note: $e");
    }
  }

  /// Logs consumption of virtual currency (Diamonds)
  Future<void> logSpendVirtualCurrency({
    required String itemName,
    required int diamondsSpent,
  }) async {
    try {
      await _firebaseAnalytics?.logSpendVirtualCurrency(
        itemName: itemName,
        virtualCurrencyName: 'Diamonds',
        value: diamondsSpent.toDouble(),
      );
    } catch (e) {
      debugPrint("Analytics logSpendVirtualCurrency note: $e");
    }
  }

  /// Logs content safety report
  Future<void> logModerationReport({
    required String characterId,
    required String reason,
  }) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'report_content',
        parameters: {
          'character_id': characterId,
          'reason': reason,
        },
      );
    } catch (e) {
      debugPrint("Analytics logModerationReport note: $e");
    }
  }

  /// Logs character block
  Future<void> logCharacterBlocked({required String characterId}) async {
    try {
      await _firebaseAnalytics?.logEvent(
        name: 'block_character',
        parameters: {
          'character_id': characterId,
        },
      );
    } catch (e) {
      debugPrint("Analytics logCharacterBlocked note: $e");
    }
  }

  /// Generic custom event dispatcher
  Future<void> logCustomEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await _firebaseAnalytics?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint("Analytics logCustomEvent note: $e");
    }
  }
}
