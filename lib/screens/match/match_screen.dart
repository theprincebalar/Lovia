import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../providers/chat_provider.dart';
import '../../providers/mood_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/coin_badge.dart';
import '../chat/character_profile_screen.dart';
import '../chat/chat_screen.dart';
import '../voice/voice_talk_screen.dart';

enum MatchPreference {
  female,
  male,
  any,
}

class MatchScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCoins;

  const MatchScreen({
    super.key,
    this.onNavigateToCoins,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with TickerProviderStateMixin {
  MatchPreference _preference = MatchPreference.any;
  Character? _currentMatch;
  bool _isMatching = false;
  int _chemistryScore = 98;
  final Set<String> _seenMatchIds = <String>{};

  late AnimationController _radarController;
  late AnimationController _heartPulseController;
  late AnimationController _revealController;

  Timer? _statusTimer;
  Timer? _sequenceTimer;
  int _statusTextIndex = 0;
  final List<String> _statusTexts = [
    "Tuning emotional frequencies...",
    "Scanning compatibility heartwaves...",
    "Finding your ideal companion...",
    "A spark has been found! 💕",
  ];

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Auto-match on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMatchingSequence();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _heartPulseController.dispose();
    _revealController.dispose();
    _statusTimer?.cancel();
    _sequenceTimer?.cancel();
    super.dispose();
  }

  void _onPreferenceChanged(MatchPreference newPref) {
    if (_preference == newPref && !_isMatching) return;
    HapticFeedback.selectionClick();
    setState(() {
      _preference = newPref;
      _seenMatchIds.clear(); // Reset cycle for newly selected gender preference
    });
    _startMatchingSequence();
  }

  void _startMatchingSequence() {
    if (_isMatching) return;

    setState(() {
      _isMatching = true;
      _statusTextIndex = 0;
    });

    _revealController.reset();

    // Cycle through playful status texts
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _statusTextIndex = (_statusTextIndex + 1) % _statusTexts.length;
      });
    });

    // 1.4 seconds of lovey-dovey animation, then pick and reveal
    _sequenceTimer?.cancel();
    _sequenceTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      _statusTimer?.cancel();

      final moodProvider = Provider.of<MoodProvider>(context, listen: false);
      final character = _pickRandomCharacter(moodProvider);

      setState(() {
        _currentMatch = character;
        _chemistryScore = 92 + math.Random().nextInt(8); // 92% - 99%
        _isMatching = false;
      });

      _revealController.forward();
      HapticFeedback.heavyImpact();
    });
  }

  Character? _pickRandomCharacter(MoodProvider moodProvider) {
    // Collect all available characters from provider
    final all = moodProvider.charactersForSelectedMood.isNotEmpty
        ? moodProvider.charactersForSelectedMood
        : Character.allCharacters;

    List<Character> eligible = all.where((c) {
      if (_preference == MatchPreference.female) return c.gender == Gender.female;
      if (_preference == MatchPreference.male) return c.gender == Gender.male;
      return true;
    }).toList();

    if (eligible.isEmpty) {
      eligible = Character.allCharacters.where((c) {
        if (_preference == MatchPreference.female) return c.gender == Gender.female;
        if (_preference == MatchPreference.male) return c.gender == Gender.male;
        return true;
      }).toList();
    }

    if (eligible.isEmpty) eligible = Character.allCharacters;

    // Filter out profiles already shown in this cycle
    List<Character> unvisited = eligible.where((c) => !_seenMatchIds.contains(c.id)).toList();

    // If all profiles completed, restart cycle again!
    if (unvisited.isEmpty) {
      _seenMatchIds.clear();
      // Avoid immediate repeat of the previous match if more than 1 character exists
      if (eligible.length > 1 && _currentMatch != null) {
        unvisited = eligible.where((c) => c.id != _currentMatch!.id).toList();
      } else {
        unvisited = List.from(eligible);
      }
    }

    unvisited.shuffle();
    final picked = unvisited.first;
    _seenMatchIds.add(picked.id);
    return picked;
  }

  void _startChatWithMatch(Character character) {
    HapticFeedback.mediumImpact();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.openChat(character: character);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ChatScreen(
          character: character,
          scenario: chatProvider.activeScenario,
          currentMood: character.primaryMood,
        ),
      ),
    );
  }

  void _startVoiceWithMatch(Character character) {
    HapticFeedback.mediumImpact();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.openChat(character: character);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => VoiceTalkScreen(
          character: character,
          scenario: chatProvider.activeScenario,
          currentMood: character.primaryMood,
        ),
      ),
    );
  }

  void _openCharacterProfile(Character character) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => CharacterProfileScreen(character: character),
      ),
    );
  }

  Widget _buildSafeImage(String path, {BoxFit fit = BoxFit.cover, Alignment alignment = const Alignment(0, -0.65)}) {
    String resolved = path;
    if (path.startsWith('assets/characters/')) {
      resolved = '${ApiService().baseUrl}/$path';
    }
    return AppCachedImage(
      imagePath: resolved,
      fit: fit,
      alignment: alignment,
      errorBuilder: (ctx, err, stack) => Container(
        color: const Color(0xFF1E162B),
        child: const Center(
          child: Icon(Icons.favorite_rounded, color: AppColors.primaryLight, size: 48),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A12),
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned(
            top: -120,
            left: -80,
            right: -80,
            height: 420,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.85,
                  colors: [
                    AppColors.primary.withOpacity(0.28),
                    const Color(0xFF8A3FFC).withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar with Title & Currency Counter
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Destiny Match",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Find your instant AI soulmate",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      CoinBadge(
                        onTap: widget.onNavigateToCoins,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Top Gender Preference Selector Chips
                _buildPreferenceSelector(),

                const SizedBox(height: 12),

                // Dynamic Body (Matching Animation vs Matched Character Reveal)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _isMatching || _currentMatch == null
                        ? _buildMatchingRadar()
                        : _buildMatchRevealCard(_currentMatch!),
                  ),
                ),

                // Bottom Shuffle Button Bar
                _buildBottomShuffleBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPreferenceChip(
              pref: MatchPreference.female,
              label: "Female",
              icon: Icons.female_rounded,
              color: const Color(0xFFFF4081),
            ),
          ),
          Expanded(
            child: _buildPreferenceChip(
              pref: MatchPreference.male,
              label: "Male",
              icon: Icons.male_rounded,
              color: const Color(0xFF00B0FF),
            ),
          ),
          Expanded(
            child: _buildPreferenceChip(
              pref: MatchPreference.any,
              label: "Any",
              icon: Icons.auto_awesome_rounded,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceChip({
    required MatchPreference pref,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _preference == pref;

    return GestureDetector(
      onTap: () => _onPreferenceChanged(pref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: color.withOpacity(0.8), width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchingRadar() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Concentric Pulsing Heart Radar Animation
          SizedBox(
            width: 240,
            height: 240,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ripple 1
                    _buildRadarRing(_radarController.value, 220),
                    // Outer ripple 2
                    _buildRadarRing((_radarController.value + 0.33) % 1.0, 220),
                    // Outer ripple 3
                    _buildRadarRing((_radarController.value + 0.66) % 1.0, 220),

                    // Central Pulsing Heart Emblem
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.12).animate(
                        CurvedAnimation(parent: _heartPulseController, curve: Curves.easeInOut),
                      ),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2E93), Color(0xFFFF5252), Color(0xFF8A3FFC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2E93).withOpacity(0.6),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Dynamic Romantic Matching Subtitle
          Text(
            _statusTexts[_statusTextIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Looking through ${_preference == MatchPreference.any ? '150 companions' : (_preference == MatchPreference.female ? 'female companions' : 'male companions')}...",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarRing(double progress, double maxDimension) {
    final size = 90.0 + progress * (maxDimension - 90.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFF2E93).withOpacity(opacity * 0.5),
          width: 2.0,
        ),
      ),
    );
  }

  Widget _buildMatchRevealCard(Character character) {
    final coverPath = character.coverImagePath;
    final screenHeight = MediaQuery.of(context).size.height;
    final double portraitHeight = (screenHeight * 0.40).clamp(240.0, 380.0);

    return FadeTransition(
      opacity: _revealController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _revealController, curve: Curves.easeOutBack),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Main Character Card Container (Tap anywhere on card to view profile)
              GestureDetector(
                onTap: () => _openCharacterProfile(character),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E142B), Color(0xFF130E1F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(
                    color: AppColors.primaryLight.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Character Cover Portrait with Chemistry Badge
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                          child: SizedBox(
                            height: portraitHeight,
                            width: double.infinity,
                            child: _buildSafeImage(
                              coverPath,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.7),
                            ),
                          ),
                        ),

                        // Gradient fade at bottom of image
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, const Color(0xFF1E142B).withOpacity(0.9)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // Chemistry Match Pill (Top-Left)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF2E93), Color(0xFFFF5252)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  "$_chemistryScore% CHEMISTRY",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Quick Info Button (Top-Right)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: GestureDetector(
                            onTap: () => _openCharacterProfile(character),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.55),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Character Details & Quote
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name, Age & Gender Badge
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  character.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      character.gender == Gender.female
                                          ? Icons.female_rounded
                                          : Icons.male_rounded,
                                      size: 14,
                                      color: character.gender == Gender.female
                                          ? const Color(0xFFFF4081)
                                          : const Color(0xFF00B0FF),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      "${character.age}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                ),
                                child: Text(
                                  character.primaryMood.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Occupation & Tagline
                          Text(
                            "${character.occupation} • \"${character.tagline}\"",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Character Bio & Story Hook
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    character.bio,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.92),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Action Buttons: Chat Now & Voice Call
                          Row(
                            children: [
                              // Chat Now CTA
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startChatWithMatch(character),
                                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                                    label: const Text(
                                      "Start Chat",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 6,
                                      shadowColor: AppColors.primary.withOpacity(0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Voice Call CTA
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startVoiceWithMatch(character),
                                    icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: Color(0xFF00E5FF)),
                                    label: const Text(
                                      "Call",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.08),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomShuffleBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F101A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.0),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isMatching ? null : _startMatchingSequence,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF221935),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                "Shuffle New Match 🎲",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
