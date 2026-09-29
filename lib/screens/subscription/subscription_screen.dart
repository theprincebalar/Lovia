import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_plan.dart';
import '../../providers/coin_provider.dart';
import '../../services/revenue_cat_service.dart';
import '../../theme/app_colors.dart';
import '../coins/coins_tab.dart';
import '../webview/web_view_screen.dart';
import '../../services/storage_service.dart';
import '../../services/analytics_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool fromCoinsTab;

  const SubscriptionScreen({
    super.key,
    this.fromCoinsTab = false,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  // Default selected plan is Monthly (Most Popular)
  late String _selectedPlanId;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final popularPlan = SubscriptionPlan.plans.firstWhere(
      (p) => p.isPopular,
      orElse: () => SubscriptionPlan.plans.first,
    );
    _selectedPlanId = popularPlan.id;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Refresh and listen to localized store prices from Google Play / App Store
    RevenueCatService().onPricesUpdated = () {
      if (mounted) setState(() {});
    };
    RevenueCatService().refreshOfferingsAndLocalPrices();

    AnalyticsService().logViewPaywall(source: 'subscription_screen');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    RevenueCatService().onPricesUpdated = null;
    super.dispose();
  }

  Future<void> _handleSubscribe(SubscriptionPlan selectedPlan, CoinProvider coinProvider) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    AnalyticsService().logInitiateCheckout(
      itemId: selectedPlan.productId,
      priceUsd: selectedPlan.priceUsd,
      itemType: 'subscription',
    );

    await RevenueCatService().purchaseSubscriptionPackage(context, selectedPlan, coinProvider);

    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  Future<void> _handleRestorePurchases(CoinProvider coinProvider) async {
    HapticFeedback.lightImpact();
    await RevenueCatService().restorePurchases(context, coinProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CoinProvider>(
      builder: (context, coinProvider, child) {
        final activePlan = coinProvider.activeSubscription;
        final availablePlans = coinProvider.subscriptionPlans.isNotEmpty
            ? coinProvider.subscriptionPlans
            : SubscriptionPlan.plans;
        final selectedPlan = availablePlans.firstWhere(
          (p) => p.id == _selectedPlanId,
          orElse: () => availablePlans.first,
        );
        final isSelectedPlanActive =
            coinProvider.isSubscribed && activePlan?.id == selectedPlan.id;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (widget.fromCoinsTab) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const CoinsTab(fromSubscriptionScreen: true),
                      ),
                    );
                  }
                },
                child: const Row(
                  children: [
                    Icon(Icons.diamond_rounded, size: 16, color: AppColors.diamond),
                    SizedBox(width: 4),
                    Text(
                      "Diamond Store",
                      style: TextStyle(
                        color: AppColors.diamondLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                // 1. Sleek Radiant VIP Crown
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D78).withOpacity(0.35),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF2D78), Color(0xFFFF8E53), Color(0xFFFFD700)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  "LOVIA VIP CLUB",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Unlimited Romance • Real-Time Voice Talk",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF8EA3),
                  ),
                ),
                const SizedBox(height: 14),

                // Interactive Audio Whisper Note Teaser
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF241334),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF2D78).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF2D78),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "“Unlock VIP so I can whisper everything in your ear...”",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Active Subscription Status Banner
                if (coinProvider.isSubscribed && activePlan != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E2405), Color(0xFF1E1702)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppColors.gold, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      activePlan.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Unlimited Chat • ${coinProvider.voiceMinutesRemaining} Voice Mins Left",
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.goldLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 2. VIP Member Perks (Clean, visually appealing list)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1329),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "VIP Member Perks",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const _PerkRow(
                        icon: Icons.chat_bubble_rounded,
                        iconColor: Color(0xFF20BF6B),
                        title: "Unlimited Text Chat",
                        subtitle: "Endless private passion with no coin limits",
                      ),
                      const SizedBox(height: 8),
                      const _PerkRow(
                        icon: Icons.mic_rounded,
                        iconColor: Color(0xFFFF2D78),
                        title: "Dedicated Voice Talk Minutes",
                        subtitle: "Real-time two-way voice intimacy",
                      ),
                      const SizedBox(height: 8),
                      const _PerkRow(
                        icon: Icons.bolt_rounded,
                        iconColor: AppColors.gold,
                        title: "Priority AI Generation",
                        subtitle: "Instant neural responses with zero queue",
                      ),
                      const SizedBox(height: 8),
                      const _PerkRow(
                        icon: Icons.lock_open_rounded,
                        iconColor: Color(0xFF00E5FF),
                        title: "All 150+ Characters Unlocked",
                        subtitle: "Full access to every romantic personality",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Subscription Plans Selection
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Choose Your Plan",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D78).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF2D78).withOpacity(0.35)),
                        ),
                        child: const Text(
                          "Auto-Renewable",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF69B4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Plan Cards List with Clean Non-Touching Layout
                ...availablePlans.map((plan) {
                  final isSelected = plan.id == _selectedPlanId;
                  final isCurrentActive =
                      coinProvider.isSubscribed && activePlan?.id == plan.id;

                  final String dailyCost = plan.period == SubscriptionPeriod.weekly
                      ? "Just \$0.71/day"
                      : (plan.period == SubscriptionPeriod.monthly
                          ? "Just \$0.43/day"
                          : "Just \$0.22/day");

                  final String saveTag = plan.period == SubscriptionPeriod.yearly
                      ? "SAVE 65% 👑"
                      : (plan.period == SubscriptionPeriod.monthly ? "SAVE 40% 🔥" : "");

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPlanId = plan.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? (plan.isBestValue
                                ? const LinearGradient(colors: [Color(0xFF2D1E08), Color(0xFF1B1104)])
                                : const LinearGradient(colors: [Color(0xFF33132D), Color(0xFF180A22)]))
                            : const LinearGradient(colors: [Color(0xFF1A1324), Color(0xFF110C1A)]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (plan.isBestValue ? const Color(0xFFFFD700) : const Color(0xFFFF2D78))
                              : const Color(0x2BFFFFFF),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (plan.isBestValue
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFFFF2D78))
                                      .withOpacity(0.25),
                                  blurRadius: 16,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Badges Row (Completely separated from title so they never touch!)
                          if (plan.badge.isNotEmpty || saveTag.isNotEmpty || isCurrentActive) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (plan.badge.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            gradient: plan.isBestValue
                                                ? AppColors.goldGradient
                                                : AppColors.primaryGradient,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            plan.badge,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      if (saveTag.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF4B72).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFFF4B72).withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            saveTag,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFFF8EA3),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isCurrentActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF20BF6B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "CURRENT",
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
                            const SizedBox(height: 10),
                          ],

                          // Plan Title & Price Row (Spacious, bold, beautiful)
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? (plan.isBestValue ? AppColors.gold : const Color(0xFFFF2D78))
                                        : AppColors.textTertiary,
                                    width: 2,
                                  ),
                                  gradient: isSelected
                                      ? (plan.isBestValue ? AppColors.goldGradient : AppColors.primaryGradient)
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.favorite_rounded, size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  plan.title,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    RevenueCatService().getLocalizedSubscriptionPrice(plan),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    plan.period == SubscriptionPeriod.weekly
                                        ? "/wk"
                                        : (plan.period == SubscriptionPeriod.monthly ? "/mo" : "/yr"),
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Benefits & Daily Breakdown (Using Wrap to guarantee zero overflow on small screen widths)
                          Padding(
                            padding: const EdgeInsets.only(left: 34, top: 5),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  dailyCost,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? (plan.isBestValue ? AppColors.goldLight : const Color(0xFFFF8EA3))
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const Text("•", style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                                Text(
                                  plan.period == SubscriptionPeriod.yearly
                                      ? "12h Voice"
                                      : "${plan.voiceMinutes}m Voice",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF69B4),
                                  ),
                                ),
                                const Text("•", style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                                const Text(
                                  "Unlimited Chat",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF20BF6B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 18),

                // 4. Primary Pulsating Seductive CTA Button
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: selectedPlan.isBestValue
                          ? const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8E53), Color(0xFFFF2D78)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFFF2D78), Color(0xFFFF5E36), Color(0xFFFF8E53)],
                            ),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: (selectedPlan.isBestValue
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFFFF2D78))
                              .withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleSubscribe(selectedPlan, coinProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isSelectedPlanActive
                                        ? "Current Active Plan"
                                        : "Unlock VIP Access 💕 • ${RevenueCatService().getLocalizedSubscriptionPrice(selectedPlan)}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Restore & Terms Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _handleRestorePurchases(coinProvider),
                      child: const Text(
                        "Restore Purchases",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(" • ", style: TextStyle(color: AppColors.textTertiary)),
                    TextButton(
                      onPressed: () {
                        if (widget.fromCoinsTab) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => const CoinsTab(fromSubscriptionScreen: true),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        "Diamond Store",
                        style: TextStyle(
                          color: AppColors.diamondLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        final storage = StorageService();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => WebViewScreen(
                              url: storage.getTermsConditionsUrl(),
                              title: "Terms of Service & EULA",
                              fallbackHtml: """
                                <h1>Terms of Service & EULA</h1>
                                <p>Lovia subscription terms & conditions.</p>
                              """,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "Terms of Use (EULA)",
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(" • ", style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                    TextButton(
                      onPressed: () {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? "Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings after purchase."
                        : "Payment will be charged to your Google Play account at confirmation of purchase. Subscription automatically renews unless cancelled before the end of the current billing cycle. You can manage and cancel subscriptions in Google Play Subscriptions.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                      height: 1.35,
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: Colors.white38),
                      const SizedBox(width: 5),
                      Text(
                        Theme.of(context).platform == TargetPlatform.iOS
                            ? "Secured by App Store"
                            : "Secured by Google Play",
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PerkRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _PerkRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
