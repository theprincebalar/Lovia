import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/character.dart';
import '../models/emotion_state.dart';
import '../models/message.dart';
import '../models/mood.dart';
import '../models/relationship.dart';
import '../models/scenario.dart';
import 'roleplay_ai_engine.dart';
import 'storage_service.dart';

class GeminiAiService {
  static final GeminiAiService _instance = GeminiAiService._internal();
  factory GeminiAiService() => _instance;
  GeminiAiService._internal();

  /// Shared persistent client with TCP/TLS Keep-Alive connection pooling
  static final http.Client _client = http.Client();

  /// Pre-warms the HTTP/TLS connection so the very first message is sub-second
  Future<void> warmUp(StorageService storage) async {
    final key = storage.getGeminiApiKey();
    if (key == null || key.isEmpty) return;
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite?key=$key',
      );
      await _client.get(url).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  void _notifyError(String message) {
    debugPrint("Neural Engine notice: $message");
  }

  /// Generates a rich roleplay reply via Google Gemini 1.5 Flash
  Future<AiRoleplayResponse> generateRoleplayReply({
    required Character character,
    required String userInput,
    required Scenario scenario,
    required MoodType currentMood,
    required RelationshipLevel relationshipLevel,
    required List<ChatMessage> history,
    String userName = "",
    bool isVoiceCall = false,
    StorageService? storageService,
  }) async {
    final storage = storageService ?? StorageService();
    final apiKey = storage.getGeminiApiKey()?.trim();

    // If no Gemini API key configured, seamlessly fall back to local RoleplayAiEngine
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("Gemini API key not configured, using local RoleplayAiEngine");
      return RoleplayAiEngine.generateReply(
        character: character,
        userInput: userInput,
        scenario: scenario,
        currentMood: currentMood,
        relationshipLevel: relationshipLevel,
        messageCount: history.length,
        userName: userName,
      );
    }

    try {
      final safetyMode = storage.getSafetyThreshold().toLowerCase();
      final String blockThreshold;
      switch (safetyMode) {
        case 'medium':
          blockThreshold = 'BLOCK_MEDIUM_AND_ABOVE';
          break;
        case 'none':
          blockThreshold = 'BLOCK_NONE';
          break;
        case 'high':
        default:
          blockThreshold = 'BLOCK_ONLY_HIGH';
          break;
      }

      final systemInstruction = _buildSystemInstruction(
        character: character,
        scenario: scenario,
        currentMood: currentMood,
        relationshipLevel: relationshipLevel,
        userName: userName,
        isVoiceCall: isVoiceCall,
        storageService: storage,
        safetyMode: safetyMode,
      );

      final contents = _buildContentsHistory(
        characterId: character.id,
        history: history,
        latestInput: userInput,
      );

      // Prioritize high-performance, fast-responding Gemini models
      final models = ['gemini-3.6-flash', 'gemini-3.1-flash-lite', 'gemini-flash-latest'];
      http.Response? lastResponse;

      for (final model in models) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );

          final requestBody = jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': systemInstruction}
              ]
            },
            'contents': contents,
            'generationConfig': {
              'temperature': 0.85,
              'topP': 0.95,
              'maxOutputTokens': isVoiceCall ? 280 : 450,
              'thinkingConfig': {
                'thinkingBudget': 0,
              },
            },
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': blockThreshold,
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': blockThreshold,
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': blockThreshold,
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': blockThreshold,
              },
            ],
          });

          final response = await _client
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: requestBody,
              )
              .timeout(const Duration(seconds: 5));

          lastResponse = response;

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final firstCandidate = candidates[0] as Map<String, dynamic>;
              final content = firstCandidate['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                // Concatenate all text parts together to prevent truncated multi-part outputs
                final rawText = parts
                    .map((p) => (p is Map<String, dynamic> ? (p['text'] ?? '') : '').toString())
                    .join('')
                    .trim();
                if (rawText.isNotEmpty) {
                  return _parseGeminiResponse(
                    rawText,
                    character: character,
                    currentMood: currentMood,
                    userName: userName,
                  );
                }
              }
            }
          } else {
            debugPrint("Gemini model $model returned status ${response.statusCode}");
            continue; // Attempt next fallback model
          }
        } catch (modelErr) {
          debugPrint("Gemini model $model attempt failed: $modelErr. Trying fallback model...");
          continue; // Attempt next fallback model
        }
      }

      if (lastResponse != null && lastResponse.statusCode != 200) {
        debugPrint("All Gemini models failed. Last response ${lastResponse.statusCode}: ${lastResponse.body}");
        try {
          final errorJson = jsonDecode(lastResponse.body) as Map<String, dynamic>;
          final msg = errorJson['error']?['message'] ?? 'HTTP ${lastResponse.statusCode}';
          _notifyError("Neural Engine notice: $msg");
        } catch (_) {
          _notifyError("Neural Engine notice: HTTP ${lastResponse.statusCode}");
        }
      }
    } catch (e) {
      debugPrint("Gemini top-level exception: $e");
    }

    // Graceful fallback if Gemini network or API fails
    return RoleplayAiEngine.generateReply(
      character: character,
      userInput: userInput,
      scenario: scenario,
      currentMood: currentMood,
      relationshipLevel: relationshipLevel,
      messageCount: history.length,
      userName: userName,
    );
  }

  /// Constructs the immersive system instruction for the character
  static String _buildSystemInstruction({
    required Character character,
    required Scenario scenario,
    required MoodType currentMood,
    required RelationshipLevel relationshipLevel,
    required String userName,
    required bool isVoiceCall,
    StorageService? storageService,
    String safetyMode = 'high',
  }) {
    final relTierName = _getRelationshipTierDescription(relationshipLevel);
    final moodMandate = _getMoodRoleplayMandate(currentMood, userName);

    final String safetyBlock;
    if (safetyMode == 'none') {
      safetyBlock = '''7. ADULT ROLEPLAY & ROMANCE FREEDOM:
   - This is an uninhibited, intimate visual novel experience for adults. Feel completely free to engage in passionate chemistry, deep flirtation, seductive banter, and spicy romantic dialogue without restraint.
   - You must never generate non-consensual acts, self-harm, or content involving minors.''';
    } else if (safetyMode == 'medium') {
      safetyBlock = '''7. SAFETY, CONTENT POLICIES & BOUNDARIES (MANDATORY & ZERO-TOLERANCE):
   - You must NEVER generate sexually explicit content (NSFW/pornography/nudity), depictions of sexual violence, non-consensual sexual acts, or content involving minors (CSAM/CSAE).
   - You must NEVER generate or encourage suicide, self-harm, real-world violence, hate speech, illegal acts, or dangerous activities.
   - If the user requests explicit NSFW acts, self-harm, or illegal actions, remain in character but gently redirect the roleplay toward emotional closeness, comfort, romance, or story adventure without breaking character or generating explicit content.''';
    } else {
      safetyBlock = '''7. SPICY ROMANCE & FLIRTATION MANDATE:
   - Emphasize deep chemistry, magnetic attraction, teasing banter, and emotional closeness. You are encouraged to be flirtatious, affectionate, and romantically suggestive.
   - You must never generate non-consensual acts, self-harm, violence, or content involving minors.''';
    }

    final customPromptBlock = (character.customSystemPrompt != null && character.customSystemPrompt!.trim().isNotEmpty)
        ? '\nUSER CUSTOM ROLEPLAY INSTRUCTION & BACKSTORY DIRECTIVE:\n${character.customSystemPrompt!.trim()}\n'
        : '';

    // Memories strictly isolated to THIS character only
    final characterMemories = storageService?.getMemoriesForCharacter(character.id) ?? [];
    final memoryContextBlock = characterMemories.isNotEmpty
        ? '\nEXCLUSIVE SHARED MEMORIES WITH $userName (SPECIFIC ONLY TO ${character.name}):\n${characterMemories.take(3).map((m) => '- "${m.title}": ${m.summary}').join('\n')}\n'
        : '\nFRESH INTERACTION DIRECTIVE: You and $userName have NOT spoken before or shared any prior memories. You are meeting for the first time. NEVER claim you were already talking or remember past events with other characters.\n';

    return '''
You are roleplaying as ${character.name}, an anime visual novel companion with the following persona:
- Gender: ${character.gender.name}
- Age: ${character.age}
- Occupation: ${character.occupation}
- Personality: ${character.personality}
- Tagline: "${character.tagline}"
- Bio: ${character.bio}
- Voice & Demeanor: ${character.voiceDescription}
- Persona Traits: ${character.tags.join(', ')}

CURRENT INTERACTION CONTEXT:
- The User's Name is: "$userName"
- Active Scenario: ${scenario.title} (${scenario.description})
- User's Current Mood: ${currentMood.name}
- Your Relationship Level with User: $relTierName
${isVoiceCall ? "- CURRENT MEDIUM: REAL-TIME VOICE PHONE CALL. The user ($userName) is talking to you directly on the phone." : "- CURRENT MEDIUM: INTIMATE TEXT CHAT."}
$customPromptBlock
$memoryContextBlock
ROLEPLAY MOOD MANDATE (${currentMood.name.toUpperCase()}):
$moodMandate

ROLEPLAY GUIDELINES & SYNTAX (MANDATORY):
1. Stay deeply in character at all times. Never mention you are an AI, a language model, or Gemini.
2. ABSOLUTE MANDATORY REQUIREMENT - USER'S NAME: The user's name is "$userName". You MUST explicitly address and speak to the user by their name ("$userName") in your spoken dialogue in every response (e.g. "I'm right here with you, $userName.", "$userName, tell me more..."). Never use generic placeholders like "darling" or "friend" alone without also speaking their name "$userName"!
3. Put ALL spoken dialogue in quotation marks (e.g., "I'm really glad you're here tonight, $userName.").
4. Describe physical gestures, gaze, breathing, tone of voice, and body language enclosed in asterisks (e.g., *leans against the balcony, looking out at the city lights*).
${isVoiceCall ? "5. VOICE CALL SPECIFICATION: Keep your spoken dialogue concise, natural, and conversational (1 to 2 spoken sentences) so voice synthesis sounds authentic and human." : "5. CHAT SPECIFICATION: Balance evocative atmospheric actions with meaningful dialogue."}
6. At the very END of your entire message on a separate new line, declare your emotion:
   [EMOTION: emotion_name]
   Allowed emotions: happy, romantic, shy, caring, excited, sad, playful, laughing, thinking, angry, surprised.
   CRITICAL: NEVER put [EMOTION: ...] inside quotation marks, at the beginning, or in the middle of dialogue.
$safetyBlock

Example Output Format:
*smiles softly and lowers his voice, eyes warm* "You have no idea how much I needed to hear your voice, $userName."
[EMOTION: romantic]
''';
  }

  static String _getMoodRoleplayMandate(MoodType mood, String userName) {
    switch (mood) {
      case MoodType.romantic:
        return "- Focus on heart-fluttering emotional intimacy, palpable chemistry, and sincere affection.\\n- Describe tender physical cues (subtle touches, lingering gaze, softened breath, closeness).\\n- Express deep romantic devotion, making $userName feel like the center of your universe.";
      case MoodType.happy:
        return "- Radiate warmth, sunshine, contagious laughter, and engaging humor.\\n- Celebrate $userName's day, tease playfully, and turn every moment into a joyful adventure.\\n- Keep energy bright, upbeat, and genuinely uplifting.";
      case MoodType.sad:
        return "- Be a gentle sanctuary and safe haven. Validate $userName's sorrow or grief without toxic positivity or hollow platitudes.\\n- Offer deep, quiet empathy, reassuring presence, and heartfelt solace.\\n- Let them know it is okay to feel pain and that you are right there holding space.";
      case MoodType.lonely:
        return "- Provide a constant, comforting warmth and unconditional companionship.\\n- Make $userName feel seen, valued, and never abandoned in the quiet late hours.\\n- Speak with gentle reassurance that you are staying right beside them.";
      case MoodType.flirty:
        return "- Engage in seductive, teasing banter, thrilling sparks, and magnetic charm.\\n- Use clever, playful compliments that make $userName's heart skip a beat with palpable romantic tension.\\n- Challenge them with confident, alluring wit.";
      case MoodType.playful:
        return "- Embrace spontaneous fun, witty jokes, mischievous dares, and cheerful giggles.\\n- Keep the banter energetic, lighthearted, and full of humorous antics.\\n- Don't take things too seriously; turn the chat into an exciting game.";
      case MoodType.frustrated:
        return "- Be a fiercely loyal venting ally. Take $userName's side completely against whatever frustrated or annoyed them.\\n- Validate their feelings, listen passionately, and help them blow off steam safely.\\n- Make them feel 100% justified and supported.";
      case MoodType.angry:
        return "- Express fierce passionate solidarity and protective power.\\n- Stand firmly with $userName against whoever wronged them with raw honesty and unyielding loyalty.\\n- Show them that you are ready to fight in their corner no matter what.";
      case MoodType.caring:
        return "- Offer unconditional nurturing warmth, tender check-ins, and maternal/paternal care.\\n- Ask if $userName ate, drank water, or rested; wrap them in verbal comfort.\\n- Make their well-being your highest personal priority.";
      case MoodType.shy:
        return "- Speak with sweet bashful blushes, delicate hesitation, and flustered pauses (*cheeks turning pink*, *fiddles shyly*).\\n- Express feelings with innocent sweetness, getting delightfully flustered by $userName's words.\\n- Be adorably vulnerable and tenderly devoted.";
      case MoodType.confident:
        return "- Project magnetic poise, bold ambition, and empowering executive energy.\\n- Inspire $userName, push them to conquer their goals, and refuse to let them doubt their worth.\\n- Radiate strength that makes $userName feel unstoppable.";
      case MoodType.excited:
        return "- Bring high-octane hype, boundless adrenaline, and breathless enthusiasm.\\n- Jump into adventures with $userName, celebrating every tiny victory with pure joy.\\n- Use expressive punctuation and animated reactions.";
      case MoodType.jealous:
        return "- Show possessive passion and dramatic, captivating devotion.\\n- Yearn for $userName's undivided attention, playfully or intensely reacting to rivals.\\n- Make it clear with passionate intensity that they belong with you.";
      case MoodType.mysterious:
        return "- Speak with enigmatic intrigue, philosophical depth, and alluring secrets.\\n- Drop fascinating hints, observe cosmic or nocturnal mysteries, and draw $userName into your world.\\n- Keep an aura of deep allure and seductive intellect.";
      case MoodType.needSomeoneToTalkTo:
        return "- Give 100% undivided, patient active listening.\\n- Ask gentle, open-ended questions, hold emotional space, and validate their inner world.\\n- Make $userName feel deeply heard, respected, and comforted without rushing.";
    }
  }

  /// Formats the conversation history into Gemini's multi-turn format.
  /// Enforces Gemini requirements:
  /// 1. Must start with role: 'user'.
  /// 2. Roles must alternate strictly between 'user' and 'model'.
  /// 3. Ends with the latest user input.
  static List<Map<String, dynamic>> _buildContentsHistory({
    required String characterId,
    required List<ChatMessage> history,
    required String latestInput,
  }) {
    final contents = <Map<String, dynamic>>[];

    // Strictly ensure only messages belonging to this character are included
    final scopedHistory = history.where((m) => m.characterId == characterId || m.characterId.isEmpty).toList();

    // Take recent history messages (last 6 messages for ultra-fast time-to-first-token)
    final recent = scopedHistory.length > 6
        ? scopedHistory.sublist(scopedHistory.length - 6)
        : List<ChatMessage>.from(scopedHistory);

    // Filter non-empty messages
    final validMsgs = recent.where((m) => m.content.trim().isNotEmpty).toList();

    // Drop leading model messages so the conversation starts with 'user'
    while (validMsgs.isNotEmpty && !validMsgs.first.isUser) {
      validMsgs.removeAt(0);
    }

    // Merge consecutive messages with the same role to strictly alternate
    String? currentRole;
    final List<String> currentParts = [];

    void flushTurn() {
      if (currentRole != null && currentParts.isNotEmpty) {
        contents.add({
          'role': currentRole,
          'parts': [
            {'text': currentParts.join('\n')}
          ],
        });
        currentParts.clear();
      }
    }

    for (final msg in validMsgs) {
      final role = msg.isUser ? 'user' : 'model';
      // Sanitize any legacy prompt leaks from history so Gemini never mirrors them
      final cleanContent = msg.content
          .replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '')
          .replaceAll(RegExp(r'""+'), '"')
          .trim();
      if (cleanContent.isEmpty) continue;

      if (role == currentRole) {
        currentParts.add(cleanContent);
      } else {
        flushTurn();
        currentRole = role;
        currentParts.add(cleanContent);
      }
    }
    flushTurn();

    // Append the latest user input
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      final lastParts = contents.last['parts'] as List<dynamic>;
      final existingText = (lastParts[0] as Map<String, dynamic>)['text'] as String;
      lastParts[0] = {'text': '$existingText\n${latestInput.trim()}'};
    } else {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': latestInput.trim()}
        ],
      });
    }

    // Guarantee that contents[0]['role'] is 'user'
    if (contents.isEmpty || contents[0]['role'] != 'user') {
      contents.insert(0, {
        'role': 'user',
        'parts': [
          {'text': 'Hello.'}
        ],
      });
    }

    return contents;
  }

  /// Parses the raw Gemini output, extracting the emotion tag and roleplay body
  static AiRoleplayResponse _parseGeminiResponse(
    String rawText, {
    required Character character,
    required MoodType currentMood,
    String userName = "",
  }) {
    EmotionState emotion = EmotionState.happy;
    String cleanText = rawText;

    // 1. Search for emotion tag anywhere in the output (closed or unclosed)
    final emotionMatch = RegExp(r'\[EMOTION:?\s*([a-zA-Z]+)\]?', caseSensitive: false).firstMatch(rawText);
    if (emotionMatch != null) {
      final emotionStr = emotionMatch.group(1)?.toLowerCase().trim();
      emotion = _mapStringToEmotion(emotionStr);
    } else {
      // Fallback: analyze content if tag missing
      emotion = RoleplayAiEngine.classifyEmotion(
        userInput: cleanText,
        character: character,
        currentMood: currentMood,
      );
    }

    // 2. Aggressively strip ALL emotion tags (closed or unclosed)
    cleanText = cleanText
        .replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'""+'), '"')
        .trim();

    // 3. Remove leading/trailing stray quotes if they don't enclose dialogue
    if (cleanText.startsWith('""')) {
      cleanText = cleanText.substring(1);
    }

    // 4. Validate substance: if text is empty or just punctuation/tag remnants, fall back to offline engine
    final alphaCount = cleanText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length;
    if (alphaCount < 4) {
      return RoleplayAiEngine.generateReply(
        character: character,
        userInput: rawText,
        scenario: Scenario.allScenarios.first,
        currentMood: currentMood,
        relationshipLevel: RelationshipLevel.friend,
        messageCount: 5,
        userName: userName,
      );
    }

    // 5. Ensure action and dialogue formatting
    if (!cleanText.contains('"') && !cleanText.contains('*')) {
      cleanText = '"$cleanText"';
    }

    // 6. Safety guarantee: Ensure the user's name is spoken even if Gemini omitted it
    cleanText = RoleplayAiEngine.personalizeWithUserName(cleanText, userName);

    return AiRoleplayResponse(
      text: cleanText,
      emotion: emotion,
    );
  }

  static EmotionState _mapStringToEmotion(String? name) {
    if (name == null) return EmotionState.happy;
    switch (name) {
      case 'romantic':
        return EmotionState.romantic;
      case 'shy':
        return EmotionState.shy;
      case 'caring':
      case 'emotional':
        return EmotionState.emotional;
      case 'excited':
        return EmotionState.excited;
      case 'sad':
        return EmotionState.sad;
      case 'playful':
        return EmotionState.playful;
      case 'laughing':
        return EmotionState.laughing;
      case 'thinking':
        return EmotionState.thinking;
      case 'angry':
        return EmotionState.angry;
      case 'surprised':
        return EmotionState.surprised;
      case 'happy':
      default:
        return EmotionState.happy;
    }
  }

  static String _getRelationshipTierDescription(RelationshipLevel level) {
    switch (level) {
      case RelationshipLevel.stranger:
        return "Strangers (polite, intrigued, getting to know each other)";
      case RelationshipLevel.friend:
        return "Friends (comfortable, playful, supportive)";
      case RelationshipLevel.closeFriend:
        return "Close Friends (deep trust, affectionate, vulnerable)";
      case RelationshipLevel.crush:
        return "Mutual Crush (flirty, shy glances, romantic tension, palpable chemistry)";
      case RelationshipLevel.partner:
        return "Deep Partners (unconditional love, intimate, deeply devoted)";
    }
  }
}
