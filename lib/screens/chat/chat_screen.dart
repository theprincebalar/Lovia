import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/character.dart';
import '../../models/emotion_state.dart';
import '../../models/message.dart';
import '../../models/mood.dart';
import '../../models/scenario.dart';
import '../../providers/chat_provider.dart';
import '../../providers/coin_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/character_avatar.dart';
import '../../widgets/coin_badge.dart';
import '../../widgets/insufficient_coins_dialog.dart';
import '../../widgets/moderation_dialogs.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/gift_selection_sheet.dart';
import '../../services/analytics_service.dart';
import '../voice/voice_talk_screen.dart';
import '../coins/coins_tab.dart';
import 'character_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final Character character;
  final Scenario scenario;
  final MoodType currentMood;

  const ChatScreen({
    super.key,
    required this.character,
    required this.scenario,
    required this.currentMood,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showFullAvatarStage = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chat = Provider.of<ChatProvider>(context, listen: false);
        if (chat.activeCharacter?.id != widget.character.id) {
          chat.openChat(character: widget.character, scenario: widget.scenario);
        }
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildCoverImage(String path, {BoxFit fit = BoxFit.cover, double? width, double? height, Alignment alignment = Alignment.center}) {
    String resolved = path;
    if (path.startsWith('assets/characters/')) {
      resolved = '${ApiService().baseUrl}/$path';
    }
    return AppCachedImage(
      imagePath: resolved,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      errorBuilder: (ctx, err, stack) => Container(color: AppColors.surfaceLight, child: const Icon(Icons.person, color: Colors.white24)),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    if (!coinProvider.isSubscribed && !coinProvider.hasEnoughCoins(1)) {
      InsufficientCoinsSheet.show(
        context,
        requiredCoins: 1,
        actionName: "AI Response",
        onCoinsAcquired: () {
          _handleSend();
        },
      );
      return;
    }

    _textController.clear();
    final sent = await chatProvider.sendMessage(text, widget.currentMood);
    if (sent) {
      AnalyticsService().logChatMessageSent(
        characterId: widget.character.id,
        characterName: widget.character.name,
      );
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, child) {
        final currentEmotion = chat.currentEmotion;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => CharacterProfileScreen(
                      character: widget.character,
                      currentMood: Mood.fromType(widget.currentMood),
                    ),
                  ),
                );
                if (context.mounted) {
                  chat.refreshRelationship(widget.character.id);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                child: Row(
                  children: [
                    ClipOval(
                      child: CharacterAvatar(
                        character: widget.character,
                        emotion: EmotionState.happy,
                        size: AvatarSize.small,
                        showAuraGlow: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.character.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: currentEmotion.accentColor,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  "${currentEmotion.displayName} • Fictional AI",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: currentEmotion.accentColor,
                                    fontWeight: FontWeight.w600,
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
            actions: [
              // Coin Balance Badge
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: CoinBadge(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const CoinsTab()),
                    );
                  },
                ),
              ),

              // Voice Call Action Icon
              IconButton(
                icon: const Icon(Icons.call_rounded, color: AppColors.primary),
                tooltip: "Voice Talk",
                onPressed: () async {
                  final coinProvider = Provider.of<CoinProvider>(context, listen: false);
                  if (!coinProvider.hasVoiceAccess()) {
                    InsufficientCoinsSheet.show(
                      context,
                      requiredCoins: 10,
                      actionName: "Voice Call with ${widget.character.name}",
                    );
                    return;
                  }

                  AnalyticsService().logVoiceCallStarted(
                    characterId: widget.character.id,
                    characterName: widget.character.name,
                    voiceQuotaOrDiamonds: coinProvider.voiceMinutesRemaining > 0
                        ? coinProvider.voiceMinutesRemaining
                        : coinProvider.balance,
                  );

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => VoiceTalkScreen(
                        character: widget.character,
                        scenario: chat.activeScenario,
                        currentMood: widget.currentMood,
                      ),
                    ),
                  );

                  // Seamlessly refresh chat history without reloading the page
                  if (context.mounted) {
                    chat.openChat(
                      character: widget.character,
                      scenario: chat.activeScenario,
                    );
                    _scrollToBottom();
                  }
                },
              ),

              // Scenario, Safety & Options Menu (Apple Guideline 1.2 & 5.6.4 compliant)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                color: AppColors.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'clear') {
                    chat.clearConversation();
                  } else if (val == 'scenario') {
                    _showScenarioPicker(context, chat);
                  } else if (val == 'safety') {
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
                  const PopupMenuItem(
                    value: 'scenario',
                    child: Row(
                      children: [
                        Icon(Icons.theater_comedy_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text("Switch Scenario", style: TextStyle(fontSize: 13)),
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
                        Text("Report Content", style: TextStyle(fontSize: 13, color: AppColors.warning)),
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
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.textTertiary),
                        SizedBox(width: 10),
                        Text("Clear History", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Scenario Context Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.7),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(chat.activeScenario.icon, size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Scenario: ${chat.activeScenario.title}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => GiftSelectionSheet.show(context, character: widget.character),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: chat.relationship.level.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: chat.relationship.level.color.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chat.relationship.level.icon, size: 12, color: chat.relationship.level.color),
                            const SizedBox(width: 4),
                            Text(
                              chat.relationship.level.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: chat.relationship.level.color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text("🎁", style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Immersive Character Stage & Live Avatar (Showing the character's full artwork in chat)
              if (_showFullAvatarStage)
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withOpacity(0.4),
                    border: const Border(
                      bottom: BorderSide(color: AppColors.glassBorder),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Atmospheric cover art backdrop with soft blur and gradient
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.22,
                          child: _buildCoverImage(
                            widget.character.coverImagePath,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.4),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.background.withOpacity(0.85),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Character Avatar Sprite
                      Center(
                        child: CharacterAvatar(
                          character: widget.character,
                          emotion: EmotionState.happy,
                          size: AvatarSize.large,
                          showAuraGlow: true,
                        ),
                      ),
                      // Close / Collapse Stage button
                      Positioned(
                        top: 6,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white60, size: 20),
                          tooltip: "Hide Character Avatar",
                          onPressed: () => setState(() => _showFullAvatarStage = false),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Collapsed indicator allowing user to re-open character artwork
                GestureDetector(
                  onTap: () => setState(() => _showFullAvatarStage = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildCoverImage(
                            widget.character.coverImagePath,
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Show Character Avatar",
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),

              // Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: chat.messages.length + (chat.isAiTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chat.messages.length && chat.isAiTyping) {
                      return TypingIndicator(character: widget.character);
                    }

                    final message = chat.messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
              ),

              // Regenerate button row (if last message is AI)
              if (chat.messages.isNotEmpty && !chat.messages.last.isUser && !chat.isAiTyping)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: TextButton.icon(
                    onPressed: () => chat.regenerateLastResponse(widget.currentMood),
                    icon: const Icon(Icons.refresh_rounded, size: 15, color: AppColors.textTertiary),
                    label: const Text(
                      "Regenerate response (1 diamond)",
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ),
                ),

              // Bottom Input Bar
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.glassBorder)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Send Gift shortcut button
                        IconButton(
                          icon: const Icon(Icons.card_giftcard_rounded, color: AppColors.secondaryLight),
                          tooltip: "Send a Gift",
                          onPressed: () => GiftSelectionSheet.show(context, character: widget.character),
                        ),

                        // Text Field
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSend(),
                            decoration: InputDecoration(
                              hintText: "Roleplay with ${widget.character.name.split(' ')[0]}...",
                              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                              filled: true,
                              fillColor: AppColors.surfaceLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Send Button
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            onPressed: _handleSend,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    final isGiftMessage = isUser && message.content.startsWith('*sent you');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Character Avatar thumbnail beside AI message
          if (!isUser) ...[
            ClipOval(
              child: CharacterAvatar(
                character: widget.character,
                emotion: EmotionState.happy,
                size: AvatarSize.small,
                showAuraGlow: false,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble Content
          Flexible(
            child: GestureDetector(
              onLongPress: !isUser
                  ? () => ModerationDialogs.showReportDialog(
                        context,
                        character: widget.character,
                        message: message,
                      )
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isGiftMessage
                      ? const LinearGradient(
                          colors: [Color(0xFFFFB800), Color(0xFFFF2D78)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : (isUser
                          ? AppColors.primaryGradient
                          : const LinearGradient(
                              colors: [Color(0xFF1F2233), Color(0xFF171926)],
                            )),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  border: Border.all(
                    color: isGiftMessage
                        ? AppColors.goldLight
                        : (isUser ? Colors.transparent : AppColors.glassBorder),
                    width: isGiftMessage ? 1.5 : 1.0,
                  ),
                  boxShadow: isGiftMessage
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Formatted Roleplay text (Actions vs Dialogue)
                    _buildFormattedContent(message.content, isUser),
                    const SizedBox(height: 6),

                    // Bubble Footer: Timestamp & Moderation Report for AI
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isUser ? Colors.white70 : AppColors.textTertiary,
                          ),
                        ),
                        if (!isUser) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => ModerationDialogs.showReportDialog(
                              context,
                              character: widget.character,
                              message: message,
                            ),
                            child: const Icon(
                              Icons.flag_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Parses text with *roleplay actions* in italic and spoken dialogue in clear text
  Widget _buildFormattedContent(String text, bool isUser) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*[^*]+\*)');
    final matches = regex.allMatches(text);

    int lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              fontSize: 14,
              color: isUser ? Colors.white : AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        );
      }
      // Action text
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: isUser ? Colors.white.withOpacity(0.85) : AppColors.secondaryLight,
            height: 1.4,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : AppColors.textPrimary,
            height: 1.4,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showScenarioPicker(BuildContext context, ChatProvider chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Change Roleplay Scenario",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: Scenario.allScenarios.map((sc) {
                    final isSel = chat.activeScenario.type == sc.type;
                    return ListTile(
                      leading: Icon(sc.icon, color: isSel ? AppColors.primary : Colors.white70),
                      title: Text(sc.title, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(sc.subtitle, style: const TextStyle(fontSize: 11)),
                      trailing: isSel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                      onTap: () {
                        chat.setScenario(sc);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
