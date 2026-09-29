import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../providers/user_provider.dart';
import '../providers/mood_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class ModerationDialogs {
  /// Presents an Apple-compliant report sheet with standard categorization
  static Future<void> showReportDialog(
    BuildContext context, {
    required Character character,
    ChatMessage? message,
  }) async {
    final reasons = [
      "Sexually explicit or inappropriate content",
      "Hate speech, harassment, or bullying",
      "Violence, self-harm, or dangerous activity",
      "Repetitive, nonsensical, or low quality output",
      "Other policy or safety violation",
    ];

    int selectedReasonIndex = 0;
    final detailsController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
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
                    const Icon(Icons.flag_rounded, color: AppColors.error, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Report Objectionable Content",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            message != null
                                ? "Reporting message from ${character.name}"
                                : "Reporting ${character.name}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Select the reason for this report:",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                ...List.generate(reasons.length, (index) {
                  final isSelected = selectedReasonIndex == index;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setModalState(() => selectedReasonIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.18) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.glassBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 18,
                            color: isSelected ? AppColors.primary : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reasons[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                TextField(
                  controller: detailsController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Additional details (optional)...",
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final user = Provider.of<UserProvider>(context, listen: false);
                          await user.reportContent(
                            characterId: character.id,
                            messageId: message?.id,
                            reason: reasons[selectedReasonIndex],
                            details: detailsController.text.trim(),
                          );
                          AnalyticsService().logModerationReport(
                            characterId: character.id,
                            reason: reasons[selectedReasonIndex],
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final messenger = rootScaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context);
                            messenger.hideCurrentSnackBar();
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF1E1724),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: Color(0x66FF2A6D), width: 1),
                                ),
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 22),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Thank you. Content has been reported and submitted for safety review.",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          "Submit Report",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  /// Presents a block confirmation dialog to remove a character
  static Future<void> showBlockDialog(
    BuildContext context, {
    required Character character,
    VoidCallback? onBlocked,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Block ${character.name}?",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to block ${character.name}? They will be hidden from your recommendations, explore feed, and search results.",
          style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              final moodProvider = Provider.of<MoodProvider>(context, listen: false);

              await userProvider.blockCharacter(character.id);
              moodProvider.updateBlockedCharacters(userProvider.blockedCharacterIds);
              AnalyticsService().logCharacterBlocked(characterId: character.id);

              if (context.mounted) {
                Navigator.pop(ctx);
                onBlocked?.call();

                final messenger = rootScaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E1724),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0x66FF2A6D), width: 1),
                    ),
                    content: Row(
                      children: [
                        const Icon(Icons.block_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Blocked ${character.name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    action: SnackBarAction(
                      label: "Undo",
                      textColor: AppColors.accent,
                      onPressed: () async {
                        await userProvider.unblockCharacter(character.id);
                        moodProvider.updateBlockedCharacters(userProvider.blockedCharacterIds);
                      },
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Block", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Displays AI Safety & Fictional Persona Disclaimer
  static void showAiDisclaimerDialog(BuildContext context) {
    final isApple = Theme.of(context).platform == TargetPlatform.iOS;
    final storePolicy = isApple ? "Apple App Store safety policies" : "Google Play safety policies";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "AI Safety & Disclaimer",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "• Fictional AI Personas:\nAll characters, dialogues, avatars, and audio in Lovia are generated by artificial intelligence. They are purely fictional and intended solely for creative storytelling and entertainment.",
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                "• Zero Tolerance for Abuse:\nLovia strictly adheres to $storePolicy. Generating hate speech, explicit illegal sexual content, self-harm, harassment, or non-consensual material is strictly prohibited.",
                style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              const Text(
                "• User Control & Support:\nYou can flag any message using the report button or block any character at any time. For safety inquiries or concerns, contact: support@genxappstudio.cloud",
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Understood", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
