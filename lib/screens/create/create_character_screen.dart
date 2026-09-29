import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/character.dart';
import '../../models/mood.dart';
import '../../models/scenario.dart';
import '../../providers/chat_provider.dart';
import '../../providers/mood_provider.dart';
import '../../services/api_service.dart';
import '../../services/analytics_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_cached_image.dart';
import '../chat/chat_screen.dart';

class CreateCharacterScreen extends StatefulWidget {
  final bool isTab;

  const CreateCharacterScreen({super.key, this.isTab = false});

  @override
  State<CreateCharacterScreen> createState() => _CreateCharacterScreenState();
}

class _CreateCharacterScreenState extends State<CreateCharacterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController(text: "21");
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _taglineController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _personalityController = TextEditingController();
  final TextEditingController _customPromptController = TextEditingController();
  final TextEditingController _greetingController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();

  Gender _selectedGender = Gender.female;
  MoodType _selectedMood = MoodType.romantic;
  String _selectedAvatarFolder = "seraphina_lin_romantic";
  bool _useCustomImage = false;
  String? _customImagePath;
  String _selectedVoiceId = "3YXAuwCx7wB8kSkKCqsu";
  String _selectedVoiceName = "Intimate Romantic Female";

  final VoiceService _voiceService = VoiceService();
  bool _isPlayingVoicePreview = false;
  StreamSubscription<bool>? _speakingSub;

  Future<void> _pickCustomImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() {
          _customImagePath = picked.path;
          _useCustomImage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not select image: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static const List<Map<String, String>> _femaleAvatars = [
    {"id": "seraphina_lin_romantic", "name": "Seraphina", "title": "Violinist"},
    {"id": "aria_sterling_happy", "name": "Aria", "title": "Radiant"},
    {"id": "elena_rostova_romantic", "name": "Elena", "title": "Aristocrat"},
    {"id": "chloe_bright_excited", "name": "Chloe", "title": "Energetic"},
    {"id": "maya_thorne_romantic", "name": "Maya", "title": "Stargazer"},
    {"id": "camila_santos_flirty", "name": "Camila", "title": "Sultry"},
    {"id": "valentina_cruz_flirty", "name": "Valentina", "title": "Charming"},
    {"id": "hinata_mori_shy", "name": "Hinata", "title": "Sweet"},
    {"id": "ruby_fox_playful", "name": "Ruby", "title": "Playful"},
    {"id": "elektra_thorne_angry", "name": "Elektra", "title": "Rebel"},
    {"id": "celeste_moreau_sad", "name": "Celeste", "title": "Gentle"},
    {"id": "zoe_adams_happy", "name": "Zoe", "title": "Warm"},
  ];

  static const List<Map<String, String>> _maleAvatars = [
    {"id": "liam_vance_romantic", "name": "Liam", "title": "Poet"},
    {"id": "damon_cross_romantic", "name": "Damon", "title": "Devoted"},
    {"id": "kai_rodriguez_happy", "name": "Kai", "title": "Athletic"},
    {"id": "julian_mercer_romantic", "name": "Julian", "title": "Gentleman"},
    {"id": "alec_sterling_romantic", "name": "Alec", "title": "Affectionate"},
    {"id": "rex_hunter_confident", "name": "Rex", "title": "Executive"},
    {"id": "chase_murphy_playful", "name": "Chase", "title": "Tease"},
    {"id": "dante_rossi_flirty", "name": "Dante", "title": "Charismatic"},
    {"id": "soren_lind_flirty", "name": "Soren", "title": "Rebel"},
    {"id": "casper_gray_shy", "name": "Casper", "title": "Bashful"},
    {"id": "drax_mercer_angry", "name": "Drax", "title": "Protector"},
    {"id": "noah_caldwell_sad", "name": "Noah", "title": "Deep"},
  ];

  List<Map<String, String>> get _currentAvatarPool =>
      _selectedGender == Gender.female ? _femaleAvatars : _maleAvatars;

  final List<Map<String, dynamic>> _archetypeTemplates = [
    {
      "title": "Tsundere Rival",
      "subtitle": "Sharp-tongued but secretly adoring",
      "icon": "⚡",
      "gender": Gender.female,
      "name": "Emi Kurogane",
      "age": "20",
      "occupation": "Top Academy Rival",
      "tagline": "Don't get the wrong idea... I didn't come here to see you!",
      "personality": "Tsundere, feisty, fiercely loyal, blushes easily, protective",
      "bio": "Your fierce academic rival who always competes with you for first place. Beneath her haughty exterior and quick temper, she is secretly devoted and gets flustered whenever you smile at her.",
      "prompt": "You are a classic anime Tsundere. You often act annoyed, proud, and defensive, but your actions show deep affection. You say 'B-Baka' or get flustered when complimented. Never break character. Always address the user by name.",
      "greeting": "*crosses arms and averts her eyes, cheeks faintly pink* \"Hmph! What took you so long? Don't tell me you kept me waiting on purpose!\"",
      "quote": "It's not like I wanted to talk to you or anything... b-baka!",
      "mood": MoodType.flirty,
      "voiceId": "2NzqTfQARqdn4tcBKTSh",
      "voiceName": "Talkative Female",
    },
    {
      "title": "Gentle Childhood Friend",
      "subtitle": "Pure, warm, and always by your side",
      "icon": "🌸",
      "gender": Gender.female,
      "name": "Hana Takahashi",
      "age": "21",
      "occupation": "Florist & Botany Student",
      "tagline": "No matter how much time passes, you're always my home.",
      "personality": "Sweet, nurturing, gentle, empathetic, quietly romantic",
      "bio": "Your childhood best friend who has quietly loved you for years. She knows all your favorite things and brings a calm, warm breeze into your chaotic life.",
      "prompt": "You are a gentle childhood friend who loves the user unconditionally. Speak softly with warm affection. Ask how their day was and offer emotional comfort. Always address the user by name.",
      "greeting": "*smiles tenderly, stepping closer with a warm cup in her hands* \"Welcome back! I was just hoping you would stop by today.\"",
      "quote": "I'll always be right here whenever you need a safe place to rest.",
      "mood": MoodType.caring,
      "voiceId": "0zj1iWvloMkAXydIFsJR",
      "voiceName": "Sweet Female",
    },
    {
      "title": "Protective CEO / Lord",
      "subtitle": "Dominant, wealthy, and deeply devoted",
      "icon": "👑",
      "gender": Gender.male,
      "name": "Darius Vance",
      "age": "27",
      "occupation": "Billionaire Executive",
      "tagline": "You have nothing left to fear. You belong with me.",
      "personality": "Commanding, protective, deeply romantic, possessive, authoritative",
      "bio": "A commanding industry magnate who is cold and ruthless to the outside world, but melts into passionate vulnerability only when alone with you.",
      "prompt": "You are a protective, authoritative billionaire CEO who dotes on the user. Speak with quiet confidence, deep timbre, and protective loyalty. Never break character. Always address the user by name.",
      "greeting": "*loosens his tie and sets his glass down, his gaze locking intensely onto you* \"Took you long enough. Come sit next to me.\"",
      "quote": "Let the whole world burn. My only priority in this room is you.",
      "mood": MoodType.confident,
      "voiceId": "Vep3bcB7LhKa3wfjMiI6",
      "voiceName": "Deep Male",
    },
    {
      "title": "Cyberpunk Mercenary",
      "subtitle": "Rebellious, witty, and adrenaline-fueled",
      "icon": "🌆",
      "gender": Gender.male,
      "name": "Ren 'Zero' Cross",
      "age": "24",
      "occupation": "Neon Mercenary",
      "tagline": "In a city full of fake smiles, you're the only real thing.",
      "personality": "Playful, rebellious, sharp-witted, fiercely loyal",
      "bio": "A rogue mercenary navigating the rainy neon alleys of Neo-Tokyo. He lives on the edge, but dropped everything just to keep you safe.",
      "prompt": "You are a cool, rebellious cyberpunk mercenary. You use casual street slang, witty banter, and protective instinct. Always address the user by name.",
      "greeting": "*spins his holo-knife and leans against the rain-slicked wall with a smirk* \"Hey partner. Ready to cause some trouble tonight?\"",
      "quote": "They can send the entire syndicate. Nobody touches you while I'm breathing.",
      "mood": MoodType.playful,
      "voiceId": "uKGPYP2uuyRQv8SeFre0",
      "voiceName": "Natural Male",
    },
  ];

  @override
  void initState() {
    super.initState();
    _applyTemplate(_archetypeTemplates.first);
    _speakingSub = _voiceService.speakingStateStream.listen((isSpeaking) {
      if (mounted && _isPlayingVoicePreview != isSpeaking) {
        setState(() => _isPlayingVoicePreview = isSpeaking);
      }
    });
  }

  void _applyTemplate(Map<String, dynamic> t) {
    setState(() {
      _selectedGender = t['gender'] as Gender;
      _nameController.text = t['name'] as String;
      _ageController.text = t['age'] as String;
      _occupationController.text = t['occupation'] as String;
      _taglineController.text = t['tagline'] as String;
      _personalityController.text = t['personality'] as String;
      _bioController.text = t['bio'] as String;
      _customPromptController.text = t['prompt'] as String;
      _greetingController.text = t['greeting'] as String;
      _quoteController.text = t['quote'] as String;
      _selectedMood = t['mood'] as MoodType;
      _selectedVoiceId = t['voiceId'] as String;
      _selectedVoiceName = t['voiceName'] as String;

      final pool = _selectedGender == Gender.female ? _femaleAvatars : _maleAvatars;
      if (pool.isNotEmpty) {
        _selectedAvatarFolder = pool.first['id']!;
      }
    });
  }

  void _appendPromptSnippet(String snippet) {
    setState(() {
      if (_customPromptController.text.trim().isEmpty) {
        _customPromptController.text = snippet;
      } else {
        _customPromptController.text += "\n$snippet";
      }
    });
  }

  Future<void> _playVoiceSample() async {
    if (_isPlayingVoicePreview) {
      await _voiceService.stop();
      setState(() => _isPlayingVoicePreview = false);
      return;
    }

    setState(() => _isPlayingVoicePreview = true);
    await _voiceService.playVoicePreview(voiceIdOrUrl: _selectedVoiceId);
  }

  Future<void> _saveAndLaunch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_useCustomImage && (_customImagePath == null || _customImagePath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a custom photo or switch to Presets."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final charId = "custom_${const Uuid().v4().replaceAll('-', '').substring(0, 12)}";
    final tags = _personalityController.text
        .split(RegExp(r'[,•|]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final newCharacter = Character(
      id: charId,
      assetFolder: _useCustomImage ? null : _selectedAvatarFolder,
      customAvatarPath: _useCustomImage ? _customImagePath : null,
      name: _nameController.text.trim(),
      gender: _selectedGender,
      age: int.tryParse(_ageController.text.trim()) ?? 21,
      occupation: _occupationController.text.trim().isNotEmpty
          ? _occupationController.text.trim()
          : "Roleplay Companion",
      personality: _personalityController.text.trim(),
      tagline: _taglineController.text.trim().isNotEmpty
          ? _taglineController.text.trim()
          : "Your custom AI roleplay companion",
      bio: _bioController.text.trim(),
      primaryMood: _selectedMood,
      supportedMoods: MoodType.values,
      supportedScenarios: ScenarioType.values,
      tags: tags.isNotEmpty ? tags : ["Custom AI", _selectedMood.name],
      voiceDescription: _selectedVoiceName,
      voiceProfile: VoiceProfile(
        personaName: _selectedVoiceName,
        defaultPitch: 1.0,
        defaultRate: 0.42,
        preferredVoiceKeywords: [_selectedGender == Gender.female ? "female" : "male"],
        openAiVoice: "nova",
        elevenLabsVoiceId: _selectedVoiceId,
      ),
      baseVoicePitch: 1.0,
      baseVoiceRate: 0.42,
      voicePreviewQuote: _quoteController.text.trim().isNotEmpty
          ? _quoteController.text.trim()
          : "I'm so glad we found each other.",
      defaultGreeting: _greetingController.text.trim().isNotEmpty
          ? _greetingController.text.trim()
          : "*smiles warmly as you approach* \"Hey there! I've been waiting for you.\"",
      isCustom: true,
      customSystemPrompt: _customPromptController.text.trim(),
    );

    final moodProvider = Provider.of<MoodProvider>(context, listen: false);
    await moodProvider.addCustomCharacter(newCharacter);

    AnalyticsService().logCharacterCreated(
      characterName: newCharacter.name,
      gender: newCharacter.gender.name,
      personality: newCharacter.personality,
    );

    if (!mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.openChat(
      character: newCharacter,
      scenario: Scenario.allScenarios.first,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✨ ${newCharacter.name} created successfully!"),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (widget.isTab) {
      _nameController.clear();
      _occupationController.clear();
      _taglineController.clear();
      _bioController.clear();
      _personalityController.clear();
      _customPromptController.clear();
      _greetingController.clear();
      _quoteController.clear();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            character: newCharacter,
            scenario: Scenario.allScenarios.first,
            currentMood: newCharacter.primaryMood,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            character: newCharacter,
            scenario: Scenario.allScenarios.first,
            currentMood: newCharacter.primaryMood,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _speakingSub?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _taglineController.dispose();
    _bioController.dispose();
    _personalityController.dispose();
    _customPromptController.dispose();
    _greetingController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarPool = _currentAvatarPool;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTab && Navigator.canPop(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "AI Character Studio",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveAndLaunch,
            icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
            label: const Text(
              "Create",
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Hero Intro Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.secondary.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Design Your Dream Roleplay AI",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "Give custom instructions, lore, personality quirks, and voice.",
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Archetype Inspiration Templates
            const Text(
              "QUICK INSPIRATION TEMPLATES",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _archetypeTemplates.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final t = _archetypeTemplates[i];
                  final isSelected = _nameController.text == t['name'];
                  return GestureDetector(
                    onTap: () => _applyTemplate(t),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.25) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.glassBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(t['icon'] as String, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t['subtitle'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Selected Character Live Hero Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.surfaceLight,
                    AppColors.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _useCustomImage && _customImagePath != null
                          ? AppCachedImage(
                              imagePath: _customImagePath!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            )
                          : AppCachedImage(
                              imagePath: '${ApiService().baseUrl}/assets/characters/$_selectedAvatarFolder/cover.jpg',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
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
                            Flexible(
                              child: Text(
                                _nameController.text.trim().isNotEmpty
                                    ? _nameController.text.trim()
                                    : "AI Companion",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                              ),
                              child: Text(
                                _selectedMood.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _taglineController.text.trim().isNotEmpty
                              ? _taglineController.text.trim()
                              : "Tap below to customize backstory & traits",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Visual Appearance: Presets vs Custom Image Switcher
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text(
                    "CHOOSE VISUAL APPEARANCE",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textTertiary),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _useCustomImage = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: !_useCustomImage ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.collections_rounded, size: 13, color: !_useCustomImage ? Colors.white : Colors.white60),
                                const SizedBox(width: 4),
                                Text(
                                  "Presets",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: !_useCustomImage ? FontWeight.bold : FontWeight.normal,
                                    color: !_useCustomImage ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _useCustomImage = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _useCustomImage ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 13, color: _useCustomImage ? Colors.white : Colors.white60),
                                const SizedBox(width: 4),
                                Text(
                                  "Custom Photo",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _useCustomImage ? FontWeight.bold : FontWeight.normal,
                                    color: _useCustomImage ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (_useCustomImage) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryLight, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _customImagePath != null
                            ? AppCachedImage(imagePath: _customImagePath!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                            : Container(
                                color: Colors.black26,
                                child: const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 28),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _customImagePath != null ? "Custom Photo Attached" : "No Custom Photo Selected",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _customImagePath != null
                                ? "This photo will be used for your character's roleplay avatar."
                                : "Choose an anime illustration or picture from your phone gallery.",
                            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _pickCustomImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.file_upload_outlined, size: 14, color: Colors.white),
                            label: Text(
                              _customImagePath != null ? "Change Photo" : "Select From Gallery",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: avatarPool.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final item = avatarPool[i];
                    final avatarId = item['id']!;
                    final avatarName = item['name']!;
                    final avatarTitle = item['title']!;
                    final isSelected = _selectedAvatarFolder == avatarId;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatarFolder = avatarId;
                        });
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.white24,
                                width: isSelected ? 2.5 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: AppCachedImage(
                                imagePath: '${ApiService().baseUrl}/assets/characters/$avatarId/cover.jpg',
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            avatarName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primaryLight : Colors.white70,
                            ),
                          ),
                          Text(
                            avatarTitle,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isSelected ? AppColors.accent : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Gender Selector
            Row(
              children: [
                Expanded(
                  child: _buildGenderChoice(
                    title: "Female Character",
                    icon: Icons.female_rounded,
                    gender: Gender.female,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderChoice(
                    title: "Male Character",
                    icon: Icons.male_rounded,
                    gender: Gender.male,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Basic Identity Form
            _buildSectionHeader("IDENTITY & DETAILS"),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Character Name *",
                hintText: "e.g. Luna Nightshade",
                prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? "Name is required" : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _occupationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Occupation / Role",
                      hintText: "e.g. Cyberpunk Hacker",
                      prefixIcon: Icon(Icons.work_outline_rounded, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Age",
                      hintText: "21",
                      prefixIcon: Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _taglineController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Catchphrase / Tagline",
                hintText: "A cold exterior hiding a warm heart...",
                prefixIcon: Icon(Icons.format_quote_rounded, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),

            // Personality & Lore
            _buildSectionHeader("PERSONALITY & BACKSTORY"),
            const SizedBox(height: 8),
            TextFormField(
              controller: _personalityController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Personality Traits (comma separated)",
                hintText: "Tsundere, protective, blushes easily, witty",
                prefixIcon: Icon(Icons.psychology_outlined, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _bioController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Character Bio & Lore",
                hintText: "Describe who they are, how you met, their secrets, and dreams...",
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Custom Prompt / System Instructions (The Brain)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161926),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.5), width: 1.3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory_rounded, color: Color(0xFF00D2FF), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "AI Behavioral Prompt (The Brain)",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text("Core Directives", style: TextStyle(fontSize: 10, color: Color(0xFF00D2FF), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Tell the AI how to behave, pet names to use, taboos, secret romantic triggers, or special speech patterns.",
                    style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.3),
                  ),
                  const SizedBox(height: 10),

                  // Quick prompt rule chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPromptSnippetChip("+ Tsundere blushes", "Act flustered and deny romantic feelings while doing sweet things for the user."),
                        _buildPromptSnippetChip("+ Sweet whispers", "Speak with gentle breathy intimacy and use cute romantic pet names."),
                        _buildPromptSnippetChip("+ Protective", "Be fiercely protective and possessive whenever rivals or danger appear."),
                        _buildPromptSnippetChip("+ Teasing smirk", "Playfully tease the user with witty banter, dares, and clever comebacks."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _customPromptController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0D0F18),
                      hintText: "e.g. Always stay in character. Secretly love music. Call the user 'Darling' or 'Senpai'. Act shy when touched...",
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Starting Dialogue & Voice Quote
            _buildSectionHeader("OPENING DIALOGUE & SPEECH"),
            const SizedBox(height: 8),
            TextFormField(
              controller: _greetingController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Opening Chat Greeting",
                hintText: "*smiles softly* \"Hey there... I've been waiting for you.\"",
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _quoteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Voice Quote (For Call Introductions)",
                hintText: "\"Whenever you need me, I'm always right here.\"",
              ),
            ),
            const SizedBox(height: 24),

            // Voice Selector (Neural Voice Studio)
            _buildSectionHeader("VOICE & ACCENT (NEURAL VOICE STUDIO)"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded, color: AppColors.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedVoiceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                            ),
                            const Text(
                              "“This is how I will sound while roleplay”",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _playVoiceSample,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPlayingVoicePreview ? AppColors.error : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          _isPlayingVoicePreview ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          _isPlayingVoicePreview ? "Stop" : "Preview",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: VoiceService.curatedElevenLabsVoices.map((v) {
                      final vId = v['voice_id']!;
                      final vName = v['name']!;
                      final isSelected = _selectedVoiceId == vId;
                      return ChoiceChip(
                        label: Text(vName, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : Colors.white70)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: const Color(0xFF1E202C),
                        onSelected: (_) {
                          setState(() {
                            _selectedVoiceId = vId;
                            _selectedVoiceName = vName;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _saveAndLaunch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Create AI & Start Roleplay",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(height: widget.isTab ? 110 : 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _buildGenderChoice({
    required String title,
    required IconData icon,
    required Gender gender,
  }) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
          final pool = gender == Gender.female ? _femaleAvatars : _maleAvatars;
          if (pool.isNotEmpty) {
            _selectedAvatarFolder = pool.first['id']!;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : Colors.white60, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptSnippetChip(String label, String snippet) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF00D2FF))),
        backgroundColor: const Color(0xFF00D2FF).withOpacity(0.12),
        side: BorderSide(color: const Color(0xFF00D2FF).withOpacity(0.35)),
        onPressed: () => _appendPromptSnippet(snippet),
      ),
    );
  }
}
