import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/character.dart';
import '../../models/mood.dart';
import '../../models/scenario.dart';
import '../../providers/chat_provider.dart';
import '../../providers/coin_provider.dart';
import '../../providers/mood_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/character_avatar.dart';
import '../../widgets/glass_container.dart';
import '../chat/character_profile_screen.dart';
import '../chat/chat_screen.dart';
import '../subscription/subscription_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToCoins;

  const HomeTab({super.key, required this.onNavigateToCoins});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (!_hasPrecached) {
      _hasPrecached = true;
      try {
        final moodProvider = Provider.of<MoodProvider>(context, listen: false);
        for (final c in moodProvider.charactersForSelectedMood.take(10)) {
          final url = c.customAvatarPath ?? c.serverCoverUrl;
          if (url.startsWith('http')) {
            precacheImage(NetworkImage(url), context);
          }
        }
        Future.microtask(() {
          if (!mounted) return;
          final all = Character.allCharacters;
          for (final c in all.take(24)) {
            final url = c.customAvatarPath ?? c.serverCoverUrl;
            if (url.startsWith('http')) {
              precacheImage(NetworkImage(url), context);
            }
          }
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCoverImage(
    String path, {
    Key? key,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.topCenter,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    String resolved = path;
    if (path.startsWith('assets/characters/')) {
      resolved = '${ApiService().baseUrl}/$path?v=20260930_clean';
    }
    return AppCachedImage(
      key: key,
      imagePath: resolved,
      fit: fit,
      alignment: alignment,
      errorBuilder: errorBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<MoodProvider, ChatProvider, CoinProvider>(
      builder: (context, moodProvider, chatProvider, coinProvider, child) {
        final selectedMood = moodProvider.selectedMood;
        final characters = moodProvider.charactersForSelectedMood;
        final recentChats = chatProvider.getAllConversations();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // 1. Top Search Bar, Diamond Counter, Daily Check-in & VIP Badge
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: [
                        // Search input pill
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: TextField(
                              controller: _searchController,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (val) => moodProvider.setSearchQuery(val),
                              decoration: const InputDecoration(
                                hintText: "Enter name or trait...",
                                hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Diamond / Coin Balance Badge (💎 37 style from screenshot)
                        GestureDetector(
                          onTap: widget.onNavigateToCoins,
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0x668A3FFC)),
                            ),
                            child: Row(
                              children: [
                                const Text("💎", style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(
                                  "${coinProvider.balance}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // VIP Crown Icon (Navigates directly to dedicated Subscription Screen)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (ctx) => const SubscriptionScreen()),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: coinProvider.isSubscribed
                                  ? const Color(0x33FFB800)
                                  : AppColors.surfaceLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: coinProvider.isSubscribed
                                    ? AppColors.gold
                                    : AppColors.primary.withOpacity(0.5),
                              ),
                            ),
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              size: 20,
                              color: coinProvider.isSubscribed ? AppColors.gold : AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // If user has custom characters, show "My Custom AI" carousel
                if (moodProvider.customCharacters.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "My Custom AI Characters",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${moodProvider.customCharacters.length} created",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: moodProvider.customCharacters.length,
                        separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) {
                          final c = moodProvider.customCharacters[i];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    character: c,
                                    scenario: Scenario.allScenarios.first,
                                    currentMood: c.primaryMood,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _buildCoverImage(
                                      c.coverImagePath,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 68,
                                  child: Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // 3. Modern "Vibe & Emotion" Mood Selector Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "How are you feeling today?",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Tap a mood to meet matched companions",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                selectedMood.gradientColors.first.withOpacity(0.25),
                                selectedMood.gradientColors.last.withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedMood.gradientColors.first.withOpacity(0.55),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(selectedMood.emoji, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 5),
                              Text(
                                selectedMood.name,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: selectedMood.gradientColors.first,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Horizontal Mood Carousel (15 Moods with rich glassmorphism & dual-tone neon glow)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 104,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: Mood.allMoods.length,
                      itemBuilder: (context, index) {
                        final mood = Mood.allMoods[index];
                        final isSelected = mood.type == selectedMood.type;

                        return GestureDetector(
                          onTap: () => moodProvider.selectMood(mood),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 86,
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: mood.gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected ? null : const Color(0xFF161826),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: mood.gradientColors.first.withOpacity(0.55),
                                        blurRadius: 18,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.24)
                                        : Colors.white.withOpacity(0.06),
                                  ),
                                  child: Center(
                                    child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  mood.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.white70,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    width: 16,
                                    height: 3,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // 4. Anime Character 2-Column Grid (Exact layout from user's screenshot!)
                if (characters.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.person_search_rounded, size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            const Text(
                              "No characters found for this mood.",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.52, // Generous height preventing vertical card overflow
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final char = characters[index];
                          return _buildAnimeCharacterCard(context, char, selectedMood);
                        },
                        childCount: characters.length,
                        findChildIndexCallback: (Key key) {
                          if (key is ValueKey<String>) {
                            final raw = key.value.replaceFirst('anime_card_', '');
                            final idx = characters.indexWhere((c) => c.id == raw);
                            return idx >= 0 ? idx : null;
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                // 5. Recent Chat Banner
                if (recentChats.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: const Text(
                        "Continue Roleplay",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GlassContainer(
                        onTap: () {
                          final recent = recentChats.first;
                          chatProvider.openChat(character: recent.character);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => ChatScreen(
                                character: recent.character,
                                scenario: chatProvider.activeScenario,
                                currentMood: selectedMood.type,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AppCachedImage.characterCover(
                                character: recentChats.first.character,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recentChats.first.character.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    recentChats.first.lastMessage.content,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds vertical anime card matching the user's uploaded screenshot
  Widget _buildAnimeCharacterCard(BuildContext context, Character char, Mood mood) {
    return GestureDetector(
      key: ValueKey('anime_card_${char.id}'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CharacterProfileScreen(
              character: char,
              currentMood: mood,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-art Anime Illustration
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildCoverImage(
                      char.coverImagePath,
                      fit: BoxFit.cover,
                      alignment: (char.isCustom && char.customAvatarPath != null)
                          ? Alignment.topCenter
                          : const Alignment(0, -0.65),
                      errorBuilder: (ctx, err, stack) => Container(
                        color: AppColors.surfaceLight,
                        child: Center(
                          child: CharacterAvatar(
                            character: char,
                            size: AvatarSize.large,
                            showAuraGlow: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Subtle gradient at bottom of image
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, AppColors.surface.withOpacity(0.95)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card Text & Badges (Matching Talkie / user screenshot)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    char.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Chips / Tags (e.g. "Tomboy", "Romantic", "Voice Talk")
                  Row(
                    children: [
                      Flexible(child: _buildChip(char.tags.first)),
                      if (char.tags.length > 1) ...[
                        const SizedBox(width: 4),
                        Flexible(child: _buildChip(char.tags[1])),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Story Hook / Subtitle
                  Text(
                    char.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
