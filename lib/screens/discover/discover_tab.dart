import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/character.dart';
import '../../models/scenario.dart';
import '../../providers/mood_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/character_avatar.dart';
import '../chat/character_profile_screen.dart';
import '../create/create_character_screen.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MoodProvider>(
      builder: (context, moodProvider, child) {
        final characters = moodProvider.filteredCharacters;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Discover",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Find or design your ideal companion.",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateCharacterScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text(
                                "Create AI",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: TextField(
                    controller: _searchController,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (val) => moodProvider.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: "Search by character name, traits, or style...",
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                moodProvider.setSearchQuery("");
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filters Row: Gender Pills
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      _buildGenderPill("All", GenderFilter.all, moodProvider),
                      const SizedBox(width: 8),
                      _buildGenderPill("Female", GenderFilter.female, moodProvider),
                      const SizedBox(width: 8),
                      _buildGenderPill("Male", GenderFilter.male, moodProvider),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Scenarios Filter Carousel
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: Scenario.allScenarios.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isAll = moodProvider.scenarioFilter == null;
                        return GestureDetector(
                          onTap: () => moodProvider.setScenarioFilter(null),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isAll ? AppColors.secondary : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              "All Scenarios",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                                color: isAll ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }

                      final sc = Scenario.allScenarios[index - 1];
                      final isSelected = moodProvider.scenarioFilter == sc.type;

                      return GestureDetector(
                        onTap: () => moodProvider.setScenarioFilter(
                          isSelected ? null : sc.type,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.secondary : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? AppColors.secondaryLight : AppColors.glassBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(sc.icon, size: 14, color: isSelected ? Colors.white : AppColors.textTertiary),
                              const SizedBox(width: 6),
                              Text(
                                sc.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Character Cards Grid
                Expanded(
                  child: characters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              const Text(
                                "No characters match your search.",
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.52,
                          ),
                          itemCount: characters.length,
                          itemBuilder: (context, index) {
                            final char = characters[index];
                            return _buildGridCard(context, char);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenderPill(String title, GenderFilter filter, MoodProvider moodProvider) {
    final isSelected = moodProvider.genderFilter == filter;
    return GestureDetector(
      onTap: () => moodProvider.setGenderFilter(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, Character char) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CharacterProfileScreen(character: char),
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
                    child: AppCachedImage.characterCover(
                      character: char,
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
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
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(child: _buildChip(char.tags.first)),
                      if (char.tags.length > 1) ...[
                        const SizedBox(width: 4),
                        Flexible(child: _buildChip(char.tags[1])),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
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
