import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/coin_wallet.dart';
import '../../providers/coin_provider.dart';
import '../../services/revenue_cat_service.dart';
import '../../theme/app_colors.dart';
import '../subscription/subscription_screen.dart';
import '../webview/web_view_screen.dart';
import '../../services/storage_service.dart';
import '../../services/analytics_service.dart';

class CoinsTab extends StatelessWidget {
  final bool fromSubscriptionScreen;

  const CoinsTab({
    super.key,
    this.fromSubscriptionScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CoinProvider>(
      builder: (context, coinProvider, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: const Text(
              "Diamond Store",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  if (fromSubscriptionScreen) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const SubscriptionScreen(fromCoinsTab: false),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const SubscriptionScreen(fromCoinsTab: true),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 17),
                label: const Text(
                  "VIP Plans",
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Seductive Glowing Diamond Vault Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1E38), Color(0xFF230F38), Color(0xFF0A1020)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.diamond.withOpacity(0.22),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF2D78).withOpacity(0.18),
                        blurRadius: 36,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.diamondLight),
                          SizedBox(width: 6),
                          Text(
                            "CURRENT BALANCE",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppColors.diamondLight,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.diamondLight),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF1E88E5)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.4),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.diamond_rounded, size: 28, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${coinProvider.balance}",
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Diamonds",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.diamondLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0x3300E5FF)),
                      const SizedBox(height: 10),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(child: _EconomyPill(icon: Icons.chat_bubble_rounded, label: "1 Diamond", subtitle: "1 Message")),
                          Expanded(child: _EconomyPill(icon: Icons.call_rounded, label: "10 Diamonds", subtitle: "1 Min Call")),
                          Expanded(child: _EconomyPill(icon: Icons.workspace_premium_rounded, label: "VIP Pass", subtitle: "Voice Included")),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. VIP Pass Banner (Direct link to separate Subscription Screen)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38143F), Color(0xFF200E30), Color(0xFF11081E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: coinProvider.isSubscribed
                          ? AppColors.gold.withOpacity(0.9)
                          : const Color(0xFFFF2D78).withOpacity(0.7),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (coinProvider.isSubscribed ? AppColors.gold : const Color(0xFFFF2D78))
                            .withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: coinProvider.isSubscribed
                                  ? AppColors.goldGradient
                                  : const LinearGradient(
                                      colors: [Color(0xFFFF2D78), Color(0xFFFF8E53)],
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: (coinProvider.isSubscribed ? AppColors.gold : const Color(0xFFFF2D78))
                                      .withOpacity(0.4),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: Icon(
                              coinProvider.isSubscribed
                                  ? Icons.workspace_premium_rounded
                                  : Icons.stars_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        "LOVIA VIP PASS",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          color: AppColors.goldLight,
                                        ),
                                      ),
                                    ),
                                    if (coinProvider.isSubscribed) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF20BF6B),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "ACTIVE",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  coinProvider.isSubscribed
                                      ? "Unlimited Chat • ${coinProvider.voiceMinutesRemaining} Voice Mins"
                                      : "Unlimited Chat & Included Voice Minutes",
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Seductive feature highlights (replaces dense boring text)
                      const Row(
                        children: [
                          Expanded(
                            child: _VipFeaturePill(
                              icon: Icons.all_inclusive_rounded,
                              label: "Unlimited Chat",
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _VipFeaturePill(
                              icon: Icons.mic_rounded,
                              label: "Voice Included",
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _VipFeaturePill(
                              icon: Icons.lock_open_rounded,
                              label: "All 150+ Lovers",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: coinProvider.isSubscribed
                              ? AppColors.goldGradient
                              : const LinearGradient(
                                  colors: [Color(0xFFFF2D78), Color(0xFFFF6A00)],
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (coinProvider.isSubscribed ? AppColors.gold : const Color(0xFFFF2D78))
                                  .withOpacity(0.35),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (fromSubscriptionScreen) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const SubscriptionScreen(fromCoinsTab: false),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const SubscriptionScreen(fromCoinsTab: true),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  coinProvider.isSubscribed
                                      ? "Manage VIP Subscription & Perks"
                                      : "View VIP Plans & Perks",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    letterSpacing: 0.3,
                                    color: coinProvider.isSubscribed ? Colors.black87 : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: coinProvider.isSubscribed ? Colors.black87 : Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3. Diamond Packages Store
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Diamond Packages",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "Instant Delivery",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.diamondLight.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...(coinProvider.diamondPackages.isNotEmpty
                        ? coinProvider.diamondPackages
                        : CoinPackage.standardPackages)
                    .map((pkg) => _buildPackageCard(context, pkg, coinProvider)),
                const SizedBox(height: 16),

                // Safe Checkout & Legal Footer
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 12, color: Colors.white38),
                          const SizedBox(width: 5),
                          Text(
                            Theme.of(context).platform == TargetPlatform.iOS
                                ? "Secured by App Store"
                                : "Secured by Google Play",
                            style: const TextStyle(fontSize: 11.5, color: Colors.white38),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final storage = StorageService();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => WebViewScreen(
                                    url: storage.getTermsConditionsUrl(),
                                    title: "Terms of Service & EULA",
                                    fallbackHtml: """
                                      <h1>Terms of Service & EULA</h1>
                                      <p>Lovia virtual diamonds terms & conditions.</p>
                                    """,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "Terms of Service",
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(" • ", style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                          GestureDetector(
                            onTap: () {
                              final storage = StorageService();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => WebViewScreen(
                                    url: storage.getPrivacyPolicyUrl(),
                                    title: "Privacy Policy",
                                    fallbackHtml: """
                                      <h1>Privacy Policy</h1>
                                      <p>Lovia values and protects your privacy.</p>
                                    """,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "Privacy Policy",
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Transaction History Log
                const Text(
                  "Recent Activity",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (coinProvider.transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "No diamond activity recorded yet.",
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                  )
                else
                  ...coinProvider.transactions.take(8).map((tx) {
                    final isPositive = tx.amount > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPositive ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                            color: isPositive ? const Color(0xFF20BF6B) : AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(tx.timestamp),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${isPositive ? '+' : ''}${tx.amount}",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isPositive ? const Color(0xFF20BF6B) : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRomanticPackageName(String id) {
    switch (id) {
      case 'pkg_20':
        return 'Spark of Chemistry';
      case 'pkg_50':
        return 'Midnight Romance';
      case 'pkg_130':
        return 'Deep Passion';
      case 'pkg_300':
        return 'Irresistible Desire';
      case 'pkg_650':
        return 'Pure Devotion';
      case 'pkg_1700':
        return 'Eternal Obsession';
      default:
        return 'Romance Pack';
    }
  }

  Widget _buildPackageCard(BuildContext context, CoinPackage pkg, CoinProvider coinProvider) {
    final romanticName = _getRomanticPackageName(pkg.id);
    final isHighlighted = pkg.isPopular || pkg.isBestValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pkg.isBestValue
              ? [const Color(0xFF2C1E0A), const Color(0xFF191104)]
              : (pkg.isPopular
                  ? [const Color(0xFF2F122C), const Color(0xFF180A1F)]
                  : [const Color(0xFF191325), const Color(0xFF100D1A)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pkg.isBestValue
              ? const Color(0xFFFFD700)
              : (pkg.isPopular
                  ? const Color(0xFFFF2D78)
                  : const Color(0x3300E5FF)),
          width: isHighlighted ? 1.6 : 1.0,
        ),
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: (pkg.isBestValue ? const Color(0xFFFFD700) : const Color(0xFFFF2D78))
                  .withOpacity(0.22),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Dedicated Badges & Bonus Row (Separated so it NEVER touches titles or buttons!)
            if (pkg.badge.isNotEmpty || pkg.bonusCoins > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (pkg.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: pkg.isBestValue
                            ? AppColors.goldGradient
                            : (pkg.isPopular
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF2D78), Color(0xFFFF6A00)],
                                  )
                                : null),
                        color: !isHighlighted ? const Color(0xFF00E5FF).withOpacity(0.2) : null,
                        borderRadius: BorderRadius.circular(6),
                        border: !isHighlighted
                            ? Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5))
                            : null,
                      ),
                      child: Text(
                        pkg.badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: (pkg.isBestValue || pkg.isPopular) ? Colors.white : AppColors.diamondLight,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (pkg.bonusCoins > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D78).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFF2D78).withOpacity(0.4)),
                      ),
                      child: Text(
                        "+${pkg.bonusCoins} BONUS FREE",
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF8EA3),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // 2. Main Row: Gemstone Icon + Titles + Price Button
            Row(
              children: [
                // Glowing Diamond Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: pkg.isBestValue
                        ? AppColors.goldGradient
                        : (pkg.isPopular
                            ? const LinearGradient(
                                colors: [Color(0xFFFF2D78), Color(0xFFFF6A00)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF1E88E5)],
                              )),
                    boxShadow: [
                      BoxShadow(
                        color: (pkg.isBestValue
                                ? AppColors.gold
                                : (pkg.isPopular ? const Color(0xFFFF2D78) : AppColors.diamond))
                            .withOpacity(0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),

                // Title and Subtitle (Handful of Diamonds, Pouch of Diamonds, etc. clearly displayed)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.diamondTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            "${pkg.coins} Diamonds",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.diamondLight,
                            ),
                          ),
                          const Text(
                            " • ",
                            style: TextStyle(color: Colors.white30, fontSize: 12),
                          ),
                          Expanded(
                            child: Text(
                              romanticName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFD4C2DC),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Price CTA Button
                Container(
                  decoration: BoxDecoration(
                    gradient: pkg.isBestValue
                        ? AppColors.goldGradient
                        : (pkg.isPopular
                            ? const LinearGradient(
                                colors: [Color(0xFFFF2D78), Color(0xFFFF6A00)],
                              )
                            : null),
                    color: !isHighlighted ? const Color(0xFF231C33) : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isHighlighted
                        ? [
                            BoxShadow(
                              color: (pkg.isBestValue ? AppColors.gold : const Color(0xFFFF2D78))
                                  .withOpacity(0.35),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                    border: !isHighlighted
                        ? Border.all(color: const Color(0x3300E5FF))
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      AnalyticsService().logInitiateCheckout(
                        itemId: pkg.productId,
                        priceUsd: pkg.priceUsd,
                        itemType: 'diamond',
                      );
                      await RevenueCatService().purchaseDiamondPackage(context, pkg, coinProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: const Size(68, 38),
                    ),
                    child: Text(
                      RevenueCatService().getLocalizedDiamondPrice(pkg),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: (pkg.isBestValue) ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EconomyPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _EconomyPill({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Icon(icon, color: AppColors.diamond, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.diamondLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _VipFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VipFeaturePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF251333),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FF2D78)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: AppColors.goldLight),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef DiamondsTab = CoinsTab;

