import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/coin_wallet.dart';
import '../models/subscription_plan.dart';
import '../providers/coin_provider.dart';
import '../services/storage_service.dart';
import '../services/review_service.dart';
import '../theme/app_colors.dart';

/// Cross-platform RevenueCat In-App Purchase & Subscription Service
/// Ensures 100% accurate localized prices in user's local currency (₹, $, €, £, etc.)
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  // Production RevenueCat Public API Keys
  static const String _googleApiKey = 'goog_dxFNiHawjykLmIbnCRihTTTmVoi';
  static const String _appleApiKey = 'appl_aYEGfxfYIrKmkrgCZroHUlAFqzi';

  // Entitlement Identifiers
  static const String entitlementVip = 'vip_access';
  static const String entitlementLoviaVip = 'lovia_vip_access';
  static const String entitlementUnlimited = 'unlimited_access';
  static const String entitlementHubPro = 'dramapop_dramas_series_hub_pro';
  static const String entitlementPremium = 'premium';

  bool isConfigured = false;
  CustomerInfo? customerInfo;
  Offerings? offerings;

  // Reactive Localized Prices in User's Local Store Currency (e.g. ₹499.00, $4.99, €4.99, £4.49)
  final Map<SubscriptionPeriod, String> localizedSubscriptionPrices = {};
  final Map<String, String> localizedDiamondPrices = {};
  final Map<String, StoreProduct> storeProductsMap = {};
  final Map<SubscriptionPeriod, Package> subscriptionPackagesMap = {};

  CoinProvider? _coinProvider;
  StorageService? _storageService;

  final Set<VoidCallback> _priceListeners = {};
  VoidCallback? _legacyPricesUpdated;

  VoidCallback? get onPricesUpdated => _legacyPricesUpdated;
  set onPricesUpdated(VoidCallback? cb) {
    _legacyPricesUpdated = cb;
    if (cb != null) {
      _priceListeners.add(cb);
    }
  }

  void addPriceListener(VoidCallback listener) {
    _priceListeners.add(listener);
  }

  void removePriceListener(VoidCallback listener) {
    _priceListeners.remove(listener);
    if (_legacyPricesUpdated == listener) {
      _legacyPricesUpdated = null;
    }
  }

  void _notifyPriceListeners() {
    for (final listener in List<VoidCallback>.from(_priceListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint("Price listener notification error: $e");
      }
    }
  }

  Future<void> init({StorageService? storageService, CoinProvider? coinProvider}) async {
    _storageService = storageService ?? StorageService();
    _coinProvider = coinProvider;

    try {
      if (kIsWeb) {
        debugPrint('RevenueCat is not supported on web platforms.');
        return;
      }

      final apiKey = Platform.isIOS ? _appleApiKey : _googleApiKey;

      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final devId = _storageService?.getOrCreateDeviceId() ?? '';
      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = devId.isNotEmpty ? devId : null;
      await Purchases.configure(configuration);
      isConfigured = true;
      debugPrint(
        '💳 RevenueCat initialized successfully for ${Platform.operatingSystem} (User: ${devId.isNotEmpty ? devId : "anonymous"})',
      );

      // Listen for real-time customer info & entitlement updates
      Purchases.addCustomerInfoUpdateListener((info) {
        customerInfo = info;
        _syncEntitlements(info);
      });

      // Fetch initial customer info
      final info = await Purchases.getCustomerInfo();
      customerInfo = info;
      _syncEntitlements(info);

      // Fetch offerings & local prices automatically in user's currency
      await refreshOfferingsAndLocalPrices();
    } catch (e) {
      debugPrint('ℹ️ RevenueCat initialization note: $e');
    }
  }

  void attachCoinProvider(CoinProvider provider) {
    _coinProvider = provider;
    if (customerInfo != null) {
      _syncEntitlements(customerInfo!);
    }
  }

  void _syncEntitlements(CustomerInfo info) {
    try {
      final activeEntitlements = info.entitlements.active;
      final activeSubs = info.activeSubscriptions;

      final hasActiveEntitlement = activeEntitlements.containsKey(entitlementVip) ||
          activeEntitlements.containsKey(entitlementLoviaVip) ||
          activeEntitlements.containsKey(entitlementUnlimited) ||
          activeEntitlements.containsKey(entitlementHubPro) ||
          activeEntitlements.containsKey(entitlementPremium) ||
          activeEntitlements.isNotEmpty;

      final hasActiveSubscription = activeSubs.isNotEmpty;
      final hasActiveVip = hasActiveEntitlement || hasActiveSubscription;

      if (hasActiveVip && _coinProvider != null) {
        DateTime expiryDate = DateTime.now().add(const Duration(days: 30));
        String prodId = '';

        if (activeEntitlements.isNotEmpty) {
          final activeEntitlement = activeEntitlements.values.first;
          final expStr = activeEntitlement.expirationDate;
          if (expStr != null) {
            final parsed = DateTime.tryParse(expStr);
            if (parsed != null) expiryDate = parsed;
          }
          prodId = activeEntitlement.productIdentifier.toLowerCase();
        } else if (activeSubs.isNotEmpty) {
          prodId = activeSubs.first.toLowerCase();
          final expStr = info.allExpirationDates[activeSubs.first];
          if (expStr != null) {
            final parsed = DateTime.tryParse(expStr);
            if (parsed != null) expiryDate = parsed;
          }
        }

        // Determine plan period from productIdentifier
        SubscriptionPlan matchedPlan;
        if (prodId.contains('weekly') || prodId.contains('week')) {
          matchedPlan = SubscriptionPlan.plans.firstWhere(
            (p) => p.period == SubscriptionPeriod.weekly,
            orElse: () => SubscriptionPlan.plans[0],
          );
        } else if (prodId.contains('yearly') || prodId.contains('annual') || prodId.contains('year')) {
          matchedPlan = SubscriptionPlan.plans.firstWhere(
            (p) => p.period == SubscriptionPeriod.yearly,
            orElse: () => SubscriptionPlan.plans[2],
          );
        } else {
          matchedPlan = SubscriptionPlan.plans.firstWhere(
            (p) => p.period == SubscriptionPeriod.monthly,
            orElse: () => SubscriptionPlan.plans[1],
          );
        }

        _coinProvider?.syncFromRevenueCat(
          plan: matchedPlan,
          expiry: expiryDate,
        );
      } else if (!hasActiveVip && _coinProvider != null) {
        // Only de-activate VIP if local plan has actually reached its stored expiration date
        final localExpiry = _coinProvider?.subscriptionExpiry;
        if (localExpiry != null && DateTime.now().isAfter(localExpiry)) {
          if (_coinProvider!.isSubscribed || _coinProvider!.activeSubscription != null) {
            debugPrint('🚫 RevenueCat: VIP plan has reached expiration date. Deactivating.');
            _coinProvider!.cancelOrExpireSubscription(reason: "Store subscription expired");
          }
        }
      }
    } catch (e) {
      debugPrint('RevenueCat entitlement sync error: $e');
    }
  }

  /// Checks real-time customer info from RevenueCat and synchronizes subscription status
  Future<void> checkAndSyncStatus() async {
    if (!isConfigured || kIsWeb) return;
    try {
      final info = await Purchases.getCustomerInfo();
      customerInfo = info;
      _syncEntitlements(info);
    } catch (e) {
      debugPrint('RevenueCat checkAndSyncStatus note: $e');
    }
  }

  // Automatically fetches prices in the user's localized currency from Google Play / Apple App Store
  Future<void> refreshOfferingsAndLocalPrices() async {
    try {
      if (!isConfigured) return;

      // 1. Fetch Subscription Offerings in User's Local Currency
      try {
        final off = await Purchases.getOfferings();
        offerings = off;

        if (off.current != null) {
          final currentOffering = off.current!;
          if (currentOffering.weekly != null) {
            final p = currentOffering.weekly!;
            localizedSubscriptionPrices[SubscriptionPeriod.weekly] = p.storeProduct.priceString;
            subscriptionPackagesMap[SubscriptionPeriod.weekly] = p;
            storeProductsMap[p.storeProduct.identifier] = p.storeProduct;
            debugPrint('🪙 Localized Offering Weekly: ${p.storeProduct.priceString} (${p.storeProduct.currencyCode})');
          }
          if (currentOffering.monthly != null) {
            final p = currentOffering.monthly!;
            localizedSubscriptionPrices[SubscriptionPeriod.monthly] = p.storeProduct.priceString;
            subscriptionPackagesMap[SubscriptionPeriod.monthly] = p;
            storeProductsMap[p.storeProduct.identifier] = p.storeProduct;
            debugPrint('🪙 Localized Offering Monthly: ${p.storeProduct.priceString} (${p.storeProduct.currencyCode})');
          }
          if (currentOffering.annual != null) {
            final p = currentOffering.annual!;
            localizedSubscriptionPrices[SubscriptionPeriod.yearly] = p.storeProduct.priceString;
            subscriptionPackagesMap[SubscriptionPeriod.yearly] = p;
            storeProductsMap[p.storeProduct.identifier] = p.storeProduct;
            debugPrint('🪙 Localized Offering Annual: ${p.storeProduct.priceString} (${p.storeProduct.currencyCode})');
          }

          for (final pkg in currentOffering.availablePackages) {
            final pId = pkg.storeProduct.identifier.toLowerCase();
            final pkgId = pkg.identifier.toLowerCase();
            storeProductsMap[pkg.storeProduct.identifier] = pkg.storeProduct;
            storeProductsMap[pkg.identifier] = pkg.storeProduct;

            final isWeekly = pkg.packageType == PackageType.weekly ||
                pId == 'lovia_vip_weekly' ||
                pkgId == 'lovia_vip_weekly' ||
                pId.contains('weekly') ||
                pkgId.contains('weekly');

            final isMonthly = pkg.packageType == PackageType.monthly ||
                pId == 'lovia_vip_monthly' ||
                pkgId == 'lovia_vip_monthly' ||
                pId.contains('monthly') ||
                pkgId.contains('monthly');

            final isYearly = pkg.packageType == PackageType.annual ||
                pId == 'lovia_vip_yearly' ||
                pkgId == 'lovia_vip_yearly' ||
                pId.contains('yearly') ||
                pId.contains('annual') ||
                pkgId.contains('yearly') ||
                pkgId.contains('annual');

            if (isWeekly && !localizedSubscriptionPrices.containsKey(SubscriptionPeriod.weekly)) {
              localizedSubscriptionPrices[SubscriptionPeriod.weekly] = pkg.storeProduct.priceString;
              subscriptionPackagesMap[SubscriptionPeriod.weekly] = pkg;
            } else if (isMonthly && !localizedSubscriptionPrices.containsKey(SubscriptionPeriod.monthly)) {
              localizedSubscriptionPrices[SubscriptionPeriod.monthly] = pkg.storeProduct.priceString;
              subscriptionPackagesMap[SubscriptionPeriod.monthly] = pkg;
            } else if (isYearly && !localizedSubscriptionPrices.containsKey(SubscriptionPeriod.yearly)) {
              localizedSubscriptionPrices[SubscriptionPeriod.yearly] = pkg.storeProduct.priceString;
              subscriptionPackagesMap[SubscriptionPeriod.yearly] = pkg;
            }
          }
        }

        // Also index all packages across all offerings
        for (final offEntry in off.all.values) {
          for (final pkg in offEntry.availablePackages) {
            final pId = pkg.storeProduct.identifier.toLowerCase();
            final pkgId = pkg.identifier.toLowerCase();
            storeProductsMap[pkg.storeProduct.identifier] = pkg.storeProduct;
            storeProductsMap[pkg.identifier] = pkg.storeProduct;

            final isWeekly = pkg.packageType == PackageType.weekly ||
                pId == 'lovia_vip_weekly' ||
                pkgId == 'lovia_vip_weekly' ||
                pId.contains('weekly') ||
                pkgId.contains('weekly');

            final isMonthly = pkg.packageType == PackageType.monthly ||
                pId == 'lovia_vip_monthly' ||
                pkgId == 'lovia_vip_monthly' ||
                pId.contains('monthly') ||
                pkgId.contains('monthly');

            final isYearly = pkg.packageType == PackageType.annual ||
                pId == 'lovia_vip_yearly' ||
                pkgId == 'lovia_vip_yearly' ||
                pId.contains('yearly') ||
                pId.contains('annual') ||
                pkgId.contains('yearly') ||
                pkgId.contains('annual');

            if (isWeekly && !subscriptionPackagesMap.containsKey(SubscriptionPeriod.weekly)) {
              subscriptionPackagesMap[SubscriptionPeriod.weekly] = pkg;
              localizedSubscriptionPrices[SubscriptionPeriod.weekly] = pkg.storeProduct.priceString;
            } else if (isMonthly && !subscriptionPackagesMap.containsKey(SubscriptionPeriod.monthly)) {
              subscriptionPackagesMap[SubscriptionPeriod.monthly] = pkg;
              localizedSubscriptionPrices[SubscriptionPeriod.monthly] = pkg.storeProduct.priceString;
            } else if (isYearly && !subscriptionPackagesMap.containsKey(SubscriptionPeriod.yearly)) {
              subscriptionPackagesMap[SubscriptionPeriod.yearly] = pkg;
              localizedSubscriptionPrices[SubscriptionPeriod.yearly] = pkg.storeProduct.priceString;
            }
          }
        }
      } catch (e) {
        debugPrint('ℹ️ Purchases.getOfferings note: $e');
      }

      // 2. Fetch Subscription Products directly from Store in User's Local Currency
      final Set<String> subscriptionProductIds = {
        'lovia_vip_weekly',
        'lovia_vip_monthly',
        'lovia_vip_yearly',
        'sub_weekly',
        'sub_monthly',
        'sub_yearly',
        'weekly',
        'monthly',
        'yearly',
      };
      final targetSubPlans = _coinProvider?.subscriptionPlans ?? SubscriptionPlan.plans;
      for (final plan in targetSubPlans) {
        subscriptionProductIds.add(plan.productId);
        subscriptionProductIds.add(plan.id);
        subscriptionProductIds.add('lovia_vip_${plan.period.name}');
      }

      try {
        List<StoreProduct> subProducts = [];
        try {
          subProducts = await Purchases.getProducts(
            subscriptionProductIds.toList(),
            productCategory: ProductCategory.subscription,
          );
        } catch (_) {
          subProducts = await Purchases.getProducts(subscriptionProductIds.toList());
        }

        for (final sp in subProducts) {
          storeProductsMap[sp.identifier] = sp;
          final idLower = sp.identifier.toLowerCase();
          if (idLower.contains('weekly') || idLower.contains('week')) {
            localizedSubscriptionPrices[SubscriptionPeriod.weekly] = sp.priceString;
          } else if (idLower.contains('yearly') || idLower.contains('annual') || idLower.contains('year')) {
            localizedSubscriptionPrices[SubscriptionPeriod.yearly] = sp.priceString;
          } else if (idLower.contains('monthly') || idLower.contains('month')) {
            localizedSubscriptionPrices[SubscriptionPeriod.monthly] = sp.priceString;
          }
          debugPrint('🪙 Localized Subscription Product [${sp.identifier}]: ${sp.priceString} (${sp.currencyCode})');
        }
      } catch (e) {
        debugPrint('ℹ️ Subscription getProducts note: $e');
      }

      // 3. Fetch Non-Subscription Diamond Products in User's Local Currency
      final Set<String> diamondProductIds = {
        'lovia_diamonds_20',
        'lovia_diamonds_50',
        'lovia_diamonds_130',
        'lovia_diamonds_300',
        'lovia_diamonds_650',
        'lovia_diamonds_1700',
        'pkg_20',
        'pkg_50',
        'pkg_130',
        'pkg_300',
        'pkg_650',
        'pkg_1700',
        'diamonds_20',
        'diamonds_50',
        'diamonds_130',
        'diamonds_300',
        'diamonds_650',
        'diamonds_1700',
      };
      final targetDiamondPackages = _coinProvider?.diamondPackages ?? CoinPackage.standardPackages;
      for (final diamondPkg in targetDiamondPackages) {
        diamondProductIds.add(diamondPkg.productId);
        diamondProductIds.add(diamondPkg.id);
        diamondProductIds.add('lovia_${diamondPkg.id}');
        diamondProductIds.add('diamonds_${diamondPkg.coins}');
        diamondProductIds.add('diamonds_${diamondPkg.totalCoins}');
        diamondProductIds.add('lovia_diamonds_${diamondPkg.coins}');
        diamondProductIds.add('lovia_diamonds_${diamondPkg.totalCoins}');
        diamondProductIds.add('coins_${diamondPkg.coins}');
        diamondProductIds.add('coins_${diamondPkg.totalCoins}');
      }

      try {
        List<StoreProduct> diamondProducts = [];
        try {
          diamondProducts = await Purchases.getProducts(
            diamondProductIds.toList(),
            productCategory: ProductCategory.nonSubscription,
          );
        } catch (_) {
          diamondProducts = await Purchases.getProducts(diamondProductIds.toList());
        }

        for (final sp in diamondProducts) {
          storeProductsMap[sp.identifier] = sp;
          localizedDiamondPrices[sp.identifier] = sp.priceString;

          // Extract numeric value from identifier to populate aliases
          final match = RegExp(r'(\d+)').firstMatch(sp.identifier);
          if (match != null) {
            final numStr = match.group(1)!;
            localizedDiamondPrices['pkg_$numStr'] = sp.priceString;
            localizedDiamondPrices['lovia_diamonds_$numStr'] = sp.priceString;
            localizedDiamondPrices['diamonds_$numStr'] = sp.priceString;
            localizedDiamondPrices['coins_$numStr'] = sp.priceString;
          }
          debugPrint('🪙 Localized Diamond Product [${sp.identifier}]: ${sp.priceString} (${sp.currencyCode})');
        }
      } catch (e) {
        debugPrint('ℹ️ Diamond getProducts note: $e');
      }

      _notifyPriceListeners();
      _coinProvider?.refreshFromStore();
    } catch (e) {
      debugPrint('ℹ️ RevenueCat local prices note: $e');
    }
  }

  // Returns plan price in user's local currency (e.g. ₹499.00, €12.99, $12.99)
  String getLocalizedSubscriptionPrice(SubscriptionPlan plan) {
    if (localizedSubscriptionPrices.containsKey(plan.period)) {
      return localizedSubscriptionPrices[plan.period]!;
    }
    if (storeProductsMap.containsKey(plan.productId)) {
      return storeProductsMap[plan.productId]!.priceString;
    }
    if (storeProductsMap.containsKey(plan.id)) {
      return storeProductsMap[plan.id]!.priceString;
    }

    final periodStr = plan.period.name.toLowerCase();
    for (final entry in storeProductsMap.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains(periodStr) || key == plan.productId.toLowerCase() || key == plan.id.toLowerCase()) {
        return entry.value.priceString;
      }
    }

    final pkg = subscriptionPackagesMap[plan.period];
    if (pkg != null) {
      return pkg.storeProduct.priceString;
    }

    return '\$${plan.priceUsd.toStringAsFixed(2)}';
  }

  // Returns diamond package price in user's local currency (e.g. ₹89.00, €1.00, $1.00)
  String getLocalizedDiamondPrice(CoinPackage pkg) {
    final candidateKeys = [
      pkg.productId,
      pkg.id,
      'lovia_${pkg.id}',
      'lovia_diamonds_${pkg.coins}',
      'lovia_diamonds_${pkg.totalCoins}',
      'diamonds_${pkg.coins}',
      'diamonds_${pkg.totalCoins}',
      'coins_${pkg.coins}',
      'coins_${pkg.totalCoins}',
    ];

    for (final key in candidateKeys) {
      if (localizedDiamondPrices.containsKey(key)) {
        return localizedDiamondPrices[key]!;
      }
      if (storeProductsMap.containsKey(key)) {
        return storeProductsMap[key]!.priceString;
      }
    }

    for (final sp in storeProductsMap.values) {
      final idLower = sp.identifier.toLowerCase();
      if (idLower == pkg.productId.toLowerCase() ||
          idLower == pkg.id.toLowerCase() ||
          idLower.contains('_${pkg.coins}') ||
          idLower.contains('_${pkg.totalCoins}')) {
        return sp.priceString;
      }
    }

    return '\$${pkg.priceUsd.toStringAsFixed(2)}';
  }

  // Handles real in-app subscription purchase through Google Play / Apple App Store
  Future<bool> purchaseSubscriptionPackage(
    BuildContext context,
    SubscriptionPlan plan,
    CoinProvider coinProvider,
  ) async {
    try {
      if (isConfigured) {
        Package? targetPackage = subscriptionPackagesMap[plan.period];
        if (targetPackage == null && offerings?.current != null) {
          final currentOffering = offerings!.current!;
          if (plan.period == SubscriptionPeriod.weekly) {
            targetPackage = currentOffering.weekly;
          } else if (plan.period == SubscriptionPeriod.monthly) {
            targetPackage = currentOffering.monthly;
          } else if (plan.period == SubscriptionPeriod.yearly) {
            targetPackage = currentOffering.annual;
          }
        }

        if (targetPackage == null && offerings != null) {
          for (final offEntry in offerings!.all.values) {
            for (final pkg in offEntry.availablePackages) {
              final spId = pkg.storeProduct.identifier.toLowerCase();
              final pkgId = pkg.identifier.toLowerCase();
              if (spId == plan.productId.toLowerCase() ||
                  pkgId == plan.productId.toLowerCase() ||
                  spId == plan.id.toLowerCase() ||
                  pkgId == plan.id.toLowerCase() ||
                  spId.contains(plan.period.name) ||
                  pkgId.contains(plan.period.name)) {
                targetPackage = pkg;
                break;
              }
            }
            if (targetPackage != null) break;
          }
        }

        if (targetPackage != null) {
          final res = await Purchases.purchase(PurchaseParams.package(targetPackage));
          customerInfo = res.customerInfo;
          _syncEntitlements(res.customerInfo);
          await coinProvider.purchaseSubscription(plan);

          // Request official store rating dialog (rate limited to once per 24h)
          ReviewService().requestPostPurchaseReview();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Welcome to ${plan.title}! Unlimited Chat & +${plan.voiceMinutes}m Voice Active! 🎉",
                ),
                backgroundColor: const Color(0xFF20BF6B),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return true;
        }

        // Fallback to StoreProduct purchase if RevenueCat package is not in Offerings
        StoreProduct? targetStoreProduct;
        final candidateSubIds = [
          plan.productId,
          plan.id,
          'lovia_vip_${plan.period.name}',
          'lovia_${plan.id}',
          plan.period.name,
        ];
        for (final id in candidateSubIds) {
          if (storeProductsMap.containsKey(id)) {
            targetStoreProduct = storeProductsMap[id];
            break;
          }
        }

        if (targetStoreProduct == null) {
          try {
            final prods = await Purchases.getProducts(
              candidateSubIds,
              productCategory: ProductCategory.subscription,
            );
            if (prods.isNotEmpty) {
              targetStoreProduct = prods.first;
              storeProductsMap[targetStoreProduct.identifier] = targetStoreProduct;
            }
          } catch (_) {
            try {
              final prods = await Purchases.getProducts(candidateSubIds);
              if (prods.isNotEmpty) {
                targetStoreProduct = prods.first;
                storeProductsMap[targetStoreProduct.identifier] = targetStoreProduct;
              }
            } catch (_) {}
          }
        }

        if (targetStoreProduct != null) {
          final res = await Purchases.purchase(PurchaseParams.storeProduct(targetStoreProduct));
          customerInfo = res.customerInfo;
          _syncEntitlements(res.customerInfo);
          await coinProvider.purchaseSubscription(plan);

          // Request official store rating dialog (rate limited to once per 24h)
          ReviewService().requestPostPurchaseReview();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Welcome to ${plan.title}! Unlimited Chat & +${plan.voiceMinutes}m Voice Active! 🎉",
                ),
                backgroundColor: const Color(0xFF20BF6B),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return true;
        }

        debugPrint('⚠️ RevenueCat: Subscription package for ${plan.period} not found in store offerings.');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Subscription plans are currently unavailable. Please verify your Google Play / App Store connection or try again later.",
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return false;
    } catch (e) {
      debugPrint('Subscription purchase error: $e');
      final isCancelled = e.toString().toLowerCase().contains('cancel') ||
          e.toString().toLowerCase().contains('user_cancelled');
      if (context.mounted) {
        if (isCancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("The subscription purchase was cancelled."),
              backgroundColor: const Color(0xFF1E1035),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Payment could not be processed. Please check your store payment method and try again.",
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
      return false;
    }
  }

  // Handles real in-app consumable diamond purchase through Google Play / Apple App Store
  Future<bool> purchaseDiamondPackage(
    BuildContext context,
    CoinPackage pkg,
    CoinProvider coinProvider,
  ) async {
    try {
      if (isConfigured) {
        StoreProduct? targetProduct;
        final candidateKeys = [
          pkg.productId,
          pkg.id,
          'lovia_${pkg.id}',
          'lovia_diamonds_${pkg.coins}',
          'lovia_diamonds_${pkg.totalCoins}',
          'diamonds_${pkg.coins}',
          'diamonds_${pkg.totalCoins}',
          'coins_${pkg.coins}',
          'coins_${pkg.totalCoins}',
        ];

        for (final k in candidateKeys) {
          if (storeProductsMap.containsKey(k)) {
            targetProduct = storeProductsMap[k];
            break;
          }
        }

        if (targetProduct == null) {
          try {
            final products = await Purchases.getProducts(
              candidateKeys,
              productCategory: ProductCategory.nonSubscription,
            );
            if (products.isNotEmpty) {
              targetProduct = products.first;
              storeProductsMap[targetProduct.identifier] = targetProduct;
            }
          } catch (_) {
            try {
              final products = await Purchases.getProducts(candidateKeys);
              if (products.isNotEmpty) {
                targetProduct = products.first;
                storeProductsMap[targetProduct.identifier] = targetProduct;
              }
            } catch (_) {}
          }
        }

        if (targetProduct != null) {
          final res = await Purchases.purchase(PurchaseParams.storeProduct(targetProduct));
          customerInfo = res.customerInfo;
          await coinProvider.purchasePackage(pkg);

          // Request official store rating dialog (rate limited to once per 24h)
          ReviewService().requestPostPurchaseReview();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Added ${pkg.totalCoins} Diamonds to your vault! 💎"),
                backgroundColor: const Color(0xFF20BF6B),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return true;
        } else {
          debugPrint('⚠️ RevenueCat: StoreProduct for ${pkg.id} not found in store offerings.');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Diamond store packages are currently unavailable. Please verify your Google Play / App Store connection or try again later.",
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return false;
    } catch (e) {
      debugPrint('Diamond purchase error: $e');
      final isCancelled = e.toString().toLowerCase().contains('cancel') ||
          e.toString().toLowerCase().contains('user_cancelled');
      if (context.mounted) {
        if (isCancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("The diamond purchase was cancelled."),
              backgroundColor: const Color(0xFF1E1035),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Payment could not be processed. Please check your store payment method and try again.",
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
      return false;
    }
  }

  // Restore purchases across devices from Google Play / Apple App Store
  Future<void> restorePurchases(BuildContext context, CoinProvider coinProvider) async {
    final isApple = Theme.of(context).platform == TargetPlatform.iOS;
    final storeName = isApple ? "App Store" : "Google Play";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Checking $storeName for active purchases..."),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    try {
      if (isConfigured) {
        final res = await Purchases.restorePurchases();
        customerInfo = res;
        _syncEntitlements(res);

        final activeEntitlements = res.entitlements.active;
        final hasActiveVip = activeEntitlements.containsKey(entitlementVip) ||
            activeEntitlements.containsKey(entitlementLoviaVip) ||
            activeEntitlements.containsKey(entitlementUnlimited) ||
            activeEntitlements.containsKey(entitlementHubPro) ||
            activeEntitlements.isNotEmpty ||
            coinProvider.isSubscribed;

        if (context.mounted) {
          if (hasActiveVip) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Restored: ${coinProvider.activeSubscription?.title ?? 'VIP Pass'} is active! 🎉",
                ),
                backgroundColor: const Color(0xFF20BF6B),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("No previous subscriptions found on this account."),
                backgroundColor: Color(0xFF1E88E5),
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not connect to $storeName. Please check your internet connection and try again."),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Restore purchases error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not restore purchases from $storeName: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
