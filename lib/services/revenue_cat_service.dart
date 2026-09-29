import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/coin_wallet.dart';
import '../models/subscription_plan.dart';
import '../providers/coin_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

/// Cross-platform RevenueCat In-App Purchase & Subscription Service
/// Ported from E:\DramaPop architecture, adapted for Lovia's Provider state layer.
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

  // Reactive Localized Prices in User's Local Store Currency (e.g. ₹, $, €, £)
  final Map<SubscriptionPeriod, String> localizedSubscriptionPrices = {};
  final Map<String, String> localizedDiamondPrices = {};
  final Map<String, StoreProduct> storeProductsMap = {};
  final Map<SubscriptionPeriod, Package> subscriptionPackagesMap = {};

  CoinProvider? _coinProvider;
  StorageService? _storageService;
  VoidCallback? onPricesUpdated;

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
      final hasActiveVip = activeEntitlements.containsKey(entitlementVip) ||
          activeEntitlements.containsKey(entitlementLoviaVip) ||
          activeEntitlements.containsKey(entitlementUnlimited) ||
          activeEntitlements.containsKey(entitlementHubPro) ||
          activeEntitlements.containsKey(entitlementPremium) ||
          activeEntitlements.isNotEmpty;

      if (hasActiveVip && activeEntitlements.isNotEmpty && _coinProvider != null) {
        final activeEntitlement = activeEntitlements.values.first;
        final expStr = activeEntitlement.expirationDate;
        DateTime expiryDate = DateTime.now().add(const Duration(days: 30));
        if (expStr != null) {
          final parsed = DateTime.tryParse(expStr);
          if (parsed != null) expiryDate = parsed;
        }

        // Determine plan period from productIdentifier
        final prodId = activeEntitlement.productIdentifier.toLowerCase();
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
        // Automatically de-activate VIP if entitlement is no longer active, expired, or cancelled
        if (_coinProvider!.isSubscribed || _coinProvider!.activeSubscription != null) {
          debugPrint('🚫 RevenueCat: VIP entitlement is no longer active. Deactivating VIP plan.');
          _coinProvider!.cancelOrExpireSubscription(reason: "Store subscription expired or cancelled");
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
      final off = await Purchases.getOfferings();
      offerings = off;

      if (off.current != null) {
        final currentOffering = off.current!;
        if (currentOffering.weekly != null) {
          final p = currentOffering.weekly!;
          localizedSubscriptionPrices[SubscriptionPeriod.weekly] = p.storeProduct.priceString;
          subscriptionPackagesMap[SubscriptionPeriod.weekly] = p;
          debugPrint('🪙 Localized Weekly Subscription: ${p.storeProduct.priceString} (${p.storeProduct.currencyCode})');
        }
        if (currentOffering.monthly != null) {
          final p = currentOffering.monthly!;
          localizedSubscriptionPrices[SubscriptionPeriod.monthly] = p.storeProduct.priceString;
          subscriptionPackagesMap[SubscriptionPeriod.monthly] = p;
          debugPrint('🪙 Localized Monthly Subscription: ${p.storeProduct.priceString} (${p.storeProduct.currencyCode})');
        }
        if (currentOffering.annual != null) {
          final p = currentOffering.annual!;
          localizedSubscriptionPrices[SubscriptionPeriod.yearly] = p.storeProduct.priceString;
          subscriptionPackagesMap[SubscriptionPeriod.yearly] = p;
          debugPrint('🪙 Localized Annual Subscription: ${p.storeProduct.priceString} (${p.storeProduct.currencyCode})');
        }

        for (final pkg in currentOffering.availablePackages) {
          if (pkg.packageType == PackageType.weekly && !localizedSubscriptionPrices.containsKey(SubscriptionPeriod.weekly)) {
            localizedSubscriptionPrices[SubscriptionPeriod.weekly] = pkg.storeProduct.priceString;
            subscriptionPackagesMap[SubscriptionPeriod.weekly] = pkg;
          } else if (pkg.packageType == PackageType.monthly && !localizedSubscriptionPrices.containsKey(SubscriptionPeriod.monthly)) {
            localizedSubscriptionPrices[SubscriptionPeriod.monthly] = pkg.storeProduct.priceString;
            subscriptionPackagesMap[SubscriptionPeriod.monthly] = pkg;
          } else if (pkg.packageType == PackageType.annual && !localizedSubscriptionPrices.containsKey(SubscriptionPeriod.yearly)) {
            localizedSubscriptionPrices[SubscriptionPeriod.yearly] = pkg.storeProduct.priceString;
            subscriptionPackagesMap[SubscriptionPeriod.yearly] = pkg;
          }
        }
      }

      // Also index all packages across all offerings
      for (final offEntry in off.all.values) {
        for (final pkg in offEntry.availablePackages) {
          if (pkg.packageType == PackageType.weekly && !subscriptionPackagesMap.containsKey(SubscriptionPeriod.weekly)) {
            subscriptionPackagesMap[SubscriptionPeriod.weekly] = pkg;
            localizedSubscriptionPrices[SubscriptionPeriod.weekly] = pkg.storeProduct.priceString;
          } else if (pkg.packageType == PackageType.monthly && !subscriptionPackagesMap.containsKey(SubscriptionPeriod.monthly)) {
            subscriptionPackagesMap[SubscriptionPeriod.monthly] = pkg;
            localizedSubscriptionPrices[SubscriptionPeriod.monthly] = pkg.storeProduct.priceString;
          } else if (pkg.packageType == PackageType.annual && !subscriptionPackagesMap.containsKey(SubscriptionPeriod.yearly)) {
            subscriptionPackagesMap[SubscriptionPeriod.yearly] = pkg;
            localizedSubscriptionPrices[SubscriptionPeriod.yearly] = pkg.storeProduct.priceString;
          }
        }
      }

      // 2. Fetch Non-Subscription Diamond Products in User's Local Currency
      final Set<String> productIdsToFetch = {};
      final targetDiamondPackages = _coinProvider?.diamondPackages ?? CoinPackage.standardPackages;
      for (final diamondPkg in targetDiamondPackages) {
        productIdsToFetch.add(diamondPkg.id);
        productIdsToFetch.add('lovia_${diamondPkg.id}');
        productIdsToFetch.add('diamonds_${diamondPkg.totalCoins}');
        productIdsToFetch.add('lovia_diamonds_${diamondPkg.totalCoins}');
        productIdsToFetch.add('coins_${diamondPkg.totalCoins}');
      }

      if (productIdsToFetch.isNotEmpty) {
        List<StoreProduct> products = [];
        try {
          products = await Purchases.getProducts(
            productIdsToFetch.toList(),
            productCategory: ProductCategory.nonSubscription,
          );
        } catch (_) {
          try {
            products = await Purchases.getProducts(productIdsToFetch.toList());
          } catch (_) {}
        }

        for (final sp in products) {
          storeProductsMap[sp.identifier] = sp;
          localizedDiamondPrices[sp.identifier] = sp.priceString;
          debugPrint('🪙 Localized Diamond Product [${sp.identifier}]: ${sp.priceString} (${sp.currencyCode})');
        }
      }

      onPricesUpdated?.call();
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
    return '\$${plan.priceUsd.toStringAsFixed(2)}';
  }

  // Returns diamond package price in user's local currency (e.g. ₹89.00, €1.00, $1.00)
  String getLocalizedDiamondPrice(CoinPackage pkg) {
    final candidateKeys = [
      pkg.id,
      'lovia_${pkg.id}',
      'lovia_diamonds_${pkg.totalCoins}',
      'diamonds_${pkg.totalCoins}',
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

        if (targetPackage != null) {
          final res = await Purchases.purchase(PurchaseParams.package(targetPackage));
          customerInfo = res.customerInfo;
          _syncEntitlements(res.customerInfo);
          await coinProvider.purchaseSubscription(plan);

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
        } else {
          debugPrint('⚠️ RevenueCat: Subscription package for ${plan.period} not found in store offerings.');
        }
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
          pkg.id,
          'lovia_${pkg.id}',
          'lovia_diamonds_${pkg.totalCoins}',
          'diamonds_${pkg.totalCoins}',
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
