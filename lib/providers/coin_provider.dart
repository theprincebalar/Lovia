import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/coin_wallet.dart';
import '../models/subscription_plan.dart';
import '../services/storage_service.dart';
import '../services/notification_campaign_service.dart';
import '../services/api_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/analytics_service.dart';

class CoinProvider extends ChangeNotifier {
  final StorageService _storage;

  int _balance = 5;
  List<CoinTransaction> _transactions = [];

  List<CoinPackage> _diamondPackages = List.from(CoinPackage.standardPackages);
  List<SubscriptionPlan> _subscriptionPlans = List.from(SubscriptionPlan.plans);

  SubscriptionPlan? _activeSubscription;
  DateTime? _subscriptionExpiry;
  int _voiceMinutesRemaining = 0;

  CoinProvider(this._storage) {
    _loadWallet();
    syncDynamicPackages();
    syncPendingAdjustments();
  }

  int get balance => _balance;
  int get diamondBalance => _balance;
  List<CoinTransaction> get transactions => _transactions;

  List<CoinPackage> get diamondPackages => _diamondPackages;
  List<SubscriptionPlan> get subscriptionPlans => _subscriptionPlans;

  SubscriptionPlan? get activeSubscription => _activeSubscription;
  DateTime? get subscriptionExpiry => _subscriptionExpiry;
  int get voiceMinutesRemaining => _voiceMinutesRemaining;

  bool get isSubscribed {
    if (_subscriptionExpiry == null) return false;
    final active = DateTime.now().isBefore(_subscriptionExpiry!);
    if (!active && _activeSubscription != null) {
      _activeSubscription = null;
      _voiceMinutesRemaining = 0;
      _storage.setSubscriptionPlanId(null);
      _storage.setSubscriptionExpiry(null);
      _storage.setSubscriptionVoiceMinutes(0);
    }
    return active;
  }

  // Deprecated reward stubs to prevent runtime crashes
  int get streak => 0;
  bool get canClaimDailyReward => false;
  Duration get timeUntilNextDailyReward => Duration.zero;

  void _loadWallet() {
    _balance = _storage.getCoins();
    _transactions = _storage.getTransactions();

    // 1. Load cached packages if available
    final cachedPackagesJson = _storage.getCachedPackagesJson();
    if (cachedPackagesJson != null && cachedPackagesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedPackagesJson) as Map<String, dynamic>;
        final List<dynamic> rawDiamonds = decoded['diamondPackages'] as List<dynamic>? ?? [];
        final List<dynamic> rawPlans = decoded['subscriptionPlans'] as List<dynamic>? ?? [];
        if (rawDiamonds.isNotEmpty) {
          _diamondPackages = rawDiamonds.map((i) => CoinPackage.fromJson(i as Map<String, dynamic>)).toList();
        }
        if (rawPlans.isNotEmpty) {
          _subscriptionPlans = rawPlans.map((i) => SubscriptionPlan.fromJson(i as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    final planId = _storage.getSubscriptionPlanId();
    _subscriptionExpiry = _storage.getSubscriptionExpiry();
    _voiceMinutesRemaining = _storage.getSubscriptionVoiceMinutes();

    if (planId != null) {
      try {
        _activeSubscription = _subscriptionPlans.firstWhere(
          (p) => p.id == planId,
          orElse: () => SubscriptionPlan.plans.firstWhere((p) => p.id == planId),
        );
      } catch (_) {
        _activeSubscription = null;
      }
    }

    // Auto-expire subscription if past expiry
    if (_subscriptionExpiry != null && DateTime.now().isAfter(_subscriptionExpiry!)) {
      _activeSubscription = null;
    }

    notifyListeners();
  }

  /// Syncs dynamic diamond packages and VIP plans configured from the Admin Panel
  Future<void> syncDynamicPackages({ApiService? apiService}) async {
    try {
      final api = apiService ?? ApiService();
      final res = await api.fetchPackages();
      if (res != null) {
        final dynamicDiamonds = res['diamondPackages'] as List<CoinPackage>?;
        final dynamicPlans = res['subscriptionPlans'] as List<SubscriptionPlan>?;

        bool changed = false;
        if (dynamicDiamonds != null && dynamicDiamonds.isNotEmpty) {
          _diamondPackages = dynamicDiamonds;
          changed = true;
        }
        if (dynamicPlans != null && dynamicPlans.isNotEmpty) {
          _subscriptionPlans = dynamicPlans;
          changed = true;
        }

        if (changed) {
          // Persist to local cache
          final cacheMap = {
            'diamondPackages': _diamondPackages.map((p) => p.toJson()).toList(),
            'subscriptionPlans': _subscriptionPlans.map((p) => p.toJson()).toList(),
          };
          await _storage.setCachedPackagesJson(jsonEncode(cacheMap));

          // Refresh store pricing with newly synced packages
          RevenueCatService().refreshOfferingsAndLocalPrices();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Packages dynamic sync note: $e");
    }
  }

  /// Check if user has sufficient coins/diamonds (1 diamond for 1 message, 10 diamonds for 1 min call)
  bool hasEnoughCoins(int requiredAmount) {
    return _balance >= requiredAmount;
  }

  bool hasEnoughDiamonds(int requiredAmount) => hasEnoughCoins(requiredAmount);

  /// Check if user has access to start or continue a voice call (has voice minutes or at least 10 diamonds)
  bool hasVoiceAccess() {
    return _voiceMinutesRemaining > 0 || _balance >= 10;
  }

  /// Deduct diamonds for text messages (1 diamond) or voice calls (10 diamonds/min)
  Future<bool> spendCoins(int amount, String description) async {
    if (_balance < amount) {
      return false;
    }

    _balance -= amount;
    await _storage.setCoins(_balance);

    // Track virtual currency spent in Firebase & Facebook Analytics
    AnalyticsService().logSpendVirtualCurrency(
      itemName: description,
      diamondsSpent: amount,
    );

    final tx = CoinTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      description: description,
      amount: -amount,
      timestamp: DateTime.now(),
    );
    await _storage.addTransaction(tx);
    _transactions.insert(0, tx);

    if (_balance <= 0 && !isSubscribed) {
      NotificationCampaignService().onPaidStatusChanged(
        isPaid: false,
        storage: _storage,
        isSubscribed: isSubscribed,
        coinBalance: _balance,
      );
    }

    notifyListeners();
    return true;
  }

  Future<bool> spendDiamonds(int amount, String description) => spendCoins(amount, description);

  /// Deduct 1 minute from the user's active subscription voice talk quota
  Future<bool> deductVoiceMinutes(int minutes) async {
    if (_voiceMinutesRemaining >= minutes) {
      _voiceMinutesRemaining -= minutes;
      await _storage.setSubscriptionVoiceMinutes(_voiceMinutesRemaining);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Purchase VIP Subscription (Weekly, Monthly, Yearly)
  Future<void> purchaseSubscription(SubscriptionPlan plan) async {
    final now = DateTime.now();
    // If user already has an active subscription, extend the expiry date
    final baseDate = (_subscriptionExpiry != null && _subscriptionExpiry!.isAfter(now))
        ? _subscriptionExpiry!
        : now;
    _subscriptionExpiry = baseDate.add(plan.duration);
    _activeSubscription = plan;

    // Credit voice talk minutes
    _voiceMinutesRemaining += plan.voiceMinutes;

    await _storage.setSubscriptionPlanId(plan.id);
    await _storage.setSubscriptionExpiry(_subscriptionExpiry);
    await _storage.setSubscriptionVoiceMinutes(_voiceMinutesRemaining);

    final tx = CoinTransaction(
      id: 'tx_sub_${DateTime.now().millisecondsSinceEpoch}',
      description: 'Subscribed to ${plan.title} (\$${plan.priceUsd}) • +${plan.voiceMinutes}m Voice',
      amount: 0,
      timestamp: now,
    );
    await _storage.addTransaction(tx);
    _transactions.insert(0, tx);

    // Stop retention campaign upon subscription
    NotificationCampaignService().onPaidStatusChanged(
      isPaid: true,
      storage: _storage,
      isSubscribed: true,
      coinBalance: _balance,
    );

    // Dual-Analytics: Log subscription conversion for Facebook Ad Network & Firebase
    AnalyticsService().logSubscription(
      planId: plan.id,
      priceUsd: plan.priceUsd,
      period: plan.period.name,
    );

    notifyListeners();
  }

  /// Synchronize subscription status from RevenueCat CustomerInfo
  Future<void> syncFromRevenueCat({
    required SubscriptionPlan plan,
    required DateTime expiry,
  }) async {
    final now = DateTime.now();
    if (expiry.isAfter(now)) {
      _subscriptionExpiry = expiry;
      _activeSubscription = plan;

      await _storage.setSubscriptionPlanId(plan.id);
      await _storage.setSubscriptionExpiry(_subscriptionExpiry);

      if (_voiceMinutesRemaining < plan.voiceMinutes) {
        _voiceMinutesRemaining = plan.voiceMinutes;
        await _storage.setSubscriptionVoiceMinutes(_voiceMinutesRemaining);
      }

      NotificationCampaignService().onPaidStatusChanged(
        isPaid: true,
        storage: _storage,
        isSubscribed: true,
        coinBalance: _balance,
      );

      notifyListeners();
    }
  }

  void refreshFromStore() {
    notifyListeners();
  }

  /// Purchase diamond package
  Future<void> purchasePackage(CoinPackage package) async {
    _balance += package.totalCoins;
    await _storage.setCoins(_balance);
    await _storage.setHasPurchasedPaidCoins(true);

    final tx = CoinTransaction(
      id: 'tx_pkg_${DateTime.now().millisecondsSinceEpoch}',
      description: 'Purchased ${package.title} (\$${package.priceUsd})',
      amount: package.totalCoins,
      timestamp: DateTime.now(),
    );
    await _storage.addTransaction(tx);
    _transactions.insert(0, tx);

    // Stop retention campaign upon paid diamond purchase
    NotificationCampaignService().onPaidStatusChanged(
      isPaid: true,
      storage: _storage,
      isSubscribed: isSubscribed,
      coinBalance: _balance,
    );

    // Dual-Analytics: Log purchase conversion for Facebook Ad Network ROAS & Firebase
    AnalyticsService().logPurchase(
      productId: package.productId,
      priceUsd: package.priceUsd,
      coins: package.totalCoins,
    );

    notifyListeners();
  }

  Future<void> purchaseDiamondPackage(CoinPackage package) => purchasePackage(package);

  /// Cancel or expire user's VIP subscription (invoked when store subscription finishes or cancels)
  Future<void> cancelOrExpireSubscription({String reason = "VIP subscription expired or cancelled"}) async {
    final hadActive = _activeSubscription != null || (_subscriptionExpiry != null && DateTime.now().isBefore(_subscriptionExpiry!));

    _activeSubscription = null;
    _subscriptionExpiry = null;
    _voiceMinutesRemaining = 0;

    await _storage.setSubscriptionPlanId(null);
    await _storage.setSubscriptionExpiry(null);
    await _storage.setSubscriptionVoiceMinutes(0);

    if (hadActive) {
      final tx = CoinTransaction(
        id: 'tx_sub_cancel_${DateTime.now().millisecondsSinceEpoch}',
        description: 'VIP Plan Deactivated ($reason)',
        amount: 0,
        timestamp: DateTime.now(),
      );
      await _storage.addTransaction(tx);
      _transactions.insert(0, tx);

      NotificationCampaignService().onPaidStatusChanged(
        isPaid: false,
        storage: _storage,
        isSubscribed: false,
        coinBalance: _balance,
      );
    }

    notifyListeners();
  }

  /// Deduct diamonds when a purchase is refunded by Google Play or Apple App Store
  Future<void> applyRefundDeduction({required int deductDiamonds, required String reason}) async {
    if (deductDiamonds <= 0) return;

    // Clamped so balance never goes below zero
    _balance = (_balance - deductDiamonds).clamp(0, 999999999);
    await _storage.setCoins(_balance);

    final tx = CoinTransaction(
      id: 'tx_refund_${DateTime.now().millisecondsSinceEpoch}',
      description: 'Refund Adjustment: -$deductDiamonds Diamonds ($reason)',
      amount: -deductDiamonds,
      timestamp: DateTime.now(),
    );
    await _storage.addTransaction(tx);
    _transactions.insert(0, tx);

    if (_balance <= 0 && !isSubscribed) {
      NotificationCampaignService().onPaidStatusChanged(
        isPaid: false,
        storage: _storage,
        isSubscribed: false,
        coinBalance: _balance,
      );
    }

    notifyListeners();
  }

  /// Synchronizes pending store refund adjustments from the server
  Future<void> syncPendingAdjustments({ApiService? apiService}) async {
    try {
      final devId = _storage.getOrCreateDeviceId();
      if (devId.isEmpty) return;

      final api = apiService ?? ApiService();
      final adjustments = await api.fetchPendingAdjustments(devId);
      if (adjustments != null && adjustments.isNotEmpty) {
        for (final adj in adjustments) {
          final id = adj['id']?.toString() ?? '';
          final type = adj['type']?.toString() ?? '';
          final deduct = (adj['deductDiamonds'] as num?)?.toInt() ?? 0;
          final reason = adj['reason']?.toString() ?? 'Store Refund';

          if (type == 'DIAMOND_DEDUCT' && deduct > 0) {
            await applyRefundDeduction(deductDiamonds: deduct, reason: reason);
          } else if (type == 'SUBSCRIPTION_REVOKED') {
            await cancelOrExpireSubscription(reason: reason);
          }

          if (id.isNotEmpty) {
            await api.acknowledgeAdjustment(id, devId);
          }
        }
      }
    } catch (e) {
      debugPrint("Refund adjustments sync note: $e");
    }
  }
}

typedef DiamondProvider = CoinProvider;

