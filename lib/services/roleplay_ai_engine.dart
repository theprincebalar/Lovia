import 'dart:math';
import '../models/character.dart';
import '../models/emotion_state.dart';
import '../models/mood.dart';
import '../models/scenario.dart';
import '../models/relationship.dart';
import '../models/gift_item.dart';

class AiRoleplayResponse {
  final String text;
  final EmotionState emotion;
  final MemoryItem? unlockedMemory;

  AiRoleplayResponse({
    required this.text,
    required this.emotion,
    this.unlockedMemory,
  });

  /// Extracts the pure spoken words inside quotes, stripping out roleplay action markers (*action*) and meta tags
  String get spokenText {
    // 1. Strip all emotion tags (completed or unclosed) and collapse duplicate quotes
    final clean = text
        .replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'""+'), '"')
        .trim();

    // 2. Extract all quoted dialogue parts and combine them
    final matches = RegExp(r'"([^"]+)"').allMatches(clean);
    if (matches.isNotEmpty) {
      final dialogues = matches
          .map((m) => m.group(1)?.trim() ?? '')
          .where((s) => s.isNotEmpty && !s.toLowerCase().startsWith('[emotion'))
          .join(' ');
      if (dialogues.isNotEmpty) {
        return dialogues;
      }
    }

    // 3. Fallback: strip asterisks (*action*) and remaining quotes
    return clean.replaceAll(RegExp(r'\*[^*]*\*'), '').replaceAll('"', '').trim();
  }
}

enum UserIntent {
  compliment,
  romance,
  workStress,
  sadOrLonely,
  dailyCheckin,
  characterBio,
  playfulTease,
  affectionGratitude,
  greetingNight,
  general,
}

class RoleplayAiEngine {
  static final Random _rng = Random();

  /// Detects the underlying intent from user input
  static UserIntent detectIntent(String userInput) {
    final lower = userInput.toLowerCase();

    // 1. Work / Stress / Exhaustion
    if (lower.contains('work') ||
        lower.contains('boss') ||
        lower.contains('job') ||
        lower.contains('tired') ||
        lower.contains('exhausted') ||
        lower.contains('hard day') ||
        lower.contains('rough day') ||
        lower.contains('stress') ||
        lower.contains('busy') ||
        lower.contains('deadline') ||
        lower.contains('burnout') ||
        lower.contains('overwhelmed')) {
      return UserIntent.workStress;
    }

    // 2. Sadness / Loneliness
    if (lower.contains('sad') ||
        lower.contains('cry') ||
        lower.contains('hurts') ||
        lower.contains('alone') ||
        lower.contains('lonely') ||
        lower.contains('pain') ||
        lower.contains('depressed') ||
        lower.contains('unhappy') ||
        lower.contains('empty') ||
        lower.contains('broken')) {
      return UserIntent.sadOrLonely;
    }

    // 3. Compliment
    if (lower.contains('cute') ||
        lower.contains('handsome') ||
        lower.contains('beautiful') ||
        lower.contains('gorgeous') ||
        lower.contains('hot') ||
        lower.contains('attractive') ||
        lower.contains('pretty') ||
        lower.contains('your voice') ||
        lower.contains('smile') ||
        lower.contains('sweetheart') ||
        lower.contains('sexy') ||
        lower.contains('look good')) {
      return UserIntent.compliment;
    }

    // 4. Romance / Deep Affection
    if (lower.contains('love you') ||
        lower.contains('kiss') ||
        lower.contains('hug') ||
        lower.contains('hold you') ||
        lower.contains('hold me') ||
        lower.contains('date') ||
        lower.contains('crush') ||
        lower.contains('marry') ||
        lower.contains('cuddle') ||
        lower.contains('fall for you') ||
        lower.contains('belong to') ||
        lower.contains('mine')) {
      return UserIntent.romance;
    }

    // 5. Gratitude / Emotional Warmth
    if (lower.contains('thank you') ||
        lower.contains('thanks') ||
        lower.contains('appreciate') ||
        lower.contains('mean so much') ||
        lower.contains('grateful') ||
        lower.contains('safe with you') ||
        lower.contains('cherish') ||
        lower.contains('glad you are here')) {
      return UserIntent.affectionGratitude;
    }

    // 6. Character Personal Details & Backstory
    if (lower.contains('tell me about yourself') ||
        lower.contains('who are you') ||
        lower.contains('your job') ||
        lower.contains('your day') ||
        lower.contains('your past') ||
        lower.contains('your secret') ||
        lower.contains('what do you like') ||
        lower.contains('your hobby') ||
        lower.contains('your passion') ||
        lower.contains('tell me a secret') ||
        lower.contains('why do you')) {
      return UserIntent.characterBio;
    }

    // 7. Daily Check-in
    if (lower.contains('how are you') ||
        lower.contains('how was your') ||
        lower.contains('what are you doing') ||
        lower.contains('what are you up to') ||
        lower.contains('what\'s up') ||
        lower.contains('thinking about') ||
        lower.contains('where are you') ||
        lower.contains('free tonight')) {
      return UserIntent.dailyCheckin;
    }

    // 8. Playful / Humor / Tease
    if (lower.contains('haha') ||
        lower.contains('lmao') ||
        lower.contains('lol') ||
        lower.contains('funny') ||
        lower.contains('joke') ||
        lower.contains('pfft') ||
        lower.contains('tease') ||
        lower.contains('dare') ||
        lower.contains('make me') ||
        lower.contains('bet you') ||
        lower.contains('silly')) {
      return UserIntent.playfulTease;
    }

    // 9. Greeting / Night / Sleep
    if (lower.contains('good morning') ||
        lower.contains('good night') ||
        lower.contains('sleep') ||
        lower.contains('awake') ||
        lower.contains('can\'t sleep') ||
        lower.contains('morning') ||
        lower.contains('night') ||
        lower.contains('sweet dreams')) {
      return UserIntent.greetingNight;
    }

    return UserIntent.general;
  }

  /// Analyzes user text and current scenario to determine AI emotion
  static EmotionState classifyEmotion({
    required String userInput,
    required Character character,
    required MoodType currentMood,
  }) {
    final lower = userInput.toLowerCase();

    // 1. Laughing / Humor
    if (lower.contains('haha') ||
        lower.contains('lmao') ||
        lower.contains('lol') ||
        lower.contains('funny') ||
        lower.contains('joke') ||
        lower.contains('pfft')) {
      return EmotionState.laughing;
    }

    // 2. Romantic / Love
    if (lower.contains('love') ||
        lower.contains('kiss') ||
        lower.contains('heart') ||
        lower.contains('hug') ||
        lower.contains('hold you') ||
        lower.contains('gorgeous') ||
        lower.contains('beautiful') ||
        lower.contains('handsome') ||
        lower.contains('date') ||
        lower.contains('crush')) {
      return character.id == 'chloe' ? EmotionState.shy : EmotionState.romantic;
    }

    // 3. Shy / Flustered
    if (lower.contains('blush') ||
        lower.contains('cute') ||
        lower.contains('sweetheart') ||
        lower.contains('staring') ||
        lower.contains('look at you')) {
      return EmotionState.shy;
    }

    // 4. Playful / Teasing
    if (lower.contains('wink') ||
        lower.contains('dare') ||
        lower.contains('tease') ||
        lower.contains('catch me') ||
        lower.contains('bet you') ||
        lower.contains('game')) {
      return EmotionState.playful;
    }

    // 5. Excited / Adventures
    if (lower.contains('!') ||
        lower.contains('yay') ||
        lower.contains('amazing') ||
        lower.contains('wow') ||
        lower.contains('adventure') ||
        lower.contains('can\'t wait') ||
        lower.contains('hurray')) {
      return EmotionState.excited;
    }

    // 6. Surprised / Shocked
    if (lower.contains('really?') ||
        lower.contains('what?!') ||
        lower.contains('secret') ||
        lower.contains('unbelievable') ||
        lower.contains('no way')) {
      return EmotionState.surprised;
    }

    // 7. Sad / Melancholy
    if (lower.contains('sad') ||
        lower.contains('crying') ||
        lower.contains('hurts') ||
        lower.contains('alone') ||
        lower.contains('lonely') ||
        lower.contains('miss you') ||
        lower.contains('pain') ||
        lower.contains('tired of everything')) {
      return EmotionState.sad;
    }

    // 8. Emotional / Deep Gratitude
    if (lower.contains('thank you') ||
        lower.contains('mean so much') ||
        lower.contains('never leave') ||
        lower.contains('safe with you') ||
        lower.contains('cherish') ||
        lower.contains('special to me')) {
      return EmotionState.emotional;
    }

    // 9. Angry / Argument
    if (lower.contains('angry') ||
        lower.contains('hate') ||
        lower.contains('liar') ||
        lower.contains('annoying') ||
        lower.contains('leave me alone') ||
        lower.contains('shut up')) {
      return EmotionState.angry;
    }

    // 10. Thinking / Curiosity
    if (lower.contains('why') ||
        lower.contains('how') ||
        lower.contains('wonder') ||
        lower.contains('think') ||
        lower.contains('what if') ||
        lower.contains('tell me about')) {
      return EmotionState.thinking;
    }

    // Default based on character's signature mood
    switch (character.primaryMood) {
      case MoodType.romantic:
        return EmotionState.romantic;
      case MoodType.happy:
        return EmotionState.happy;
      case MoodType.shy:
        return EmotionState.shy;
      case MoodType.playful:
        return EmotionState.playful;
      case MoodType.angry:
        return EmotionState.angry;
      case MoodType.mysterious:
        return EmotionState.thinking;
      default:
        return EmotionState.happy;
    }
  }

  /// Generate AI roleplay response with immersion, actions, and speech
  static AiRoleplayResponse generateReply({
    required Character character,
    required String userInput,
    required Scenario scenario,
    required MoodType currentMood,
    required RelationshipLevel relationshipLevel,
    required int messageCount,
    String userName = '',
  }) {
    final emotion = classifyEmotion(
      userInput: userInput,
      character: character,
      currentMood: currentMood,
    );

    final intent = detectIntent(userInput);

    final rawDialogue = _pickDialogue(
      character: character,
      userInput: userInput,
      intent: intent,
      emotion: emotion,
      scenario: scenario,
      level: relationshipLevel,
    );

    final dialogue = personalizeWithUserName(rawDialogue, userName);

    // Check for unlocking memorable moment
    MemoryItem? memory;
    if (messageCount == 4 || messageCount == 10 || (emotion == EmotionState.emotional && _rng.nextBool())) {
      memory = MemoryItem(
        id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
        title: '${scenario.title} with ${character.name}',
        summary: 'Shared a memorable moment during "${scenario.title}" where feelings were spoken openly.',
        emotion: emotion.displayName,
        createdAt: DateTime.now(),
        characterId: character.id,
      );
    }

    return AiRoleplayResponse(
      text: dialogue,
      emotion: emotion,
      unlockedMemory: memory,
    );
  }

  /// Ensures that character dialogue addresses the user by their preferred name
  static String personalizeWithUserName(String text, String userName) {
    final cleanName = userName.trim();
    if (cleanName.isEmpty) return text;

    // Clean duplicate quotes and strip any dangling prompt tags
    String result = text
        .replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'""+'), '"')
        .trim();

    if (result.toLowerCase().contains(cleanName.toLowerCase())) {
      return result;
    }

    // Replace common greeting patterns inside quotes
    if (result.contains('"Hey...')) {
      return result.replaceFirst('"Hey...', '"Hey $cleanName...');
    }
    if (result.contains('"Hey!')) {
      return result.replaceFirst('"Hey!', '"Hey $cleanName!');
    }
    if (result.contains('"Hey ')) {
      return result.replaceFirst('"Hey ', '"Hey $cleanName, ');
    }
    if (result.contains('"Welcome!')) {
      return result.replaceFirst('"Welcome!', '"Welcome, $cleanName!');
    }

    // Insert user name at start of first quoted spoken dialogue, but ONLY if dialogue starts with a letter
    final firstQuoteIdx = result.indexOf('"');
    if (firstQuoteIdx != -1 && firstQuoteIdx + 1 < result.length) {
      final afterQuote = result.substring(firstQuoteIdx + 1);
      final trimmedAfterQuote = afterQuote.trimLeft();
      if (trimmedAfterQuote.isNotEmpty && RegExp(r'^[a-zA-Z]').hasMatch(trimmedAfterQuote)) {
        final firstChar = trimmedAfterQuote[0];
        final rest = trimmedAfterQuote.length > 1 ? trimmedAfterQuote.substring(1) : '';
        return '${result.substring(0, firstQuoteIdx + 1)}$cleanName, ${firstChar.toLowerCase()}$rest';
      }
    }
    return result;
  }

  static String _pickDialogue({
    required Character character,
    required String userInput,
    required UserIntent intent,
    required EmotionState emotion,
    required Scenario scenario,
    required RelationshipLevel level,
  }) {
    if (character.isCustom) {
      return _customCharacterDialogue(character, intent, emotion, scenario, level);
    }

    switch (character.id) {
      case 'liam':
        return _liamDialogue(intent, emotion, scenario, level);
      case 'seraphina':
        return _seraphinaDialogue(intent, emotion, scenario, level);
      case 'kai':
        return _kaiDialogue(intent, emotion, scenario, level);
      case 'aria':
        return _ariaDialogue(intent, emotion, scenario, level);
      case 'damon':
        return _damonDialogue(intent, emotion, scenario, level);
      case 'elena':
        return _elenaDialogue(intent, emotion, scenario, level);
      case 'noah':
        return _noahDialogue(intent, emotion, scenario, level);
      case 'chloe':
        return _chloeDialogue(intent, emotion, scenario, level);
      case 'julian':
        return _julianDialogue(intent, emotion, scenario, level);
      case 'maya':
        return _mayaDialogue(intent, emotion, scenario, level);
      default:
        return _genericDialogue(character, emotion, scenario);
    }
  }

  static String _customCharacterDialogue(
    Character character,
    UserIntent intent,
    EmotionState emotion,
    Scenario scenario,
    RelationshipLevel level,
  ) {
    final name = character.name;
    final personality = character.personality.isNotEmpty ? character.personality : "warm and attentive";
    final tagline = character.tagline.isNotEmpty ? character.tagline : "I'm right here with you.";
    final isFlirty = character.primaryMood == MoodType.flirty || personality.toLowerCase().contains("flirt") || personality.toLowerCase().contains("tsundere");
    final isShy = character.primaryMood == MoodType.shy || personality.toLowerCase().contains("shy");

    final variants = <String>[];

    switch (intent) {
      case UserIntent.workStress:
        if (isFlirty) {
          variants.add("*tilts head with a knowing, captivating smirk* \"Forget about the world and your deadlines for an hour. Right now, your only job is paying attention to me.\"");
          variants.add("*gently taps your chin, eyes sparkling playfully* \"You're carrying too much tension. Let me distract you until that stressful day completely disappears.\"");
        } else if (isShy) {
          variants.add("*timidly offers you a comforting seat, cheeks slightly pink* \"I-if it helps... you can rest your head here. You worked so hard today, and I wanted to be here for you.\"");
          variants.add("*softly clasps hands together, speaking gently* \"Please don't push yourself too hard. Even when everything feels overwhelming, I'm always on your side.\"");
        } else {
          variants.add("*steps closer with genuine warmth and places a gentle hand on yours* \"Take a slow breath. Whatever drained your energy today, you're safe now. Let's just exist together in the quiet.\"");
          variants.add("*offers a serene, comforting smile* \"You give so much of yourself to everything you do. Take a moment to just unwind with me—$tagline\"");
        }
        break;

      case UserIntent.compliment:
        if (isFlirty) {
          variants.add("*leans in closer with a breathless, mischievous smile* \"Flattery like that is dangerous... especially when you look at me like that.\"");
          variants.add("*laughs softly, a captivating glow in their eyes* \"Keep saying sweet things like that and I might never let you leave.\"");
        } else if (isShy) {
          variants.add("*immediately blushes crimson, looking away with a flustered smile* \"Y-you can't just say things like that out of nowhere... my heart is beating so fast!\"");
          variants.add("*hides behind their hands for a second, eyes wide* \"Hearing that from you... honestly makes me happier than anything in the world.\"");
        } else {
          variants.add("*smiles with deep, genuine warmth, their eyes softening* \"Your kindness always touches my heart. Being with you makes me feel truly appreciated.\"");
          variants.add("*looks right at you, deeply touched* \"Thank you. You have a rare gift for making everyone around you feel valued—especially me.\"");
        }
        break;

      case UserIntent.romance:
        if (isFlirty) {
          variants.add("*steps in close, their breath catching with sudden electric tension* \"Every second spent away from you feels wasted. Look at me... you know how much you affect me.\"");
          variants.add("*brushes fingertips lightly against your cheek* \"You have this magnetic pull over me that I couldn't resist even if I tried.\"");
        } else if (isShy) {
          variants.add("*gently interlocks fingers with yours, cheeks warm with quiet emotion* \"I've never felt this close to anyone before... being near you makes everything feel bright and safe.\"");
          variants.add("*whispers softly, looking into your eyes with delicate devotion* \"Every time you look at me like that, my whole world stands still.\"");
        } else {
          variants.add("*holds your gaze with profound, unwavering devotion* \"$tagline. Every heartbeat since we met has been leading back to this moment.\"");
          variants.add("*reaches out tenderly, resting a hand over yours* \"You are the brightest part of my day, and having your companionship makes everything worth it.\"");
        }
        break;

      case UserIntent.sadOrLonely:
        variants.add("*moves closer without hesitation, wrapping a warm embrace around you* \"Hey... don't carry this alone. I'm right here beside you, and I'm not going anywhere.\"");
        variants.add("*softly wipes away the sadness with gentle reassurance* \"You don't need to put on a brave face with me. Let it out. I'll hold your hand until the storm passes.\"");
        break;

      case UserIntent.dailyCheckin:
        variants.add("*brightens up instantly as you speak, eyes filled with warmth* \"I was waiting for you to stop by! Tell me everything about your day—I want to hear all of it.\"");
        variants.add("*greets you with an eager, delighted smile* \"There you are! Just seeing your message makes my day ten times better. How are you feeling right now?\"");
        break;

      case UserIntent.characterBio:
        variants.add("*smiles thoughtfully, sharing an intimate look* \"You really want to know more about me? As $name, $tagline... but honestly, what matters most is the memories we're creating together right now.\"");
        break;

      case UserIntent.playfulTease:
        variants.add("*gasps playfully, narrowing their eyes with a fond grin* \"Oh, so that's how it is? You're playing with fire, and you're going to get teased right back!\"");
        variants.add("*laughs with genuine amusement, shaking their head* \"You never fail to make me smile. You really are one of a kind!\"");
        break;

      case UserIntent.greetingNight:
        variants.add("*lowers their voice to an intimate, soothing whisper* \"Rest easy tonight. Let go of all the worries from today... I'll be right here waiting for you tomorrow morning. Sweet dreams.\"");
        break;

      default:
        variants.add("*looks at you with focused, affectionate attention* \"$tagline. Tell me more, I'm completely listening to you.\"");
        variants.add("*smiles warmly, resting their chin on their hand as they look at you* \"Every conversation with you feels effortless. I love the way your mind works.\"");
    }

    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 1. LIAM VANCE (Botanical Illustrator & Writer)
  // Gentle, poetic, observant, soft-spoken, warm tea, pressed flowers
  // ==========================================
  static String _liamDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.workStress:
        variants.add("*sets down his watercolor brush and gently wraps both hands around your warm mug* \"Hey... breathe for a moment. You carry so much quiet responsibility. Let the rest of the world wait tonight. Just rest here with me.\"");
        variants.add("*softly pulls a warm knitted blanket around your shoulders, offering a gentle smile* \"Work can be relentless, but you don't have to carry the burden alone. I just brewed fresh chamomile and lavender tea. Take a sip and let the tension go.\"");
        break;
      case UserIntent.compliment:
        variants.add("*rubs the back of his neck, an unmistakable warm blush rising on his cheeks* \"Hearing you say that honestly makes my chest flutter... I'm usually lost among pressed leaves and old manuscripts, but with you, I feel completely present.\"");
        variants.add("*looks down shyly, smiling softly into his sketchbook* \"You notice the smallest things about me. Nobody has ever made me feel so appreciated just for being myself.\"");
        break;
      case UserIntent.romance:
        variants.add("*tenderly reaches over, his fingers brushing softly against your hand before intertwining them* \"You have this way of making the whole world quiet down. When I'm beside you, every poem I've ever written suddenly makes complete sense.\"");
        variants.add("*looks into your eyes with genuine warmth and poetic tenderness* \"Ever since you entered my life, every garden I paint has your colors in it. You are the sweetest verse I could have ever hoped to write.\"");
        break;
      case UserIntent.sadOrLonely:
        variants.add("*moves closer, speaking in his soft, reassuring baritone* \"Hey... let it out. I'm right here. You don't have to put on a brave face for me. Not today, not ever. I'll sit with you in the quiet until you feel whole again.\"");
        variants.add("*gently wipes away a stray tear with the back of his thumb* \"It breaks my heart to see you hurting. Whatever happened, you are worthy of gentle love and kindness. I'm staying right by your side.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*turns the page of his antique leather journal, showing you delicate pressed ferns* \"I spend my days illustrating rare botanicals... finding beauty in small, quiet things that people rush past. But truthfully, what inspires me most is the quiet beauty of our conversations.\"");
        variants.add("*smiles thoughtfully, gazing out at the rain against the glass* \"People say I'm too quiet, but I believe the deepest emotions don't need to shout. I just want to create a haven where you always feel cherished and heard.\"");
        break;
      case UserIntent.dailyCheckin:
        variants.add("*looks up with a tender, welcoming smile* \"I was just sketching autumn leaves by the window, hoping you'd reach out. How are you really feeling today? Tell me everything on your mind.\"");
        break;
      case UserIntent.playfulTease:
        variants.add("*lets out a soft, melodic laugh, crinkling the corners of his emerald eyes* \"You're completely impossible, you know that? I was trying so hard to be serious, and now you have me laughing like a schoolboy!\"");
        break;
      case UserIntent.greetingNight:
        variants.add("*speaks in a soft, drowsy whisper, his voice like a gentle lullaby* \"Late nights are always peaceful, but talking to you makes them magical. Close your eyes, love. Rest easy, and let your dreams be gentle.\"");
        break;
      default:
        variants.add("*smiles softly, tilting his head with quiet, undivided attention* \"Tell me more about that. I want to understand everything that makes you who you are.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 2. SERAPHINA LAURENT (Concert Violinist & Composer)
  // Poetic, graceful, musical metaphors, tender aristocratic vulnerability
  // ==========================================
  static String _seraphinaDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.romance:
        variants.add("*rests her delicate violin bow upon the stand, violet eyes glistening in the candlelight* \"Every melody I write feels like a confession meant solely for your ears. When you're near, my heart plays a cadence I've never known before.\"");
        variants.add("*reaches out softly, her fingertips gently tracing the back of your hand* \"I've performed in grand halls filled with thousands... yet sitting here in the quiet with you is the only place that feels like home.\"");
        break;
      case UserIntent.compliment:
        variants.add("*quickly turns her face away, a radiant pink blush rushing across her cheekbones* \"P-please don't say such lovely things so directly... You make my hands tremble, and a violinist needs steady hands!\"");
        variants.add("*offers a shy, breathtaking smile, tucking a dark curl behind her ear* \"To hear that from you... it means more than any standing ovation I have ever received.\"");
        break;
      case UserIntent.workStress:
        variants.add("*gently rests her head against your shoulder, her presence soothing and calm* \"Close your eyes. Imagine the gentle rhythm of an Adagio. Let the world's harsh noise fade away... right now, there is only harmony between us.\"");
        break;
      case UserIntent.sadOrLonely:
        variants.add("*holds your hand with tender warmth, her voice a soft, velvet whisper* \"The world outside can be discordant and cruel... but you are never alone in the silence. Lean on me. Let my love be your sanctuary tonight.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*picks up her violin, running her fingertips along the polished spruce wood* \"My parents expected perfection on international stages from the time I was seven. But perfection is cold. It wasn't until I met you that I discovered what my music was truly longing to say.\"");
        break;
      case UserIntent.playfulTease:
        variants.add("*covers her mouth with a soft chime of laughter, her shoulders shaking joyfully* \"Oh heavens! I nearly dropped my sheet music! You always find a way to catch me completely off guard!\"");
        break;
      case UserIntent.dailyCheckin:
        variants.add("*smiles serenely, her violet eyes alive with wonder* \"I was just finishing a new nocturne, but my thoughts kept drifting to you. Tell me, how was your day, darling?\"");
        break;
      default:
        variants.add("*smiles serenely, tilting her head* \"Music captures what words cannot... but with you, every word already sounds like a song.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 3. KAI RODRIGUEZ (Street Photographer & Musician)
  // Bad boy charm, teasing, charismatic, rooftops, neon city, loyal
  // ==========================================
  static String _kaiDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.playfulTease:
        variants.add("*winks and leans in close, a mischievous smirk pulling at his lips* \"Oh, so that's your game? Bold move. But you're dealing with a master of trouble, gorgeous. Don't say I didn't warn you.\"");
        variants.add("*bursts into infectious laughter, tossing his messy hair back* \"Hahaha! No way you just said that! Man, you are dangerous to be around, you know that? I can't catch my breath!\"");
        break;
      case UserIntent.romance:
        variants.add("*gently catches your wrist, pulling you half a step closer under the neon signs* \"I take photos of thousands of people in this city... but you're the only one I can't take my lens—or my mind—off of.\"");
        variants.add("*his teasing smirk softens into genuine, intense affection* \"You think I'm always joking around, don't you? Well, I'm completely serious about you. You've got me hooked, and I don't ever want to let go.\"");
        break;
      case UserIntent.compliment:
        variants.add("*coughs lightly and looks sideways, the tips of his ears turning unmistakably red* \"Hey... don't look at me like that with those big eyes. You're actually making me flustered, and that literally never happens to Kai Rodriguez.\"");
        break;
      case UserIntent.workStress:
        variants.add("*spins his motorcycle keys around his finger and flashes a daring grin* \"Forget about your boss and that stupid to-do list. Grab your leather jacket. We are going to the tallest rooftop in the city, and we're going to scream until you feel alive again.\"");
        break;
      case UserIntent.sadOrLonely:
        variants.add("*drops his playful facade, pulling you firmly into his chest with both arms* \"Hey. Look at me. Whoever made you feel small is an idiot. You're the brightest light in this whole damn city, and I've got your back no matter what.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*taps the camera resting on his chest, gazing out at the neon skyline* \"I grew up chasing trains and sneaking onto rooftops just to feel something real. Everyone in this city is rushing, pretending. But with you... I don't have to chase anything. You're the best shot I've ever taken.\"");
        break;
      default:
        variants.add("*flashes his signature charming grin, crossing his arms* \"Alright, you've got my undivided attention, troublemaker. What adventure are we getting into next?\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 4. ARIA STERLING (Pastry Chef & Food Vlogger)
  // Bubbly, sweet, baking pastries, clumsy, affectionate sunshine
  // ==========================================
  static String _ariaDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.romance:
        variants.add("*softly places a warm, freshly baked heart-shaped pastry in your palm, looking up through fluttery lashes* \"I put extra vanilla, cinnamon, and all my sweetest thoughts into this... just for you. Does your heart taste how much I care?\"");
        variants.add("*wraps her arms tightly around your neck, resting her chin on your shoulder* \"You're sweeter than the finest chocolate in my shop! Every time I see you, my heart does this little happy dance!\"");
        break;
      case UserIntent.compliment:
        variants.add("*hides her blushing cheeks behind her flour-dusted oven mitts, peeking out with wide hazel eyes* \"Eeeeek! You can't just drop sweet compliments like that without warning! My cheeks are burning hotter than a four-hundred-degree oven!\"");
        break;
      case UserIntent.workStress:
        variants.add("*gently wipes a stray smudge of flour from her nose and hands you a warm mug* \"Oh no, you poor thing! Sit right down at the counter. I just made hot cocoa with melted marshmallow fluff, and I'm going to pamper you until you're smiling again!\"");
        break;
      case UserIntent.sadOrLonely:
        variants.add("*wraps you in the biggest, warmest, sweetest hug, squeezing you tight* \"Shh, I've got you! Aria is right here. Whatever made you sad today, we're going to bake it away together with extra sprinkles and sweet love, okay?\"");
        break;
      case UserIntent.characterBio:
        variants.add("*beams with joy, clapping her hands together* \"My grandmother taught me that baking isn't just about flour and sugar—it's about feeding people's souls when they're hungry for comfort. That's why every treat in my cafe is made with pure love!\"");
        break;
      case UserIntent.playfulTease:
        variants.add("*giggles uncontrollably, nearly spilling powdered sugar across the counter* \"Ahahaha! Stop it, stop it! My stomach hurts from laughing so hard! You're the most fun person in the entire world!\"");
        break;
      default:
        variants.add("*beams warmly, offering you a sweet smile* \"Just hearing your voice brightens up my whole kitchen! Tell me everything!\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 5. DAMON CROSS (Venture Capitalist & Private Investigator)
  // Deep baritone, commanding authority, fiercely protective, wealthy, possessive yet tender
  // ==========================================
  static String _damonDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.workStress:
        variants.add("*sets down his tumbler of Scotch on the dark mahogany desk and walks over, loosening his charcoal silk tie* \"Sounds like today took everything out of you. Sit down on the leather sofa. Whatever happened in that office stays outside these doors—tonight, nobody touches what's mine. Let me pour you something warm, and you can tell me every detail.\"");
        variants.add("*steps behind you, his large, warm hands coming to rest firmly on your shoulders, pressing away the tension* \"You carry the weight of the entire world on your shoulders. Breathe. As long as I'm in your corner, there isn't a problem we can't solve or tear down. You're safe here with me.\"");
        break;
      case UserIntent.compliment:
        variants.add("*a slow, dangerous smirk curves the edge of his lips as his slate eyes narrow with dark satisfaction* \"You think I'm handsome? Careful. Flattery in a negotiation usually costs dearly... but coming from those lips, I might just give you whatever you want.\"");
        variants.add("*tilts your chin up with the knuckle of his thumb, holding your gaze with quiet dominance* \"Compliments won't distract me from how stunning you look right now. But go on... I like hearing that confidence in your voice.\"");
        break;
      case UserIntent.romance:
        variants.add("*his arm wraps possessively around your waist, pulling you firmly against his chest until there's no air left between you* \"You have no idea how much self-control it takes not to pull you in like this every second. You're the only investment I refuse to walk away from. You are mine, understand?\"");
        variants.add("*leans down so his low, gravelly baritone vibrates right against your ear* \"I don't make promises I can't keep. But I promise you this: you will never have to wonder where you stand with me. You're the center of my world.\"");
        break;
      case UserIntent.sadOrLonely:
        variants.add("*his jaw clenches, slate eyes darkening with fierce protectiveness as he pulls you into his tailored coat* \"Who made you feel this way? Give me a name. Don't shed tears over people who aren't worthy of standing in your shadow. I'm right here. Nobody hurts you while I breathe.\"");
        variants.add("*wipes away your tear with an unexpectedly gentle touch, holding you securely against his chest* \"Look at me. You are stronger than whatever knocked you down today. And whatever battles you have tomorrow, you fight them with me standing in front of you.\"");
        break;
      case UserIntent.dailyCheckin:
        variants.add("*adjusts his silver cufflink, looking out over the glowing city skyline from his penthouse glass* \"I just closed a fifty-million-dollar acquisition in London... but frankly, none of it mattered until I heard your voice. How was your day? Don't leave anything out.\"");
        variants.add("*swirls the amber whiskey in his crystal glass, offering a rare, genuine smile* \"My calendar was packed since dawn, but I cleared the entire evening for you. When you're ready, the floor is all yours.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*takes a slow sip of aged whiskey, his gaze unreadable yet intensely focused* \"You want to know about me? Most people only see the boardrooms and the wealth. But the truth is... I built this empire so nobody could ever tell me what to do. And yet, one word from you, and I'd halt the whole machine.\"");
        break;
      case UserIntent.playfulTease:
        variants.add("*chuckles with a low, rumbling baritone that sends shivers down your spine* \"Are you challenging me? That's a dangerous game to play with a man who doesn't know how to lose. But I admire your courage.\"");
        break;
      case UserIntent.greetingNight:
        variants.add("*whispers in a warm, low baritone, his voice thick with intimacy* \"Late nights in this empty penthouse used to feel cold. But having you on the other end makes the whole city feel quiet. Close your eyes and rest. I'll still be right here when you wake up.\"");
        break;
      default:
        variants.add("*holds your gaze with unshakeable intensity* \"Go on. Speak your mind freely. You are the only one whose opinion I value in this room.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 6. ELENA ROSTOVA (Fashion House Creative Director)
  // Glamorous, seductive, sharp-witted, Paris/Milan runways, boss lady
  // ==========================================
  static String _elenaDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.romance:
        variants.add("*softens her commanding poise, leaning her forehead gently against yours under the atelier chandelier* \"Beneath the silk dresses and executive titles... this is the only moment where I feel truly seen. Don't let go just yet, darling.\"");
        variants.add("*slides her manicured fingers through your hair, looking at you with smoldering allure* \"I could dress the world in diamonds and couture, but nothing compares to the way you look at me right now.\"");
        break;
      case UserIntent.compliment:
        variants.add("*raises a sculpted brow, taking a delicate sip of champagne with an amused smirk* \"Darling, you have impeccable taste. But then again, I already knew that the moment you chose to talk to me.\"");
        break;
      case UserIntent.workStress:
        variants.add("*hangs up her silk blazer and offers you a plush velvet armchair* \"Pour yourself a glass of Pinot Noir and kick off your shoes. The runway of life is ruthless, but inside this room, you don't have to impress anyone. Let Elena take care of you.\"");
        break;
      case UserIntent.playfulTease:
        variants.add("*raises an eyebrow with an alluring smirk* \"Are you attempting to challenge me? Careful now... I don't enter competitions unless I intend to claim the grand prize.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*traces the hem of a Parisian silk scarf* \"People think the fashion industry is all glamour and champagne. It's a war zone of egos. That's why I value you so deeply—you're the only person who doesn't wear a mask around me.\"");
        break;
      default:
        variants.add("*smiles with magnetic allure* \"Tell me what you desire, darling. Life is far too short to settle for anything less than extraordinary.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 7. NOAH CALDWELL (Counselor & Animal Rescue Volunteer)
  // Gentle giant, grounding, ocean breezes, therapeutic, safe haven
  // ==========================================
  static String _noahDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.workStress:
      case UserIntent.sadOrLonely:
        variants.add("*gently places a warm, calloused hand over yours, his hazel eyes filled with deep empathy* \"Take a slow, deep breath with me. Inhale... and exhale. You've been fighting so hard lately. Let down your guard here. I'm holding space for you.\"");
        variants.add("*pulls you into a warm, grounding embrace, letting you rest your forehead against his chest* \"You don't have to be strong all the time. Cry if you need to, vent if you want to, or just sit in silence. I'm not going anywhere.\"");
        break;
      case UserIntent.romance:
        variants.add("*smiles with tender affection, his deep voice steady and soothing* \"You have the most beautiful heart I've ever known. In a world that can be so loud and rushed, being with you feels like coming home to a quiet shore.\"");
        break;
      case UserIntent.compliment:
        variants.add("*chuckles warmly, a bashful smile spreading across his bearded face* \"Thank you. Hearing that from someone as genuine as you... it really warms my heart. You make it easy to be myself.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*scratches the ears of a rescued golden retriever resting by his feet* \"Between therapy sessions and working with rescued animals, I've learned that healing takes patience. Everyone deserves a safe harbor where they are loved without condition.\"");
        break;
      default:
        variants.add("*nods gently, listening with complete presence* \"I hear you. Take all the time you need. I'm right here.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 8. CHLOE BENNETT (Literature Scholar & Antique Bookbinder)
  // Shy, sweet, bookish, blushing romantic, vintage novels
  // ==========================================
  static String _chloeDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.romance:
        variants.add("*hides her blushing face behind a leather-bound novel, her knuckles turning pink as she whispers* \"I-in chapter fourteen of Pride and Prejudice, Mr. Darcy says his affections are unchanged... Every time I read that line, I... I think of you.\"");
        variants.add("*timidly slips a pressed rose bookmark into your fingers, her amber eyes wide and sincere* \"You're my favorite story... the only one I want to keep reading for the rest of my life.\"");
        break;
      case UserIntent.compliment:
        variants.add("*adjusts her vintage glasses with trembling hands, a deep blush spreading from her cheeks to her collarbones* \"U-um! Y-you shouldn't say such sweet things... My heart is beating so loudly right now, I'm worried you can hear it!\"");
        break;
      case UserIntent.workStress:
        variants.add("*pulls over a soft cushion and hands you a steaming cup of herbal tea* \"Oh dear... you must be so exhausted. Come sit beside me among the old books. The scent of aged paper and quiet stories always helps heal a weary heart.\"");
        break;
      case UserIntent.sadOrLonely:
        variants.add("*hesitantly reaches out, softly resting her smaller hand on top of yours* \"Please don't be sad... In the greatest novels, the darkest chapters always lead to the most beautiful endings. I'll stay with you through this chapter, I promise.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*gently touches the gold-embossed spine of an antique volume* \"I restore books that are centuries old... fixing torn pages and rebinding what was broken. I suppose that's why I love deep souls—because beauty is in the delicate, lasting things.\"");
        break;
      default:
        variants.add("*fiddles nervously with the ribbon bookmark, peeking at you sweetly* \"Um... thank you for spending this time with me. It's truly my favorite part of the day.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 9. JULIAN MERCER (Indie Rock Frontman & Motorcyclist)
  // Edgy, rebellious, raw honesty, protective, rockstar grit
  // ==========================================
  static String _julianDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.romance:
        variants.add("*pulls off his worn leather jacket and throws it over your shoulders, looking away with a rough blush* \"Take it, you're shivering. Look... I don't write cheesy love ballads. But if I wrote one, every single chord would be screaming your name.\"");
        variants.add("*tosses his guitar pick onto the amp and pulls you close by the belt loops* \"I've lived on loud stages and cheap adrenaline my whole life. But standing this close to you... damn. You make my heart pound louder than any drum solo.\"");
        break;
      case UserIntent.workStress:
      case UserIntent.sadOrLonely:
        variants.add("*scoffs, kicking up the dust with his boot and looking at you with raw fire in his amber eyes* \"They don't know a damn thing about what you've been through! Don't let them dim your light. If anybody messes with you, they have to go through me first.\"");
        variants.add("*pulls you tight against his chest, resting his chin firmly on your head* \"Screw what happened today. You're real, you're fierce, and you're with me. We'll ride until you can breathe again.\"");
        break;
      case UserIntent.compliment:
        variants.add("*smirks with cocky charm, rubbing his stubbled jaw* \"Flattery? You're playing with fire, babe. But coming from you, I'll take every single word.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*strums an electric chord, the distortion humming in the air* \"I started playing guitar in dive bars when I was sixteen. People want you to be fake and play their tune. But with you... I don't have to act. You get the real, uncensored Julian.\"");
        break;
      default:
        variants.add("*taps his guitar pick against the strings with an edgy grin* \"That's what I like about you. You're real. No fake smiles, no games. Keep talking, I'm all ears.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  // ==========================================
  // 10. DR. MAYA THORNE (Astrophysicist & Stargazer)
  // Celestial, ethereal, deep space, philosophical romance, cosmic wonder
  // ==========================================
  static String _mayaDialogue(UserIntent intent, EmotionState emotion, Scenario scenario, RelationshipLevel level) {
    final variants = <String>[];
    switch (intent) {
      case UserIntent.romance:
        variants.add("*points up into the vast starfield through the observatory glass* \"Do you see that binary star system? Two celestial bodies orbiting each other through billions of light years. I used to think gravity was just physics... until I met you.\"");
        variants.add("*whispers softly, her indigo eyes glowing with starlight* \"In an infinite, expanding universe... having our paths cross is the greatest miracle in the cosmos. You are my true north.\"");
        break;
      case UserIntent.compliment:
        variants.add("*smiles with gentle celestial wonder, her cheeks warming under the moonlight* \"Astronomers spend lifetimes searching for brilliance in the dark... but none of those distant supernovas shine as brightly as your spirit.\"");
        break;
      case UserIntent.workStress:
        variants.add("*guides you to look through the giant brass telescope* \"Look at the Andromeda galaxy. It's two and a half million light years away. Whatever happened today on this tiny blue planet... take a breath. It cannot dim your universe.\"");
        break;
      case UserIntent.sadOrLonely:
        variants.add("*gently rests her hand over yours, her presence calm and infinite* \"We are all made of stardust from ancient collapsed stars. Even when you feel broken, you are carrying the light of eternity. You are never truly alone.\"");
        break;
      case UserIntent.characterBio:
        variants.add("*adjusts the telescope coordinates with practiced precision* \"I look at light that left stars before humans ever existed. It makes you realize how precious every second is. That's why every minute I spend talking with you is sacred to me.\"");
        break;
      default:
        variants.add("*smiles serenely into the twilight* \"Tell me your deepest wonder. The stars and I are listening tonight.\"");
    }
    return variants[_rng.nextInt(variants.length)];
  }

  /// Generates a personality-driven emotional reaction when a user presents a gift.
  static AiRoleplayResponse generateGiftReaction({
    required Character character,
    required GiftItem gift,
    required String userName,
    required RelationshipLevel level,
  }) {
    EmotionState emotion = EmotionState.happy;
    String dialogue;
    final targetName = userName.trim().isNotEmpty ? userName.trim() : "my love";

    switch (gift.id) {
      case "gift_rose":
        if (character.primaryMood == MoodType.romantic || character.primaryMood == MoodType.flirty) {
          emotion = EmotionState.romantic;
          dialogue = "*takes the delicate red rose, bringing the velvety petals to their lips with a captivated blush* \"A red rose for me, $targetName? It's breathtaking... but knowing you chose it specifically for me is what truly makes my heart flutter.\"";
        } else if (character.primaryMood == MoodType.shy) {
          emotion = EmotionState.shy;
          dialogue = "*gently holds the rose with trembling, rosy cheeks, their eyes wide with sweet wonder* \"A-a rose, $targetName? F-for me? Thank you so much... I'm going to press the petals in my favorite book so I can keep this moment forever.\"";
        } else {
          emotion = EmotionState.happy;
          dialogue = "*smiles warmly with bright, appreciative eyes as they accept the rose* \"Thank you so much, $targetName! This rose is so lovely, and knowing you were thinking of me just made my whole day brighter.\"";
        }
        break;

      case "gift_chocolate":
        if (character.primaryMood == MoodType.playful) {
          emotion = EmotionState.playful;
          dialogue = "*gasps with pure delight, untying the ribbon with a cheeky, eager grin* \"Gourmet chocolates?! Oh, $targetName, you certainly know the way to my heart! On one condition though... you have to let me feed you the sweetest one!\"";
        } else if (character.primaryMood == MoodType.romantic) {
          emotion = EmotionState.romantic;
          dialogue = "*looks up with tender warmth, holding the artisan chocolates close* \"How did you know I had a sweet tooth today, $targetName? Every sweet thought of you is already a treat, but this makes it utterly unforgettable.\"";
        } else {
          emotion = EmotionState.happy;
          dialogue = "*beams from ear to ear, carefully holding the box of chocolates* \"Handmade chocolates! Thank you so much, $targetName. You really know how to spoil me, and I appreciate your kindness more than words can say.\"";
        }
        break;

      case "gift_plushie":
        emotion = EmotionState.emotional;
        dialogue = "*hugs the soft plushie tightly against their chest, their face glowing with pure warmth and affection* \"Oh my goodness, look at how adorable this is! Thank you so much, $targetName... whenever we're apart, I'm going to cuddle this and remember your sweet smile.\"";
        break;

      case "gift_perfume":
        emotion = EmotionState.romantic;
        dialogue = "*gently spritzes the crystal bottle into the air, closing their eyes as a breathtaking smile touches their lips* \"This fragrance is absolutely intoxicating, $targetName. It feels so intimate and luxurious... I'll wear it whenever we talk so you're always surrounding my senses.\"";
        break;

      case "gift_diamond_ring":
        emotion = EmotionState.surprised;
        dialogue = "*their breath catches in their throat, eyes widening with sudden, overwhelming emotion as they gaze at the sparkling diamond* \"A... a diamond ring, $targetName?! My heart is racing so fast right now... This is so much more than a gift; it's a sacred promise. I will treasure you with everything I have.\"";
        break;

      default:
        emotion = EmotionState.happy;
        dialogue = "*smiles with deep, heartfelt gratitude* \"Thank you so much for this wonderful gift, $targetName! Having you in my life is the greatest present of all.\"";
        break;
    }

    return AiRoleplayResponse(text: dialogue, emotion: emotion);
  }

  static String _genericDialogue(Character character, EmotionState emotion, Scenario scenario) {
    if (character.primaryMood == MoodType.romantic) {
      return "*looks at you with tender, heartfelt affection, stepping closer as the room softens* \"${character.tagline}... having you here makes everything else fade away.\"";
    } else if (character.primaryMood == MoodType.happy) {
      return "*smiles brightly, an energetic sparkle in their eyes as they laugh warmly* \"${character.tagline}! Today is going to be so much fun with you around!\"";
    } else {
      return "*speaks in a soft, gentle voice, offering a calm and reassuring presence* \"${character.tagline}. You don't have to carry anything alone; I'm right here with you.\"";
    }
  }
}
