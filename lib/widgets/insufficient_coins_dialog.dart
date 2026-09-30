import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/coin_wallet.dart';
import '../providers/coin_provider.dart';
import '../screens/coins/coins_tab.dart';
import '../screens/subscription/subscription_screen.dart';
import '../theme/app_colors.dart';
import '../services/analytics_service.dart';
import '../services/revenue_cat_service.dart';
import 'glass_container.dart';

class InsufficientCoinsSheet extends StatelessWidget {
  final int requiredCoins;
  final String actionName;
  final VoidCallback? onCoinsAcquired;

  const InsufficientCoinsSheet({
    super.key,
    required this.requiredCoins,
    required this.actionName,
    this.onCoinsAcquired,
  });

  static void show(
    BuildContext context, {
    required int requiredCoins,
    required String actionName,
    VoidCallback? onCoinsAcquired,
  }) {
    AnalyticsService().logViewPaywall(source: 'insufficient_diamonds_$actionName');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => InsufficientCoinsSheet(
        requiredCoins: requiredCoins,
        actionName: actionName,
        onCoinsAcquired: onCoinsAcquired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CoinProvider>(
      builder: (context, coinProvider, child) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(color: AppColors.glassBorderActive, width: 1.5),
            ),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Diamond icon with glow
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.diamondGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.diamond.withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.diamond_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Need More Diamonds",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You need $requiredCoins diamonds for $actionName. Your current balance is ${coinProvider.balance} diamonds.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 20),

              // Option 1: Quick Coin Refill (20 Coins for $1.00)
              GlassContainer(
                margin: const EdgeInsets.only(bottom: 12),
                backgroundColor: const Color(0x3300E5FF),
                borderColor: const Color(0x6600E5FF),
                onTap: () async {
                  final pkg = CoinPackage.standardPackages.first; // 20 coins for $1.00
                  final success = await RevenueCatService().purchaseDiamondPackage(context, pkg, coinProvider);
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    onCoinsAcquired?.call();
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Get 20 Diamonds • ${RevenueCatService().getLocalizedDiamondPrice(CoinPackage.standardPackages.first)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const Text(
                            "Instant refill for messages & calls",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                  ],
                ),
              ),

              // Option 2: Unlock Unlimited Chat & Voice Talk (VIP)
              GlassContainer(
                margin: const EdgeInsets.only(bottom: 14),
                backgroundColor: const Color(0x338A3FFC),
                borderColor: const Color(0x668A3FFC),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const SubscriptionScreen()),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: AppColors.accent, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Unlock Unlimited Chat (VIP)",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          Text(
                            "Unlimited messages, no diamond costs + voice minutes",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                  ],
                ),
              ),

              // Option 3: Open Diamond Store
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const CoinsTab()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.diamond_rounded, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Open Diamond Store",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

typedef InsufficientDiamondsSheet = InsufficientCoinsSheet;

