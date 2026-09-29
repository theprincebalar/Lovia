import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/character.dart';
import '../../models/mood.dart';
import '../../models/scenario.dart';
import '../../providers/voice_provider.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/character_avatar.dart';
import '../../widgets/audio_visualizer.dart';
import '../../widgets/glass_container.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceTalkScreen extends StatefulWidget {
  final Character character;
  final Scenario scenario;
  final MoodType currentMood;

  const VoiceTalkScreen({
    super.key,
    required this.character,
    required this.scenario,
    required this.currentMood,
  });

  @override
  State<VoiceTalkScreen> createState() => _VoiceTalkScreenState();
}

class _VoiceTalkScreenState extends State<VoiceTalkScreen> {
  final TextEditingController _voiceInputSimController = TextEditingController();

  VoiceProvider? _voiceProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final vp = Provider.of<VoiceProvider>(context, listen: false);
        if (!vp.isCallActive || vp.activeCharacter?.id != widget.character.id) {
          vp.startCall(
            character: widget.character,
            scenario: widget.scenario,
            currentMood: widget.currentMood,
          );
        } else {
          vp.ensureMicrophonePermission();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _voiceInputSimController.dispose();
    if (_voiceProvider?.isCallActive ?? false) {
      _voiceProvider?.endCall();
    }
    super.dispose();
  }

  void _sendSpokenInput(String text) {
    if (text.trim().isEmpty) return;
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.handleUserSpeech(
      userText: text,
      scenario: widget.scenario,
      currentMood: widget.currentMood,
    );
    _voiceInputSimController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voice, child) {
        final status = voice.status;
        final currentEmotion = voice.currentEmotion;

        String statusLabel = "Connecting...";
        Color statusColor = AppColors.warning;
        IconData statusIcon = Icons.sensors_rounded;

        switch (status) {
          case VoiceCallStatus.connecting:
            statusLabel = "Connecting...";
            statusColor = AppColors.warning;
            statusIcon = Icons.wifi_protected_setup_rounded;
            break;
          case VoiceCallStatus.listening:
            statusLabel = "Listening to you...";
            statusColor = AppColors.tertiary;
            statusIcon = Icons.mic_rounded;
            break;
          case VoiceCallStatus.thinking:
            statusLabel = "${widget.character.name.split(' ')[0]} is thinking...";
            statusColor = AppColors.secondaryLight;
            statusIcon = Icons.auto_awesome_rounded;
            break;
          case VoiceCallStatus.speaking:
            statusLabel = "${widget.character.name.split(' ')[0]} is speaking (${currentEmotion.displayName})";
            statusColor = currentEmotion.accentColor;
            statusIcon = Icons.volume_up_rounded;
            break;
          case VoiceCallStatus.idle:
            statusLabel = "Call Ended";
            statusColor = AppColors.textTertiary;
            statusIcon = Icons.call_end_rounded;
            break;
        }

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              voice.endCall();
            }
          },
          child: Scaffold(
          backgroundColor: const Color(0xFF07080E),
          body: SafeArea(
            child: Stack(
              children: [
                // 1. Ambient Dynamic Glow
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          currentEmotion.accentColor.withOpacity(0.18),
                          Colors.transparent,
                        ],
                        center: const Alignment(0, -0.1),
                        radius: 0.8,
                      ),
                    ),
                  ),
                ),

                // 2. Main Content
                Column(
                  children: [
                    // Top App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.white70),
                            onPressed: () {
                              voice.endCall();
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  widget.character.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "Scenario: ${widget.scenario.title}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  voice.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                  color: voice.isMuted ? AppColors.error : Colors.white70,
                                ),
                                onPressed: voice.toggleMute,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Pill, Call Duration & Minutes Remaining Row
                    Container(
                      margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 14, color: statusColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 13, color: Colors.white70),
                                  const SizedBox(width: 5),
                                  Text(
                                    voice.callDurationMinutes > 0
                                        ? "${voice.formattedCallDuration} (${voice.callDurationMinutes}m)"
                                        : voice.formattedCallDuration,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    voice.isUsingSubscriptionMinutes ? "• VIP" : "• 10💎/m",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: voice.isUsingSubscriptionMinutes ? AppColors.accent : AppColors.diamondLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: voice.isUsingSubscriptionMinutes
                                    ? AppColors.primary.withOpacity(0.18)
                                    : AppColors.diamondDark.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: voice.isUsingSubscriptionMinutes
                                      ? AppColors.primaryLight.withOpacity(0.5)
                                      : AppColors.diamondLight.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    voice.isUsingSubscriptionMinutes
                                        ? Icons.hourglass_bottom_rounded
                                        : Icons.diamond_rounded,
                                    size: 13,
                                    color: voice.isUsingSubscriptionMinutes
                                        ? AppColors.primaryLight
                                        : AppColors.diamondLight,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    voice.remainingMinutesLabel,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: voice.isUsingSubscriptionMinutes
                                          ? Colors.white
                                          : AppColors.goldLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Interactive Microphone Permission Banner (when permission or STT is needed)
                    if (!voice.hasMicPermission)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D1B28),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF4B72).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic_off_rounded, color: Color(0xFFFF4B72), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Mic permission needed",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () async {
                                final granted = await voice.ensureMicrophonePermission();
                                if (!context.mounted) return;
                                if (granted) {
                                  voice.triggerListening();
                                } else {
                                  final status = await Permission.microphone.status;
                                  if (status.isPermanentlyDenied) {
                                    await openAppSettings();
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4B72),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "Allow",
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (!voice.isSttAvailable)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2332),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.keyboard_rounded, color: Color(0xFF00D2FF), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Speech engine offline • Tap to type",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await voice.ensureMicrophonePermission();
                                    voice.triggerListening();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D2FF).withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00D2FF)),
                                    ),
                                    child: const Text(
                                      "Retry",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _showSpeechInputModal(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Text(
                                      "Type",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // ElevenLabs Notice Banner (if any error occurs)
                    if (voice.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B141D),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.error.withOpacity(0.8), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2.0),
                              child: Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Voice Studio Notice",
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    voice.errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                              onPressed: () => voice.clearErrorMessage(),
                            ),
                          ],
                        ),
                      ),

                    // 3. Flexible Center Area (Avatar + Subtitles) - Auto-scales to prevent any overflow
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableHeight = constraints.maxHeight;
                          final bool hasSubtitle = voice.characterSpokenText.isNotEmpty;
                          final double avatarDim = (hasSubtitle
                                  ? (availableHeight * 0.54)
                                  : (availableHeight * 0.72))
                              .clamp(130.0, 240.0);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Hero(
                                tag: 'avatar_${widget.character.id}',
                                child: SizedBox(
                                  width: avatarDim,
                                  height: avatarDim,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: CharacterAvatar(
                                      character: widget.character,
                                      emotion: currentEmotion,
                                      size: AvatarSize.large,
                                      showAuraGlow: true,
                                    ),
                                  ),
                                ),
                              ),
                              if (hasSubtitle)
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: GlassContainer(
                                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Text(
                                        voice.characterSpokenText,
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                          height: 1.35,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Live User Speech Transcript Bubble (Spoken in real-time)
                              if (voice.liveTranscript.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D2FF).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.mic_rounded, color: Color(0xFF00D2FF), size: 16),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            "You: ${voice.liveTranscript}",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF00D2FF),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                    // 4. Animated Soundwave Visualizer
                    AudioVisualizer(
                      frequencies: voice.visualizerFrequencies,
                      barColor: currentEmotion.accentColor,
                      height: 42,
                      isSpeaking: voice.isAnyoneSpeaking,
                      isUserSpeaking: voice.isUserSpeaking,
                    ),
                    const SizedBox(height: 12),

                    // 5. Call Controls Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Mute / Unmute Microphone
                          _buildControlCircle(
                            icon: voice.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: voice.isMuted ? AppColors.error.withOpacity(0.2) : AppColors.surfaceLight,
                            iconColor: voice.isMuted ? AppColors.error : Colors.white70,
                            onTap: () => voice.toggleMute(),
                          ),

                          // Text simulation input modal button
                          _buildControlCircle(
                            icon: Icons.keyboard_rounded,
                            color: AppColors.surfaceLight,
                            iconColor: Colors.white70,
                            onTap: () => _showSpeechInputModal(context),
                          ),

                          // Push to Talk / Speak Microphone Main Button
                          GestureDetector(
                            onTap: () async {
                              if (!voice.hasMicPermission) {
                                final granted = await voice.ensureMicrophonePermission();
                                if (!context.mounted) return;
                                if (granted) {
                                  voice.triggerListening();
                                } else {
                                  _showSpeechInputModal(context);
                                }
                              } else {
                                voice.triggerListening();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: voice.isUserSpeaking
                                    ? const LinearGradient(colors: [Color(0xFF00D2FF), Color(0xFF0077B6)])
                                    : (voice.isAgentSpeaking
                                        ? LinearGradient(colors: [currentEmotion.accentColor, AppColors.primary])
                                        : const LinearGradient(colors: [Color(0xFF25293A), Color(0xFF191C28)])),
                                border: Border.all(
                                  color: voice.isUserSpeaking
                                      ? const Color(0xFF00D2FF).withOpacity(0.8)
                                      : (voice.isAgentSpeaking
                                          ? currentEmotion.accentColor.withOpacity(0.8)
                                          : AppColors.glassBorder),
                                  width: 1.5,
                                ),
                                boxShadow: voice.isAnyoneSpeaking
                                    ? [
                                        BoxShadow(
                                          color: (voice.isUserSpeaking
                                                  ? const Color(0xFF00D2FF)
                                                  : currentEmotion.accentColor)
                                              .withOpacity(0.45),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                voice.isAgentSpeaking
                                    ? Icons.graphic_eq_rounded
                                    : (voice.isUserSpeaking ? Icons.mic_rounded : Icons.mic_none_rounded),
                                size: 30,
                                color: voice.isAnyoneSpeaking ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),

                          // End Call Button
                          _buildControlCircle(
                            icon: Icons.call_end_rounded,
                            color: AppColors.error,
                            iconColor: Colors.white,
                            onTap: () {
                              voice.endCall();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildControlCircle({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  void _showSpeechInputModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Speak or Type Message",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _voiceInputSimController,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                onSubmitted: (val) {
                  Navigator.pop(ctx);
                  _sendSpokenInput(val);
                },
                decoration: InputDecoration(
                  hintText: "Speak your mind...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: () {
                      final val = _voiceInputSimController.text;
                      Navigator.pop(ctx);
                      _sendSpokenInput(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
