import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../models/mood.dart';
import '../main_navigation_screen.dart';
import '../../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onFinish;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 3000),
    this.onFinish,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // 1. Entrance reveal controller
  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // 2. Rhythmic organic heartbeat controller
  late final AnimationController _heartbeatController;

  // 3. Radiant expanding shockwave ripples
  late final AnimationController _rippleController;

  // 4. Shimmering light sweep on brand logo
  late final AnimationController _shimmerController;

  // 5. Star sparkle glint & oscillation
  late final AnimationController _starController;

  // 6. Laser loading progress line (0% to 100%)
  late final AnimationController _progressController;

  Timer? _navigationTimer;
  bool _hasPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrecached) {
      _hasPrecached = true;
      _precacheWarmupImages();
    }
  }

  void _precacheWarmupImages() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final characters = Character.allCharacters;
      final popularMoodTypes = [
        MoodType.romantic,
        MoodType.happy,
        MoodType.flirty,
        MoodType.caring,
        MoodType.shy,
        MoodType.playful,
      ];

      final seenPaths = <String>{};
      for (final mood in popularMoodTypes) {
        final matching = characters.where((c) => c.supportedMoods.contains(mood)).take(4);
        for (final c in matching) {
          final url = c.serverCoverUrl;
          if (!seenPaths.contains(url)) {
            seenPaths.add(url);
            precacheImage(NetworkImage(url), context);
          }
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();

    // Entrance
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Heartbeat
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    // Ripples
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Shimmer
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Star sparkle rotation
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Progress line
    final effectiveDuration = widget.duration > Duration.zero
        ? widget.duration
        : const Duration(milliseconds: 100);

    _progressController = AnimationController(
      vsync: this,
      duration: effectiveDuration,
    )..forward();

    _entranceController.forward();

    if (widget.duration > Duration.zero) {
      _navigationTimer = Timer(widget.duration, _navigateToNext);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToNext();
      });
    }
  }

  double _getHeartbeatIntensity() {
    final t = _heartbeatController.value;
    if (t < 0.15) {
      return sin((t / 0.15) * pi);
    } else if (t >= 0.25 && t < 0.45) {
      return sin(((t - 0.25) / 0.20) * pi) * 0.65;
    }
    return 0.0;
  }

  void _navigateToNext() {
    if (!mounted) return;
    if (widget.onFinish != null) {
      widget.onFinish!();
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _heartbeatController.dispose();
    _rippleController.dispose();
    _shimmerController.dispose();
    _starController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Background Radial Glow with Dynamic Breathing
          AnimatedBuilder(
            animation: _heartbeatController,
            builder: (context, child) {
              final beat = _getHeartbeatIntensity();
              return Center(
                child: Container(
                  width: 360 + (beat * 80),
                  height: 360 + (beat * 80),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.22 + (beat * 0.12)),
                        AppColors.secondary.withOpacity(0.14 + (beat * 0.08)),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. Central Content
          SafeArea(
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Animated Emblem with Shockwave Ripples & Heartbeat
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Shockwave Ripple Ring 1
                            AnimatedBuilder(
                              animation: _rippleController,
                              builder: (context, child) {
                                final phase = _rippleController.value;
                                final scale = 1.0 + (phase * 0.95);
                                final opacity = ((1.0 - phase) * 0.5).clamp(0.0, 0.5);
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(34),
                                      border: Border.all(
                                        color: AppColors.primaryLight.withOpacity(opacity),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Shockwave Ripple Ring 2 (offset phase)
                            AnimatedBuilder(
                              animation: _rippleController,
                              builder: (context, child) {
                                final phase = (_rippleController.value + 0.5) % 1.0;
                                final scale = 1.0 + (phase * 0.95);
                                final opacity = ((1.0 - phase) * 0.4).clamp(0.0, 0.4);
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(34),
                                      border: Border.all(
                                        color: AppColors.secondaryLight.withOpacity(opacity),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Core Pulsing Emblem
                            AnimatedBuilder(
                              animation: _heartbeatController,
                              builder: (context, child) {
                                final beat = _getHeartbeatIntensity();
                                final scale = 1.0 + (beat * 0.08);
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF32133A),
                                          Color(0xFF180E2D),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(32),
                                      border: Border.all(
                                        color: AppColors.primaryLight.withOpacity(0.75 + (beat * 0.25)),
                                        width: 2.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.45 + (beat * 0.35)),
                                          blurRadius: 36 + (beat * 18),
                                          spreadRadius: 2 + (beat * 4),
                                          offset: const Offset(0, 4),
                                        ),
                                        BoxShadow(
                                          color: AppColors.secondary.withOpacity(0.35 + (beat * 0.20)),
                                          blurRadius: 44 + (beat * 14),
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Vibrant Beating Heart
                                        Icon(
                                          Icons.favorite_rounded,
                                          size: 54 + (beat * 5),
                                          color: AppColors.primaryLight,
                                        ),

                                        // Twinkling / Rotating Anime Star
                                        Positioned(
                                          top: 17,
                                          right: 17,
                                          child: AnimatedBuilder(
                                            animation: _starController,
                                            builder: (context, child) {
                                              final angle = (_starController.value - 0.5) * 0.4;
                                              final starScale = 0.95 + (_starController.value * 0.15);
                                              return Transform.rotate(
                                                angle: angle,
                                                child: Transform.scale(
                                                  scale: starScale,
                                                  child: const Icon(
                                                    Icons.auto_awesome_rounded,
                                                    size: 26,
                                                    color: AppColors.goldLight,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Brand Title & Tagline with Dynamic Shimmer
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Shimmering "LOVIA" Typography
                          AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              final shimmerVal = _shimmerController.value;
                              return ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: [
                                      (shimmerVal - 0.35).clamp(0.0, 1.0),
                                      shimmerVal,
                                      (shimmerVal + 0.35).clamp(0.0, 1.0),
                                    ],
                                    colors: const [
                                      Colors.white,
                                      Color(0xFFFFB3D1),
                                      Colors.white,
                                    ],
                                  ).createShader(bounds);
                                },
                                child: const Text(
                                  "LOVIA",
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 8.5,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: AppColors.primary,
                                        blurRadius: 28,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // Tagline Capsule
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.glassBorder,
                                width: 1.2,
                              ),
                            ),
                            child: const Text(
                              "WHERE ANIME COMPANIONS COME ALIVE",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Footer: Dynamic Laser Progress Line & Neural Status Message
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          final progress = _progressController.value;
                          final statusText = progress < 0.40
                              ? "INITIALIZING NEURAL COMPANIONS"
                              : progress < 0.80
                                  ? "TUNING EMOTIONAL VOICES..."
                                  : "COMPANIONS READY ✨";

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Laser Progress Track
                              Container(
                                width: 190,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Stack(
                                  children: [
                                    // Animated Laser Fill
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress.clamp(0.02, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppColors.secondary,
                                              AppColors.primary,
                                              AppColors.accent,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryLight.withOpacity(0.8),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Dynamic Status Text
                              Text(
                                statusText,
                                style: const TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.0,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
