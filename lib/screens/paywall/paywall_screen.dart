import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/coin_wallet.dart';
import '../../providers/coin_provider.dart';
import '../../services/revenue_cat_service.dart';
import '../../theme/app_colors.dart';
import '../subscription/subscription_screen.dart';
import '../coins/coins_tab.dart';
import '../../services/analytics_service.dart';

class PaywallScreen extends StatefulWidget {
  final String? sourceAction;
  final int? requiredCoins;

  const PaywallScreen({
    super.key,
    this.sourceAction,
    this.requiredCoins,
  });

  static Future<void> show(
    BuildContext context, {
    String? sourceAction,
    int? requiredCoins,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const CoinsTab(),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with SingleTickerProviderStateMixin {
  late CoinPackage _selectedPackage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Default to 130 coins ($5) - Most Popular
    _selectedPackage = CoinPackage.standardPackages.firstWhere(
      (pkg) => pkg.id == "pkg_130",
      orElse: () => CoinPackage.standardPackages[2],
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    RevenueCatService().onPricesUpdated = () {
      if (mounted) setState(() {});
    };
    RevenueCatService().refreshOfferingsAndLocalPrices();

    AnalyticsService().logViewPaywall(source: widget.sourceAction ?? 'paywall_screen');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    RevenueCatService().onPricesUpdated = null;
    super.dispose();
  }

  Future<void> _handlePurchase(CoinProvider coinProvider) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    AnalyticsService().logInitiateCheckout(
      itemId: _selectedPackage.productId,
      priceUsd: _selectedPackage.priceUsd,
      itemType: 'diamond',
    );

    final success = await RevenueCatService().purchaseDiamondPackage(context, _selectedPackage, coinProvider);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!success) return;

    // Show celebration dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.black, size: 44),
            ),
            const SizedBox(height: 18),
            const Text(
              "Coins Added!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Successfully credited ${_selectedPackage.coins} Coins to your wallet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "New Balance: ${coinProvider.balance} Coins",
                    style: const TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Close paywall
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                child: const Text(
                  "Continue Roleplay ✨",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinProvider = Provider.of<CoinProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF090B13),
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned(
            top: -100,
            left: -50,
            right: -50,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    AppColors.gold.withOpacity(0.25),
                    const Color(0xFF7A1CAC).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const Spacer(),
                      // VIP Switcher Button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const SubscriptionScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2C1B4D), Color(0xFF1E1035)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withOpacity(0.8), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withOpacity(0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "VIP Plans",
                                style: TextStyle(
                                  color: AppColors.goldLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Hero Visual Emblem
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFDF00), Color(0xFFD4AF37), Color(0xFF996515)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withOpacity(0.5),
                                  blurRadius: 28,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.monetization_on_rounded,
                                size: 52,
                                color: Color(0xFF1F1600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        const Text(
                          "Get Roleplay Coins",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.sourceAction != null
                              ? "You need ${widget.requiredCoins ?? 'more'} coins to ${widget.sourceAction}."
                              : "Chat endlessly, start real-time voice calls, and gift companions.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Limited Time Offer Ribbon
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE94560).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE94560).withOpacity(0.6)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFFFF5252), size: 16),
                              SizedBox(width: 4),
                              Text(
                                "⚡ LIMITED TIME BONUS ACTIVE",
                                style: TextStyle(
                                  color: Color(0xFFFF8A80),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 6 Interactive Coin Packages Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.92,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: CoinPackage.standardPackages.length,
                          itemBuilder: (context, index) {
                            final pkg = CoinPackage.standardPackages[index];
                            final isSelected = _selectedPackage.id == pkg.id;

                            return _buildInteractiveTierCard(pkg, isSelected);
                          },
                        ),

                        const SizedBox(height: 20),

                        // Interactive "What You Get" Dynamic Card
                        _buildDynamicValueSummary(_selectedPackage),

                        const SizedBox(height: 16),

                        // VIP Pass Banner Card
                        _buildVipTeaserCard(context),

                        const SizedBox(height: 100), // spacing for bottom bar
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Floating CTA Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomCheckoutBar(coinProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTierCard(CoinPackage pkg, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPackage = pkg);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2E2210), Color(0xFF1A1408), Color(0xFF0F0D08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.12),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.3),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),
                  // Coins Count with Coin Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        size: 26,
                        color: isSelected ? AppColors.gold : const Color(0xFFE0E0E0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${pkg.coins}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : const Color(0xFFE8E8E8),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "COINS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isSelected ? AppColors.goldLight : Colors.white54,
                    ),
                  ),
                  const Spacer(),
                  // Price Button Pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? AppColors.goldGradient
                          : LinearGradient(
                              colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.08)],
                            ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      RevenueCatService().getLocalizedDiamondPrice(pkg),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top Badge (Popular / Best Value / Bonus)
            if (pkg.badge.isNotEmpty)
              Positioned(
                top: -8,
                left: 12,
                right: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: pkg.isBestValue
                          ? const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)])
                          : (pkg.isPopular
                              ? const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)])
                              : const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFAA771C)])),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      pkg.badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

            // Selection Checkmark
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.black, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicValueSummary(CoinPackage pkg) {
    final messages = pkg.coins;
    final callMinutes = (pkg.coins / 10).floor();
    final gifts = (pkg.coins / 25).floor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Text(
                "WHAT YOU GET WITH ${pkg.coins} COINS:",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.goldLight,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildValuePill(
                  icon: Icons.chat_bubble_rounded,
                  color: const Color(0xFF4E9F3D),
                  count: "$messages",
                  label: "Messages",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildValuePill(
                  icon: Icons.phone_in_talk_rounded,
                  color: const Color(0xFF00ADB5),
                  count: "${callMinutes}m",
                  label: "Voice Talk",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildValuePill(
                  icon: Icons.card_giftcard_rounded,
                  color: const Color(0xFFE94560),
                  count: "$gifts",
                  label: "Luxury Gifts",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValuePill({
    required IconData icon,
    required Color color,
    required String count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipTeaserCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const SubscriptionScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF27133E), Color(0xFF1B0B2E)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFF9E00), Color(0xFFFF5400)]),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Want Unlimited Messages?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    "Lovia VIP Pass includes unlimited chat & voice calls",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCheckoutBar(CoinProvider coinProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Unlock Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _handlePurchase(coinProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                elevation: 8,
                shadowColor: AppColors.gold.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Colors.black, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "Unlock ${_selectedPackage.coins} Coins • ${RevenueCatService().getLocalizedDiamondPrice(_selectedPackage)}",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 12, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text(
                "Secure 256-Bit SSL • Instant Delivery • 100% Satisfaction",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
