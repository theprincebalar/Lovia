import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/review_service.dart';
import '../theme/app_colors.dart';
import '../widgets/welcome_name_dialog.dart';
import 'create/create_character_screen.dart';
import 'home/home_tab.dart';
import 'chats/chats_tab.dart';
import 'coins/coins_tab.dart';
import 'match/match_screen.dart';
import 'profile/profile_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WelcomeNameDialog.showIfNeeded(context);
        // If user is a paid customer and 24h passed, prompt store review
        ReviewService().checkAndPromptReviewIfEligible(delaySeconds: 4);
      }
    });

    // Mark user as active in current session
    StorageService().updateLastActiveTimestamp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      StorageService().updateLastActiveTimestamp();
    } else if (state == AppLifecycleState.resumed) {
      // Check 24h rating eligibility on app resume for paid users
      ReviewService().checkAndPromptReviewIfEligible(delaySeconds: 2);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    const tabNames = ['HomeTab', 'MatchTab', 'CreateTab', 'ChatsTab', 'ProfileTab'];
    if (index >= 0 && index < tabNames.length) {
      AnalyticsService().logScreenView(tabNames[index]);
    }
    // Check 24h rating prompt eligibility across tabs for paid users
    ReviewService().checkAndPromptReviewIfEligible(delaySeconds: 2);
  }

  @override
  Widget build(BuildContext context) {
    void openDiamondStore() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => const CoinsTab()),
      );
    }

    final List<Widget> tabs = [
      HomeTab(onNavigateToCoins: openDiamondStore),
      MatchScreen(onNavigateToCoins: openDiamondStore),
      const CreateCharacterScreen(isTab: true),
      ChatsTab(onExplorePressed: () => _onTabTapped(0)),
      ProfileTab(onNavigateToCoins: openDiamondStore),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: _buildSexyBottomBar(),
    );
  }

  Widget _buildSexyBottomBar() {
    final isCreateSelected = _currentIndex == 2;
    const double barHeight = 74.0;
    const double baseTop = 14.0;
    const double bumpHeight = 16.0;
    const double bumpRadius = 48.0;

    return Container(
      color: const Color(0xF210121F),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Ambient Glow Behind the Center Bump
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 76,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2D78).withOpacity(isCreateSelected ? 0.35 : 0.22),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Sculpted Frosted Glass Dock with Smooth Bump Arch
              Positioned.fill(
                child: ClipPath(
                  clipper: BumpBarClipper(
                    bumpRadius: bumpRadius,
                    bumpHeight: bumpHeight,
                    baseTop: baseTop,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: const Color(0xF210121F),
                    ),
                  ),
                ),
              ),

              // 3. Top Glass Contour Border & Neon Crest Highlight
              Positioned.fill(
                child: CustomPaint(
                  painter: BumpBarBorderPainter(
                    bumpRadius: bumpRadius,
                    bumpHeight: bumpHeight,
                    baseTop: baseTop,
                    isSelected: isCreateSelected,
                  ),
                ),
              ),

              // 4. Navigation Items Row
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: baseTop - 2),
                        child: _buildStandardNavItem(
                          index: 0,
                          label: "Home",
                          inactiveIcon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: baseTop - 2),
                        child: _buildStandardNavItem(
                          index: 1,
                          label: "Match",
                          inactiveIcon: Icons.favorite_outline_rounded,
                          activeIcon: Icons.favorite_rounded,
                        ),
                      ),
                    ),
                    // Center Elevated Glowing "Create" Button Nestled in the Bump
                    _buildCenterCreateButton(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: baseTop - 2),
                        child: _buildStandardNavItem(
                          index: 3,
                          label: "Chats",
                          inactiveIcon: Icons.chat_bubble_outline_rounded,
                          activeIcon: Icons.chat_bubble_rounded,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: baseTop - 2),
                        child: _buildStandardNavItem(
                          index: 4,
                          label: "Profile",
                          inactiveIcon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCreateButton() {
    final isSelected = _currentIndex == 2;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onTabTapped(2);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8A3FFC),
                    Color(0xFFFF2D78),
                    Color(0xFFFF66A1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                  width: isSelected ? 2.2 : 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D78).withOpacity(isSelected ? 0.7 : 0.45),
                    blurRadius: isSelected ? 18 : 12,
                    spreadRadius: isSelected ? 2 : 1,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: const Color(0xFF8A3FFC).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Create",
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? const Color(0xFFFF66A1) : Colors.white.withOpacity(0.7),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardNavItem({
    required int index,
    required String label,
    required IconData inactiveIcon,
    required IconData activeIcon,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _onTabTapped(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: isSelected
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppColors.primaryLight : const Color(0xFF757B9A),
              size: 23,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF757B9A),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 12 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    )
                  : null,
              borderRadius: BorderRadius.circular(2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.8),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class BumpBarClipper extends CustomClipper<Path> {
  final double bumpRadius;
  final double bumpHeight;
  final double baseTop;

  BumpBarClipper({
    this.bumpRadius = 48.0,
    this.bumpHeight = 16.0,
    this.baseTop = 14.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    const cornerRadius = 20.0;

    // Start bottom-left
    path.moveTo(0, h);
    // Left edge up to top-left corner
    path.lineTo(0, baseTop + cornerRadius);
    path.quadraticBezierTo(0, baseTop, cornerRadius, baseTop);

    // Flat line to start of bump
    final bumpStart = cx - bumpRadius;
    path.lineTo(bumpStart, baseTop);

    // Smooth cubic bezier arch (the bump)
    path.cubicTo(
      cx - bumpRadius * 0.52, baseTop,
      cx - bumpRadius * 0.48, baseTop - bumpHeight,
      cx, baseTop - bumpHeight,
    );
    path.cubicTo(
      cx + bumpRadius * 0.48, baseTop - bumpHeight,
      cx + bumpRadius * 0.52, baseTop,
      cx + bumpRadius, baseTop,
    );

    // Flat line to top-right corner
    path.lineTo(w - cornerRadius, baseTop);
    path.quadraticBezierTo(w, baseTop, w, baseTop + cornerRadius);

    // Down right edge to bottom-right
    path.lineTo(w, h);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant BumpBarClipper oldClipper) =>
      oldClipper.bumpRadius != bumpRadius ||
      oldClipper.bumpHeight != bumpHeight ||
      oldClipper.baseTop != baseTop;
}

class BumpBarBorderPainter extends CustomPainter {
  final double bumpRadius;
  final double bumpHeight;
  final double baseTop;
  final bool isSelected;

  BumpBarBorderPainter({
    this.bumpRadius = 48.0,
    this.bumpHeight = 16.0,
    this.baseTop = 14.0,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    const cornerRadius = 20.0;

    final borderPath = Path();
    borderPath.moveTo(0, baseTop + cornerRadius);
    borderPath.quadraticBezierTo(0, baseTop, cornerRadius, baseTop);

    final bumpStart = cx - bumpRadius;
    borderPath.lineTo(bumpStart, baseTop);

    borderPath.cubicTo(
      cx - bumpRadius * 0.52, baseTop,
      cx - bumpRadius * 0.48, baseTop - bumpHeight,
      cx, baseTop - bumpHeight,
    );
    borderPath.cubicTo(
      cx + bumpRadius * 0.48, baseTop - bumpHeight,
      cx + bumpRadius * 0.52, baseTop,
      cx + bumpRadius, baseTop,
    );

    borderPath.lineTo(w - cornerRadius, baseTop);
    borderPath.quadraticBezierTo(w, baseTop, w, baseTop + cornerRadius);

    // Base subtle border
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(borderPath, basePaint);

    // Glowing neon highlight on the bump crest
    final crestPath = Path();
    crestPath.moveTo(bumpStart + 6, baseTop);
    crestPath.cubicTo(
      cx - bumpRadius * 0.52, baseTop,
      cx - bumpRadius * 0.48, baseTop - bumpHeight,
      cx, baseTop - bumpHeight,
    );
    crestPath.cubicTo(
      cx + bumpRadius * 0.48, baseTop - bumpHeight,
      cx + bumpRadius * 0.52, baseTop,
      cx + bumpRadius - 6, baseTop,
    );

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFFF2D78).withOpacity(isSelected ? 0.95 : 0.65),
          const Color(0xFFFF66A1).withOpacity(isSelected ? 1.0 : 0.85),
          const Color(0xFF8A3FFC).withOpacity(isSelected ? 0.95 : 0.65),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(
        cx - bumpRadius,
        baseTop - bumpHeight - 2,
        bumpRadius * 2,
        bumpHeight + 4,
      ))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.2 : 1.6;
    canvas.drawPath(crestPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant BumpBarBorderPainter oldDelegate) =>
      oldDelegate.isSelected != isSelected;
}
