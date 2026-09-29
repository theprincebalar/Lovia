import 'dart:async';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/emotion_state.dart';
import '../services/storage_service.dart';
import '../services/voice_service.dart';
import '../theme/app_colors.dart';
import 'app_cached_image.dart';

class VoiceStudioSheet extends StatefulWidget {
  final Character character;
  final StorageService storageService;
  final VoidCallback? onVoiceUpdated;
  final bool allowToneChange;

  const VoiceStudioSheet({
    super.key,
    required this.character,
    required this.storageService,
    this.onVoiceUpdated,
    this.allowToneChange = true,
  });

  static Future<void> show(
    BuildContext context, {
    required Character character,
    required StorageService storageService,
    VoidCallback? onVoiceUpdated,
    bool allowToneChange = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => VoiceStudioSheet(
        character: character,
        storageService: storageService,
        onVoiceUpdated: onVoiceUpdated,
        allowToneChange: allowToneChange,
      ),
    );
  }

  @override
  State<VoiceStudioSheet> createState() => _VoiceStudioSheetState();
}

class _VoiceStudioSheetState extends State<VoiceStudioSheet> {
  final VoiceService _voiceService = VoiceService();
  late double _pitch;
  late double _rate;
  late double _emotionIntensity;
  late String _engineMode;
  late TextEditingController _apiKeyController;
  late TextEditingController _elevenApiKeyController;
  late TextEditingController _customVoiceIdController;
  late TextEditingController _geminiApiKeyController;
  String? _selectedPersonaPreset;
  EmotionState _previewEmotion = EmotionState.romantic;
  bool _isTesting = false;
  StreamSubscription<String>? _errorSubscription;
  List<Map<String, String>> _fetchedElevenLabsVoices = [];
  bool _isLoadingElevenLabsVoices = false;

  Future<void> _fetchAccountVoices() async {
    setState(() => _isLoadingElevenLabsVoices = true);
    final key = _elevenApiKeyController.text.trim().isNotEmpty
        ? _elevenApiKeyController.text.trim()
        : null;
    final voices = await _voiceService.fetchElevenLabsAccountVoices(
      apiKey: key,
      storageService: widget.storageService,
    );
    if (mounted) {
      setState(() {
        _fetchedElevenLabsVoices = voices;
        _isLoadingElevenLabsVoices = false;
      });
      if (voices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No voices returned. Please verify your Neural Voice configuration."),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pitch = widget.storageService.getCharacterVoicePitch(
      widget.character.id,
      widget.character.voiceProfile.defaultPitch,
    );
    _rate = widget.storageService.getCharacterVoiceRate(
      widget.character.id,
      widget.character.voiceProfile.defaultRate,
    );
    _emotionIntensity = widget.storageService.getCharacterEmotionIntensity(
      widget.character.id,
    );
    _engineMode = widget.storageService.getVoiceEngineMode();
    _apiKeyController = TextEditingController(
      text: widget.storageService.getOpenAiApiKey() ?? '',
    );
    _elevenApiKeyController = TextEditingController(
      text: widget.storageService.getElevenLabsApiKey() ?? '',
    );
    _geminiApiKeyController = TextEditingController(
      text: widget.storageService.getGeminiApiKey() ?? '',
    );
    _customVoiceIdController = TextEditingController(
      text: widget.storageService.getCharacterElevenLabsVoice(widget.character.id) ??
          widget.character.voiceProfile.elevenLabsVoiceId,
    );
    _selectedPersonaPreset = widget.storageService.getCharacterVoicePersona(widget.character.id);

    _errorSubscription = _voiceService.errorMessageStream.listen((msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _apiKeyController.dispose();
    _elevenApiKeyController.dispose();
    _geminiApiKeyController.dispose();
    _customVoiceIdController.dispose();
    super.dispose();
  }

  String _getPitchLabel(double pitch) {
    if (pitch < 0.85) return "Deep Baritone / Low Alto";
    if (pitch < 1.02) return "Warm & Grounded";
    if (pitch < 1.14) return "Melodic & Tender";
    return "Bright & Youthful Soprano";
  }

  String _getRateLabel(double rate) {
    if (rate < 0.38) return "Calm & Intimate";
    if (rate < 0.44) return "Natural Conversational";
    return "Energetic & Animated";
  }

  String _getIntensityLabel(double intensity) {
    if (intensity < 0.8) return "Subtle Inflection";
    if (intensity < 1.3) return "Expressive & Natural";
    return "Passionate Drama";
  }

  String _getEmotionSampleQuote(EmotionState emotion) {
    switch (emotion) {
      case EmotionState.romantic:
        return "Every time I look at you... my heart whispers that you're the one.";
      case EmotionState.shy:
        return "U-um... I've been thinking about you all day... is that silly?";
      case EmotionState.happy:
        return "Seeing your smile right now is the sweetest thing in the world!";
      case EmotionState.excited:
        return "You won't believe this! We have to celebrate together right now!";
      case EmotionState.sad:
        return "I'm sorry... I just really needed to hear your voice tonight.";
      case EmotionState.emotional:
        return "Take a deep breath. Whatever you've been carrying, I'm right here with you.";
      case EmotionState.playful:
      case EmotionState.laughing:
        return "Are you blushing already? You're too cute when you try to act innocent!";
      case EmotionState.angry:
        return "I can't stand seeing anyone treat you like that. You deserve so much better!";
      default:
        return widget.character.voicePreviewQuote;
    }
  }

  void _applyPreset(String key) {
    setState(() {
      _selectedPersonaPreset = key;
      switch (key) {
        case 'soft':
          _pitch = (widget.character.voiceProfile.defaultPitch + 0.06).clamp(0.70, 1.30);
          _rate = (widget.character.voiceProfile.defaultRate - 0.04).clamp(0.30, 0.55);
          _emotionIntensity = 1.3;
          break;
        case 'deep':
          _pitch = (widget.character.voiceProfile.defaultPitch - 0.08).clamp(0.70, 1.30);
          _rate = (widget.character.voiceProfile.defaultRate - 0.02).clamp(0.30, 0.55);
          _emotionIntensity = 1.1;
          break;
        case 'bright':
          _pitch = (widget.character.voiceProfile.defaultPitch + 0.08).clamp(0.70, 1.30);
          _rate = (widget.character.voiceProfile.defaultRate + 0.03).clamp(0.30, 0.55);
          _emotionIntensity = 1.4;
          break;
        case 'signature':
        default:
          _pitch = widget.character.voiceProfile.defaultPitch;
          _rate = widget.character.voiceProfile.defaultRate;
          _emotionIntensity = 1.0;
          break;
      }
    });
  }

  Future<void> _testVoice({EmotionState? emotionOverride}) async {
    final emotion = emotionOverride ?? _previewEmotion;
    if (_isTesting) {
      await _voiceService.stop();
      setState(() => _isTesting = false);
      return;
    }

    // Persist transient inputs so test respects current engine mode & keys
    await widget.storageService.setVoiceEngineMode(_engineMode);
    if (_engineMode == 'elevenlabs' && _elevenApiKeyController.text.trim().isNotEmpty) {
      await widget.storageService.setElevenLabsApiKey(_elevenApiKeyController.text.trim());
      await widget.storageService.setCharacterElevenLabsVoice(
        widget.character.id,
        _customVoiceIdController.text.trim(),
      );
    } else if (_engineMode == 'openai_neural' && _apiKeyController.text.trim().isNotEmpty) {
      await widget.storageService.setOpenAiApiKey(_apiKeyController.text.trim());
    }

    setState(() => _isTesting = true);
    await _voiceService.testVoice(
      character: widget.character,
      pitch: _pitch,
      rate: _rate,
      emotion: emotion,
      emotionIntensity: _emotionIntensity,
      storageService: widget.storageService,
      sampleText: _getEmotionSampleQuote(emotion),
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isTesting = false);
    });
  }

  Future<void> _saveVoice() async {
    await widget.storageService.setCharacterVoicePitch(widget.character.id, _pitch);
    await widget.storageService.setCharacterVoiceRate(widget.character.id, _rate);
    await widget.storageService.setCharacterEmotionIntensity(widget.character.id, _emotionIntensity);
    await widget.storageService.setVoiceEngineMode(_engineMode);

    if (_geminiApiKeyController.text.trim().isNotEmpty) {
      await widget.storageService.setGeminiApiKey(_geminiApiKeyController.text.trim());
    }

    if (_engineMode == 'elevenlabs' && _elevenApiKeyController.text.trim().isNotEmpty) {
      await widget.storageService.setElevenLabsApiKey(_elevenApiKeyController.text.trim());
      await widget.storageService.setCharacterElevenLabsVoice(
        widget.character.id,
        _customVoiceIdController.text.trim(),
      );
    } else if (_engineMode == 'openai_neural' && _apiKeyController.text.trim().isNotEmpty) {
      await widget.storageService.setOpenAiApiKey(_apiKeyController.text.trim());
    }

    if (_selectedPersonaPreset != null) {
      await widget.storageService.setCharacterVoicePersona(widget.character.id, _selectedPersonaPreset!);
    }
    widget.onVoiceUpdated?.call();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emotional Voice saved for ${widget.character.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetDefault() async {
    await widget.storageService.resetCharacterVoice(widget.character.id);
    setState(() {
      _pitch = widget.character.voiceProfile.defaultPitch;
      _rate = widget.character.voiceProfile.defaultRate;
      _emotionIntensity = 1.0;
      _selectedPersonaPreset = null;
      _customVoiceIdController.text = 'QAmlwgbPtjxpk7u98Qs9';
    });
    widget.onVoiceUpdated?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppCachedImage.characterCover(
                    character: widget.character,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
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
                              widget.character.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Voice Studio',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '🎙️ ${widget.character.voiceProfile.personaName} • Actor: ${widget.character.voiceProfile.openAiVoice}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Engine Selector Card
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        // 1. ElevenLabs (Premier Engine)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _engineMode = 'elevenlabs'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                gradient: _engineMode == 'elevenlabs'
                                    ? AppColors.primaryGradient
                                    : null,
                                color: _engineMode == 'elevenlabs'
                                    ? null
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  "💎 Lovia Neural Voice",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: _engineMode == 'elevenlabs'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 2. OpenAI Neural (Optional)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _engineMode = 'openai_neural'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _engineMode == 'openai_neural'
                                    ? AppColors.secondary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  "🎙️ Natural Speech",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: _engineMode == 'openai_neural'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lovia Neural Voice Configuration Box
                  if (_engineMode == 'elevenlabs') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.accent.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    "💎 Lovia Neural Voice",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "Hyper-Emotional",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "High-fidelity AI voice with emotional prosody, sighs, whispers, and breathing enabled for this character.",
                            style: TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          if (widget.allowToneChange) ...[
                            Row(
                              children: [
                                const Text(
                                  "Voice ID: ",
                                  style: TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _customVoiceIdController,
                                    style: const TextStyle(fontSize: 12, color: AppColors.accent),
                                    decoration: InputDecoration(
                                      hintText: "Character Voice ID",
                                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                                      filled: true,
                                      fillColor: Colors.black26,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: _isLoadingElevenLabsVoices ? null : _fetchAccountVoices,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    backgroundColor: Colors.white.withOpacity(0.06),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: _isLoadingElevenLabsVoices
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                        )
                                      : const Icon(Icons.sync_rounded, size: 16, color: AppColors.accent),
                                  label: Text(
                                    _isLoadingElevenLabsVoices ? "Fetching Voices..." : "List Available Voices",
                                    style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (_fetchedElevenLabsVoices.isNotEmpty)
                                  Text(
                                    "${_fetchedElevenLabsVoices.length} found",
                                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                                  ),
                              ],
                            ),
                            if (_fetchedElevenLabsVoices.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: _fetchedElevenLabsVoices.length,
                                  separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                                  itemBuilder: (ctx, i) {
                                    final v = _fetchedElevenLabsVoices[i];
                                    final vId = v['voice_id'] ?? '';
                                    final isSelected = _customVoiceIdController.text == vId;
                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              v['name'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? AppColors.accent : Colors.white,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: v['category'] == 'cloned' ? AppColors.primary.withOpacity(0.3) : Colors.white10,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              v['category'] ?? '',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: v['category'] == 'cloned' ? AppColors.primaryLight : Colors.white60,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        vId,
                                        style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                                      ),
                                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18) : null,
                                      onTap: () {
                                        setState(() {
                                          _customVoiceIdController.text = vId;
                                        });
                                        widget.storageService.setCharacterElevenLabsVoice(widget.character.id, vId);
                                        widget.onVoiceUpdated?.call();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 2. Interactive Emotion Tester
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Live Emotion Previewer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Tap to listen in this emotion',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildEmotionChip(EmotionState.romantic, 'Romantic', '💖'),
                        _buildEmotionChip(EmotionState.shy, 'Shy', '😳'),
                        _buildEmotionChip(EmotionState.happy, 'Happy', '😄'),
                        _buildEmotionChip(EmotionState.excited, 'Excited', '✨'),
                        _buildEmotionChip(EmotionState.sad, 'Sad', '😢'),
                        _buildEmotionChip(EmotionState.playful, 'Playful', '🎭'),
                        _buildEmotionChip(EmotionState.emotional, 'Heartfelt', '🌸'),
                        _buildEmotionChip(EmotionState.angry, 'Angry', '😤'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Emotional Intensity Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Emotional Expressiveness',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getIntensityLabel(_emotionIntensity),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _emotionIntensity,
                      min: 0.50,
                      max: 1.80,
                      divisions: 26,
                      onChanged: (val) => setState(() => _emotionIntensity = val),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (widget.allowToneChange) ...[
                    // 4. Vocal Presets
                    const Text(
                      'Vocal Presets',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip('signature', 'Signature Tone', Icons.stars_rounded),
                        _buildPresetChip('soft', 'Soft & Whisper', Icons.air_rounded),
                        _buildPresetChip('deep', 'Deep & Velvety', Icons.graphic_eq_rounded),
                        _buildPresetChip('bright', 'Bright Anime', Icons.bolt_rounded),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Pitch Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Vocal Pitch',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getPitchLabel(_pitch),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _pitch,
                        min: 0.70,
                        max: 1.30,
                        divisions: 60,
                        onChanged: (val) {
                          setState(() {
                            _pitch = val;
                            _selectedPersonaPreset = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, color: AppColors.accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Voice tone is locked to ${widget.character.name}'s signature persona during calls.",
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                // Speech Rate Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Conversational Pace',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getRateLabel(_rate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _rate,
                    min: 0.30,
                    max: 0.55,
                    divisions: 50,
                    onChanged: (val) {
                      setState(() {
                        _rate = val;
                        _selectedPersonaPreset = null;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Sample Quote preview for current emotion
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getEmotionSampleQuote(_previewEmotion),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Buttons: Test & Save
                Row(
                  children: [
                    // Test Button
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: _isTesting ? AppColors.accent : Colors.white24,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          _isTesting ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: _isTesting ? AppColors.accent : Colors.white,
                        ),
                        label: Text(_isTesting ? 'Playing...' : 'Test Voice'),
                        onPressed: () => _testVoice(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save & Apply Button
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                          shadowColor: AppColors.primary.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'Save & Apply',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _saveVoice,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Reset default text button
                Center(
                  child: TextButton.icon(
                    onPressed: _resetDefault,
                    icon: const Icon(Icons.restore_rounded, size: 16, color: Colors.white38),
                    label: const Text(
                      'Reset to Character Default',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
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

  Widget _buildEmotionChip(EmotionState emotion, String label, String emoji) {
    final isSelected = _previewEmotion == emotion;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          "$emoji $label",
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary.withValues(alpha: 0.5),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.white12,
          ),
        ),
        onSelected: (_) {
          setState(() => _previewEmotion = emotion);
          _testVoice(emotionOverride: emotion);
        },
      ),
    );
  }

  Widget _buildPresetChip(String key, String label, IconData icon) {
    final isSelected = _selectedPersonaPreset == key;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : Colors.white60,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.4),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.white12,
        ),
      ),
      onSelected: (_) => _applyPreset(key),
    );
  }
}
