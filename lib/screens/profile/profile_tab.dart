import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/character.dart';
import '../../providers/chat_provider.dart';
import '../../providers/coin_provider.dart';
import '../../providers/mood_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/character_avatar.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/moderation_dialogs.dart';
import '../chat/character_profile_screen.dart';
import '../chat/chat_screen.dart';
import '../subscription/subscription_screen.dart';
import '../webview/web_view_screen.dart';
import '../../services/storage_service.dart';

class ProfileTab extends StatelessWidget {
  final VoidCallback onNavigateToCoins;

  const ProfileTab({super.key, required this.onNavigateToCoins});

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserProvider, CoinProvider, MoodProvider>(
      builder: (context, userProvider, coinProvider, moodProvider, child) {
        final favorites = userProvider.favoriteCharacters;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: const Text(
              "My Profile",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. User Profile Card
                GlassContainer(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _showEditNameDialog(context, userProvider),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      userProvider.userName.isNotEmpty ? userProvider.userName : "Set Your Name",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.edit_rounded, size: 15, color: AppColors.primaryLight),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Lovia Premium Explorer",
                              style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.diamond_rounded, size: 14, color: AppColors.diamond),
                                const SizedBox(width: 4),
                                Text(
                                  "${coinProvider.balance} Diamonds",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.diamondLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: onNavigateToCoins,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text("Top Up", style: TextStyle(fontSize: 12, color: AppColors.goldLight)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // VIP Membership Card
                GestureDetector(
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
                        colors: [Color(0xFF2D1838), Color(0xFF1B1124)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: coinProvider.isSubscribed
                            ? AppColors.gold.withOpacity(0.8)
                            : AppColors.accent.withOpacity(0.6),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (coinProvider.isSubscribed ? AppColors.gold : AppColors.accent)
                              .withOpacity(0.18),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: coinProvider.isSubscribed
                                ? AppColors.goldGradient
                                : AppColors.primaryGradient,
                          ),
                          child: Icon(
                            coinProvider.isSubscribed
                                ? Icons.workspace_premium_rounded
                                : Icons.stars_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      coinProvider.isSubscribed
                                          ? "VIP: ${coinProvider.activeSubscription?.title ?? 'Active'}"
                                          : "Lovia VIP Club",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (coinProvider.isSubscribed) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF20BF6B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        "ACTIVE",
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                coinProvider.isSubscribed
                                    ? "Unlimited Chat • ${coinProvider.voiceMinutesRemaining} Voice Mins"
                                    : "Unlimited Chat, Voice Talk & Priority AI",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.goldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Quick Bar
                GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfileStat(
                        icon: Icons.diamond_rounded,
                        iconColor: AppColors.diamond,
                        value: "${coinProvider.balance}",
                        label: "Diamonds",
                      ),
                      Container(width: 1, height: 32, color: AppColors.glassBorder),
                      _buildProfileStat(
                        icon: Icons.card_giftcard_rounded,
                        iconColor: const Color(0xFFFF5E7E),
                        value: "${userProvider.giftsSentCount}",
                        label: "Gifts Sent",
                      ),
                      Container(width: 1, height: 32, color: AppColors.glassBorder),
                      _buildProfileStat(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: AppColors.primaryLight,
                        value: "${moodProvider.customCharacters.length}",
                        label: "Creations",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Favorite Characters Carousel
                const Text(
                  "Favorite Characters",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (favorites.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Center(
                      child: Text(
                        "Tap the heart icon on any character profile to add them to your favorites.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final char = favorites[index];
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
                            width: 90,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                CharacterAvatar(
                                  character: char,
                                  size: AvatarSize.medium,
                                  showAuraGlow: true,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  char.name.split(' ')[0],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),

                // 3. My Creations Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "My Creations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (moodProvider.customCharacters.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                        ),
                        child: Text(
                          "${moodProvider.customCharacters.length} Created",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (moodProvider.customCharacters.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 22),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "No Custom Characters Yet",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Design your own roleplay partner with custom lore, prompts, voices, and photos in the Create tab.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: moodProvider.customCharacters.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final char = moodProvider.customCharacters[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppCachedImage.characterCover(
                                  character: char,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          char.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          char.primaryMood.name.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryLight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    char.tagline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Chat Action Button
                            IconButton(
                              onPressed: () {
                                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                                chatProvider.openChat(character: char);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => ChatScreen(
                                      character: char,
                                      scenario: chatProvider.activeScenario,
                                      currentMood: char.primaryMood,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryLight, size: 20),
                              tooltip: "Chat with ${char.name}",
                            ),
                            // Delete Action Button
                            IconButton(
                              onPressed: () => _confirmDeleteCustomCharacter(context, moodProvider, char),
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              tooltip: "Delete ${char.name}",
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // 4. Preferences (Voice Autoplay removed as requested)
                const Text(
                  "Preferences",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      value: userProvider.proactiveNotificationsEnabled,
                      activeColor: AppColors.primary,
                      title: const Text("Proactive Companion Check-ins", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text("Receive spontaneous thoughts, affection, and greetings from characters", style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      onChanged: (val) => userProvider.setProactiveNotificationsEnabled(val),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Legal & Policies
                const Text(
                  "Legal & About",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.badge_rounded, size: 20, color: AppColors.primaryLight),
                          title: const Text("Your Roleplay Name", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text("Characters will address you by this name in chat and calls", style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                userProvider.userName,
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_rounded, size: 14, color: AppColors.primaryLight),
                            ],
                          ),
                          onTap: () => _showEditNameDialog(context, userProvider),
                        ),
                        const Divider(color: AppColors.glassBorder, height: 1),
                        ListTile(
                          leading: const Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.accent),
                          title: const Text("AI Safety & Zero Tolerance EULA", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            Theme.of(context).platform == TargetPlatform.iOS
                                ? "Apple Review Guideline 1.2 & 5.6.4 compliant"
                                : "Google Play Developer Policy compliant",
                            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                          onTap: () => ModerationDialogs.showAiDisclaimerDialog(context),
                        ),
                        const Divider(color: AppColors.glassBorder, height: 1),
                        ListTile(
                          leading: const Icon(Icons.block_rounded, size: 20, color: AppColors.error),
                          title: const Text("Blocked Characters", style: TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${userProvider.blockedCharacterIds.length}",
                                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                            ],
                          ),
                          onTap: () => _showBlockedCharactersSheet(context, userProvider),
                        ),
                        const Divider(color: AppColors.glassBorder, height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, size: 20, color: AppColors.textSecondary),
                          title: const Text("Privacy Policy", style: TextStyle(fontSize: 14)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                          onTap: () {
                            final storage = StorageService();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => WebViewScreen(
                                  url: storage.getPrivacyPolicyUrl(),
                                  title: "Privacy Policy",
                                  fallbackHtml: """
                                    <h1>Lovia Privacy Policy</h1>
                                    <p>Lovia values and protects your privacy.</p>
                                    <p><strong>1. Data Collection:</strong> We do not sell your personal data. Chat histories, voice parameters, and relationship progression are stored securely on your local device.</p>
                                    <p><strong>2. AI Processing:</strong> Dialogue is processed in real time via secure API endpoints exclusively to generate contextual roleplay text and audio responses.</p>
                                    <p><strong>3. Account & Data Deletion:</strong> You can completely delete all stored chat records, affection XP, and settings at any time using the 'Delete Account & Reset Data' button.</p>
                                  """,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(color: AppColors.glassBorder, height: 1),
                        ListTile(
                          leading: const Icon(Icons.description_outlined, size: 20, color: AppColors.textSecondary),
                          title: const Text("Terms of Service (EULA)", style: TextStyle(fontSize: 14)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                          onTap: () {
                            final storage = StorageService();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => WebViewScreen(
                                  url: storage.getTermsConditionsUrl(),
                                  title: "Terms of Service & EULA",
                                  fallbackHtml: """
                                    <h1>End User License Agreement (EULA)</h1>
                                    <p>By using Lovia, you agree to the following terms:</p>
                                    <p><strong>1. Fictional Entertainment:</strong> Lovia is an interactive visual novel roleplay application. All characters, voices, and responses are fictional creations produced by artificial intelligence.</p>
                                    <p><strong>2. Zero Tolerance for Objectionable Content:</strong> Users must not attempt to generate or encourage hate speech, violent threats, sexually explicit or non-consensual content, harassment, or self-harm.</p>
                                    <p><strong>3. User Controls:</strong> Users have the right and tools to report any objectionable output and block any character immediately.</p>
                                    <p><strong>4. Virtual Currency:</strong> Diamonds are virtual entertainment tokens used for in-app messaging and calls. Diamonds have no real-world monetary value.</p>
                                  """,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Danger Zone: Delete Account / Reset Data
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                      title: const Text(
                        "Delete Account & Reset Data",
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        "Clears all chats, affection XP, and resets diamonds",
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                      onTap: () => _confirmReset(context, userProvider),
                    ),
                  ),
                ),
                const SizedBox(height: 108),
              ],
            ),
          ),
        );
      },
    );
  }


  void _confirmReset(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset All Data?", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: const Text(
          "Are you sure you want to delete your account? All active chats, relationship levels, and diamond history will be reset to default.",
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              await userProvider.deleteAccountAndReset();
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Account and data have been reset.")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Reset All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomCharacter(BuildContext context, MoodProvider moodProvider, Character character) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete ${character.name}?",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
        ),
        content: Text(
          "Are you sure you want to permanently delete \"${character.name}\"? This custom AI character and their roleplay data will be deleted.",
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await moodProvider.deleteCustomCharacter(character.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("✨ ${character.name} has been deleted."),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlockedCharactersSheet(BuildContext context, UserProvider userProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final blocked = userProvider.blockedCharacters;

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.block_rounded, color: AppColors.error, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Blocked Characters (${blocked.length})",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Blocked characters are hidden from your home feed, discovery, and search.",
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              if (blocked.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36.0),
                  child: Center(
                    child: Text(
                      "You have not blocked any characters.",
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: blocked.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.glassBorder, height: 1),
                    itemBuilder: (context, index) {
                      final char = blocked[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CharacterAvatar(
                          character: char,
                          size: AvatarSize.small,
                          showAuraGlow: false,
                        ),
                        title: Text(
                          char.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          char.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final moodProvider = Provider.of<MoodProvider>(context, listen: false);
                            await userProvider.unblockCharacter(char.id);
                            moodProvider.updateBlockedCharacters(userProvider.blockedCharacterIds);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Unblocked ${char.name}")),
                              );
                            }
                          },
                          child: const Text("Unblock", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, UserProvider userProvider) {
    final controller = TextEditingController(text: userProvider.userName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.badge_rounded, color: AppColors.primaryLight, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Your Roleplay Name",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Characters will address you intimately by this name in conversations, voice calls, and greetings.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: "Your Name / Nickname",
                  labelStyle: const TextStyle(color: AppColors.textTertiary),
                  hintText: "Enter your name...",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await userProvider.setUserName(newName);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text("Roleplay name updated to $newName! Characters will now call you $newName."),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileStat({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
