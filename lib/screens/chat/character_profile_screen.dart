import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/character.dart';
import '../../models/emotion_state.dart';
import '../../models/mood.dart';
import '../../models/scenario.dart';
import '../../models/relationship.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/coin_provider.dart';
import '../../services/storage_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/character_avatar.dart';
import '../../widgets/insufficient_coins_dialog.dart';
import '../../widgets/moderation_dialogs.dart';
import 'chat_screen.dart';
import '../voice/voice_talk_screen.dart';

class CharacterProfileScreen extends StatefulWidget {
  final Character character;
  final Mood? currentMood;

  const CharacterProfileScreen({
    super.key,
    required this.character,
    this.currentMood,
  });

  @override
  State<CharacterProfileScreen> createState() => _CharacterProfileScreenState();
}

class _CharacterProfileScreenState extends State<CharacterProfileScreen> {
  late Scenario _selectedScenario;
  final VoiceService _voiceService = VoiceService();
  final StorageService _storageService = StorageService();
  bool _isPlayingVoicePreview = false;

  @override
  void initState() {
    super.initState();
    final firstType = widget.character.supportedScenarios.first;
    _selectedScenario = Scenario.allScenarios.firstWhere((s) => s.type == firstType);
    _storageService.init();
  }

  @override
  void dispose() {
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _toggleVoicePreview() async {
    if (_isPlayingVoicePreview) {
      await _voiceService.stop();
      if (mounted) setState(() => _isPlayingVoicePreview = false);
      return;
    }

    setState(() => _isPlayingVoicePreview = true);

    final quote = widget.character.voicePreviewQuote.isNotEmpty
        ? widget.character.voicePreviewQuote
        : widget.character.initialGreeting;

    await _voiceService.speakAndWait(
      character: widget.character,
      emotion: EmotionState.happy,
      text: quote,
      storageService: _storageService,
    );

    if (mounted) {
      setState(() => _isPlayingVoicePreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);
    final isFav = userProvider.isFavorite(widget.character.id);

    // Get relationship with live synchronized affection from storage & provider
    final relationship = chatProvider.getRelationshipFor(widget.character.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero Character App Bar
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: _isPlayingVoicePreview ? "Stop Voice Sample" : "Play Voice Sample",
                icon: Icon(
                  _isPlayingVoicePreview ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                  color: _isPlayingVoicePreview ? AppColors.primary : AppColors.accent,
                ),
                onPressed: _toggleVoicePreview,
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? AppColors.primary : Colors.white70,
                ),
                onPressed: () => userProvider.toggleFavorite(widget.character.id),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                color: AppColors.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'safety') {
                    ModerationDialogs.showAiDisclaimerDialog(context);
                  } else if (val == 'report') {
                    ModerationDialogs.showReportDialog(context, character: widget.character);
                  } else if (val == 'block') {
                    ModerationDialogs.showBlockDialog(
                      context,
                      character: widget.character,
                      onBlocked: () => Navigator.pop(context),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'safety',
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
                        SizedBox(width: 10),
                        Text("AI Safety & Disclaimer", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_rounded, size: 18, color: AppColors.warning),
                        SizedBox(width: 10),
                        Text("Report Character", style: TextStyle(fontSize: 13, color: AppColors.warning)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded, size: 18, color: AppColors.error),
                        SizedBox(width: 10),
                        Text("Block Character", style: TextStyle(fontSize: 13, color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Full-bleed anime illustration
                  Positioned.fill(
                    child: AppCachedImage.characterCover(
                      character: widget.character,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.4),
                      errorBuilder: (ctx, err, stack) => Center(
                        child: CharacterAvatar(
                          character: widget.character,
                          emotion: EmotionState.happy,
                          size: AvatarSize.fullscreen,
                          showAuraGlow: true,
                        ),
                      ),
                    ),
                  ),

                  // Bottom dark fade
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.darkFadeGradient,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Character Profile Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Gender/Age badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.character.name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          "${widget.character.gender == Gender.female ? 'Female' : 'Male'}, ${widget.character.age}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Tagline
                  Text(
                    widget.character.tagline,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Apple Guideline 5.6.4 AI Persona Disclosure Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x1F8A3FFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x448A3FFC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.accent),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            "Fictional AI Persona • Entertainment Roleplay",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Relationship Level Card (Redesigned & Beautiful with Info Icon)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          relationship.level.color.withOpacity(0.18),
                          const Color(0xFF141624),
                          AppColors.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: relationship.level.color.withOpacity(0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: relationship.level.color.withOpacity(0.18),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: Icon & Status Label + XP Pill & Info Icon (i)
                        Row(
                          children: [
                            // Glowing Level Icon Badge
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: relationship.level.color.withOpacity(0.18),
                                border: Border.all(
                                  color: relationship.level.color.withOpacity(0.55),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: relationship.level.color.withOpacity(0.35),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(
                                relationship.level.icon,
                                color: relationship.level.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "INTIMACY BOND",
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    relationship.level.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: relationship.level.color,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // XP Pill Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: relationship.level.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: relationship.level.color.withOpacity(0.4),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("✨", style: TextStyle(fontSize: 11)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${relationship.affectionPoints} XP",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: relationship.level.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Info Icon (i) button
                            Tooltip(
                              message: "How XP Works",
                              child: GestureDetector(
                                onTap: () => _showXpInfoSheet(context, relationship),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.08),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Glowing Animated Progress Bar
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2132),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final progress = relationship.levelProgress.clamp(0.0, 1.0);
                              return Stack(
                                children: [
                                  Container(
                                    width: constraints.maxWidth * progress,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          relationship.level.color.withOpacity(0.7),
                                          relationship.level.color,
                                          const Color(0xFFFF66A1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: relationship.level.color.withOpacity(0.7),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Bottom Floor / Ceiling Labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Level: ${relationship.level.displayName}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              relationship.level == RelationshipLevel.partner
                                  ? "Max Intimacy reached 💕"
                                  : "${(relationship.levelProgress * 100).toInt()}% to ${_getNextLevelName(relationship.level)}",
                              style: TextStyle(
                                fontSize: 11,
                                color: relationship.level.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Voice Sample Audio Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF201633),
                          Color(0xFF141322),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _isPlayingVoicePreview
                            ? AppColors.primary
                            : Colors.white.withOpacity(0.08),
                        width: _isPlayingVoicePreview ? 1.5 : 1.0,
                      ),
                      boxShadow: _isPlayingVoicePreview
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleVoicePreview,
                          child: Container(
                            width: 44,
                            height: 44,
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
                            child: Icon(
                              _isPlayingVoicePreview ? Icons.stop_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _isPlayingVoicePreview ? "Playing Voice Sample..." : "Voice Sample",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _isPlayingVoicePreview ? AppColors.primaryLight : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (_isPlayingVoicePreview)
                                    const Icon(Icons.graphic_eq_rounded, color: AppColors.primaryLight, size: 16),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "\"${widget.character.voicePreviewQuote.isNotEmpty ? widget.character.voicePreviewQuote : widget.character.initialGreeting}\"",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bio Section
                  const Text(
                    "About",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.character.bio,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Character Traits / Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.character.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Scenarios Picker
                  const Text(
                    "Choose Roleplay Scenario",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.character.supportedScenarios.length,
                      itemBuilder: (context, index) {
                        final sType = widget.character.supportedScenarios[index];
                        final scenario = Scenario.allScenarios.firstWhere((s) => s.type == sType);
                        final isSelected = _selectedScenario.type == sType;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedScenario = scenario),
                          child: Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.surfaceLight : AppColors.surfaceGlass,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.glassBorder,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  scenario.icon,
                                  size: 24,
                                  color: isSelected ? AppColors.primary : AppColors.textTertiary,
                                ),
                                const Spacer(),
                                Text(
                                  scenario.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  scenario.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Action Bar: Chat and Voice Talk CTA Buttons
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Voice Talk Button (5 coins)
              Expanded(
                flex: 1,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.6)),
                  ),
                  child: TextButton.icon(
                    onPressed: () async {
                      if (!coinProvider.hasVoiceAccess()) {
                        InsufficientCoinsSheet.show(
                          context,
                          requiredCoins: 10,
                          actionName: "Voice Call with ${widget.character.name}",
                        );
                        return;
                      }

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => VoiceTalkScreen(
                            character: widget.character,
                            scenario: _selectedScenario,
                            currentMood: widget.currentMood?.type ?? widget.character.primaryMood,
                          ),
                        ),
                      );
                      if (mounted) {
                        chatProvider.refreshRelationship(widget.character.id);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.call_rounded, color: AppColors.secondaryLight, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Voice Talk",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Chat Button (1 diamond)
              Expanded(
                flex: 1,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      chatProvider.openChat(
                        character: widget.character,
                        scenario: _selectedScenario,
                      );
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => ChatScreen(
                            character: widget.character,
                            scenario: _selectedScenario,
                            currentMood: widget.currentMood?.type ?? widget.character.primaryMood,
                          ),
                        ),
                      );
                      if (mounted) {
                        chatProvider.refreshRelationship(widget.character.id);
                        setState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Chat Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNextLevelName(RelationshipLevel level) {
    switch (level) {
      case RelationshipLevel.stranger:
        return "Friend";
      case RelationshipLevel.friend:
        return "Close Friend";
      case RelationshipLevel.closeFriend:
        return "Crush";
      case RelationshipLevel.crush:
        return "Partner";
      case RelationshipLevel.partner:
        return "Soulmate";
    }
  }

  void _showXpInfoSheet(BuildContext context, CharacterRelationship relationship) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF131524),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.18),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                        ),
                        child: const Center(
                          child: Text("💖", style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "How Affection & XP Work",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Deepen your connection with ${widget.character.name}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 1. How you earn XP card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: AppColors.gold, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "How to Earn XP",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildXpMethodRow("💬 Text Messages", "+5 XP per message reply", "Chat freely with your companion"),
                        const SizedBox(height: 8),
                        _buildXpMethodRow("📞 Voice Calls", "+25 XP per minute of call", "Real-time emotional voice conversation"),
                        const SizedBox(height: 8),
                        _buildXpMethodRow("🎁 Virtual Gifts", "+25 to +800 XP instantly", "Roses, Chocolates, Perfume, Diamond Ring"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. What happens as XP increases
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "What Happens As XP Increases?",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildEffectRow("🎭 AI Persona Evolution", "Your companion speaks with greater intimacy, playful teasing, and sincere romance."),
                        const SizedBox(height: 8),
                        _buildEffectRow("🔓 Secret Memory Unlocks", "Unlock emotional backstories and shared memories in your profile dossier."),
                        const SizedBox(height: 8),
                        _buildEffectRow("👑 Relationship Tiers", "Progress from Stranger → Friend → Close Friend → Crush → Partner!"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Tiers Overview
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Relationship Tiers",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTierBadgeRow(RelationshipLevel.stranger, "0 - 49 XP", "Introductory & polite"),
                        _buildTierBadgeRow(RelationshipLevel.friend, "50 - 149 XP", "Warm & casual banter"),
                        _buildTierBadgeRow(RelationshipLevel.closeFriend, "150 - 349 XP", "High trust & vulnerability"),
                        _buildTierBadgeRow(RelationshipLevel.crush, "350 - 649 XP", "Mutual flirty tension"),
                        _buildTierBadgeRow(RelationshipLevel.partner, "650+ XP", "Deep unconditional romance"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text("Got It! 💕", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildXpMethodRow(String title, String xpBadge, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 1),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            xpBadge,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
          ),
        ),
      ],
    );
  }

  Widget _buildEffectRow(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
      ],
    );
  }

  Widget _buildTierBadgeRow(RelationshipLevel level, String xp, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(level.icon, size: 16, color: level.color),
          const SizedBox(width: 8),
          Text(
            level.displayName,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: level.color),
          ),
          const SizedBox(width: 6),
          Text("($xp)", style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          const SizedBox(width: 8),
          const Spacer(),
          Flexible(
            child: Text(
              desc,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
