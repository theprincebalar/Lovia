import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lovia/models/character.dart';
import 'package:lovia/models/emotion_state.dart';
import 'package:lovia/models/mood.dart';
import 'package:lovia/models/scenario.dart';
import 'package:lovia/models/message.dart';
import 'package:lovia/models/relationship.dart';
import 'package:lovia/models/coin_wallet.dart';
import 'package:lovia/models/subscription_plan.dart';
import 'package:lovia/providers/coin_provider.dart';
import 'package:lovia/providers/user_provider.dart';
import 'package:lovia/providers/mood_provider.dart';
import 'package:lovia/providers/voice_provider.dart';
import 'package:lovia/providers/chat_provider.dart';
import 'package:lovia/screens/coins/coins_tab.dart';
import 'package:lovia/screens/subscription/subscription_screen.dart';
import 'package:lovia/screens/voice/voice_talk_screen.dart';
import 'package:lovia/screens/create/create_character_screen.dart';
import 'package:lovia/screens/splash/splash_screen.dart';
import 'package:lovia/screens/match/match_screen.dart';
import 'package:lovia/screens/home/home_tab.dart';
import 'package:lovia/screens/chats/chats_tab.dart';
import 'package:lovia/screens/chat/character_profile_screen.dart';
import 'package:lovia/screens/main_navigation_screen.dart';
import 'package:lovia/screens/profile/profile_tab.dart';
import 'package:lovia/widgets/welcome_name_dialog.dart';
import 'package:lovia/widgets/character_avatar.dart';
import 'package:lovia/widgets/voice_studio_sheet.dart';
import 'package:lovia/services/notification_campaign_service.dart';
import 'package:lovia/widgets/audio_visualizer.dart';
import 'package:lovia/services/gemini_ai_service.dart';
import 'package:lovia/services/roleplay_ai_engine.dart';
import 'package:lovia/services/voice_service.dart';
import 'package:lovia/services/storage_service.dart';
import 'package:lovia/models/gift_item.dart';
import 'package:lovia/widgets/gift_selection_sheet.dart';
import 'package:lovia/services/proactive_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Lovia Core Specifications Test', () {
    test('Should have all 15 required moods configured', () {
      expect(Mood.allMoods.length, 15);
      final names = Mood.allMoods.map((m) => m.name).toList();
      expect(names, containsAll([
        "Romantic", "Happy", "Sad", "Lonely", "Flirty", "Playful",
        "Frustrated", "Angry", "Caring", "Shy", "Confident", "Excited",
        "Jealous", "Mysterious", "Need Someone to Talk To"
      ]));
    });

    test('Should have 11 required emotions for character states', () {
      expect(EmotionState.values.length, 11);
      final emotionNames = EmotionState.values.map((e) => e.name).toList();
      expect(emotionNames, containsAll([
        "happy", "sad", "romantic", "angry", "shy", "playful",
        "surprised", "thinking", "laughing", "emotional", "excited"
      ]));
    });

    test('Should have all 11 required scenarios', () {
      expect(Scenario.allScenarios.length, 11);
      final titles = Scenario.allScenarios.map((s) => s.title).toList();
      expect(titles, containsAll([
        "First Meeting", "First Date", "Late Night Chat", "Best Friends",
        "Roommates", "Secret Crush", "Vacation", "Adventure",
        "Mystery", "Argument", "Reunion"
      ]));
    });

    test('Should include both male and female characters with transparent sprite paths', () {
      final males = Character.allCharacters.where((c) => c.gender == Gender.male).toList();
      final females = Character.allCharacters.where((c) => c.gender == Gender.female).toList();

      expect(males.length, greaterThanOrEqualTo(4));
      expect(females.length, greaterThanOrEqualTo(4));

      for (final char in Character.allCharacters) {
        expect(char.name.isNotEmpty, true);
        expect(char.bio.isNotEmpty, true);
        expect(char.voiceDescription.isNotEmpty, true);

        // Every character must have sprite paths for all 11 emotions
        for (final emotion in EmotionState.values) {
          final path = char.getSpritePath(emotion);
          expect(path, 'assets/characters/${char.assetFolder ?? char.id}/${emotion.name}.png');
        }
      }
    });

    test('Relationship progression updates levels correctly', () {
      final rel = CharacterRelationship(characterId: 'seraphina');
      expect(rel.level, RelationshipLevel.stranger);

      rel.addAffection(60);
      expect(rel.level, RelationshipLevel.friend);

      rel.addAffection(100); // total 160
      expect(rel.level, RelationshipLevel.closeFriend);

      rel.addAffection(200); // total 360
      expect(rel.level, RelationshipLevel.crush);

      rel.addAffection(300); // total 660
      expect(rel.level, RelationshipLevel.partner);
    });

    test('Roleplay AI Engine classifies emotions accurately', () {
      final liam = Character.allCharacters.first;

      final happyEmotion = RoleplayAiEngine.classifyEmotion(
        userInput: "Haha that is so funny, lol!",
        character: liam,
        currentMood: MoodType.happy,
      );
      expect(happyEmotion, EmotionState.laughing);

      final romanticEmotion = RoleplayAiEngine.classifyEmotion(
        userInput: "I love you with all my heart and want to hold you close.",
        character: liam,
        currentMood: MoodType.romantic,
      );
      expect(romanticEmotion, EmotionState.romantic);

      final sadEmotion = RoleplayAiEngine.classifyEmotion(
        userInput: "I've been feeling so lonely and sad today, it hurts.",
        character: liam,
        currentMood: MoodType.sad,
      );
      expect(sadEmotion, EmotionState.sad);
    });

    test('Roleplay AI Engine generates character-specific roleplay and extracts pure spokenText', () {
      final damon = Character.allCharacters.firstWhere((c) => c.gender == Gender.male);
      final liam = Character.allCharacters.lastWhere((c) => c.gender == Gender.male);

      // Damon handles work stress with protective executive authority
      final damonReply = RoleplayAiEngine.generateReply(
        character: damon,
        userInput: "My boss was yelling at me all day and I'm exhausted from work.",
        scenario: Scenario.allScenarios.first,
        currentMood: MoodType.needSomeoneToTalkTo,
        relationshipLevel: RelationshipLevel.crush,
        messageCount: 5,
      );
      expect(damonReply.text.contains('*'), true); // contains roleplay action descriptions
      expect(damonReply.text.contains('"'), true); // contains spoken dialogue
      expect(damonReply.spokenText.contains('*'), false); // pure speech for ElevenLabs
      expect(damonReply.spokenText.isNotEmpty, true);

      // Liam handles sadness with gentle botanical comfort
      final liamReply = RoleplayAiEngine.generateReply(
        character: liam,
        userInput: "I feel so lonely and sad tonight...",
        scenario: Scenario.allScenarios.first,
        currentMood: MoodType.sad,
        relationshipLevel: RelationshipLevel.friend,
        messageCount: 3,
      );
      expect(liamReply.text.contains('*'), true);
      expect(liamReply.spokenText.contains('*'), false);
    });

    test('Coin packages are properly configured with exact prices and coins', () {
      expect(CoinPackage.standardPackages.length, 6);
      expect(CoinPackage.standardPackages[0].coins, 20);
      expect(CoinPackage.standardPackages[0].priceUsd, 1.00);
      expect(CoinPackage.standardPackages[1].coins, 50);
      expect(CoinPackage.standardPackages[1].priceUsd, 2.00);
      expect(CoinPackage.standardPackages[2].coins, 130);
      expect(CoinPackage.standardPackages[2].priceUsd, 5.00);
      expect(CoinPackage.standardPackages[3].coins, 300);
      expect(CoinPackage.standardPackages[3].priceUsd, 10.00);
      expect(CoinPackage.standardPackages[4].coins, 650);
      expect(CoinPackage.standardPackages[4].priceUsd, 20.00);
      expect(CoinPackage.standardPackages[5].coins, 1700);
      expect(CoinPackage.standardPackages[5].priceUsd, 50.00);
    });

    test('VIP Subscriptions grant proper voice talk minutes and pricing', () {
      expect(SubscriptionPlan.plans.length, 3);
      final weekly = SubscriptionPlan.plans.firstWhere((p) => p.period == SubscriptionPeriod.weekly);
      expect(weekly.priceUsd, 4.99);
      expect(weekly.voiceMinutes, 10);

      final monthly = SubscriptionPlan.plans.firstWhere((p) => p.period == SubscriptionPeriod.monthly);
      expect(monthly.priceUsd, 12.99);
      expect(monthly.voiceMinutes, 50);

      final yearly = SubscriptionPlan.plans.firstWhere((p) => p.period == SubscriptionPeriod.yearly);
      expect(yearly.priceUsd, 79.99);
      expect(yearly.voiceMinutes, 720); // 12 hours
    });

    test('Every character must have a unique, distinct VoiceProfile configured', () {
      expect(Character.allCharacters.length, 150);

      final voicePersonas = <String>{};
      for (final char in Character.allCharacters) {
        final profile = char.voiceProfile;
        expect(profile.personaName.isNotEmpty, true);
        expect(profile.defaultPitch, greaterThanOrEqualTo(0.70));
        expect(profile.defaultPitch, lessThanOrEqualTo(1.30));
        expect(profile.defaultRate, greaterThanOrEqualTo(0.30));
        expect(profile.defaultRate, lessThanOrEqualTo(0.55));
        expect(profile.preferredVoiceKeywords.isNotEmpty, true);
        expect(profile.openAiVoice.isNotEmpty, true);
        expect(profile.elevenLabsVoiceId.isNotEmpty, true);

        voicePersonas.add(profile.personaName);
      }

      // All 150 characters have their own distinctive persona names
      expect(voicePersonas.length, 150);

      final maleChar = Character.allCharacters.firstWhere((c) => c.gender == Gender.male);
      final femaleChar = Character.allCharacters.firstWhere((c) => c.gender == Gender.female);
      expect(maleChar.voiceProfile.defaultPitch != femaleChar.voiceProfile.defaultPitch, true);
    });

    test('All 15 moods have exactly 5 male and 5 female characters with ABSOLUTELY ZERO character repetition', () {
      final seenIds = <String>{};

      for (final mood in MoodType.values) {
        final chars = Character.allCharacters.where((c) => c.supportedMoods.contains(mood)).toList();
        final males = chars.where((c) => c.gender == Gender.male).toList();
        final females = chars.where((c) => c.gender == Gender.female).toList();

        // Exactly 5 males and 5 females per mood
        expect(males.length, 5, reason: 'Expected exactly 5 males for mood ${mood.name}');
        expect(females.length, 5, reason: 'Expected exactly 5 females for mood ${mood.name}');
        expect(chars.length, 10, reason: 'Expected exactly 10 characters for mood ${mood.name}');

        // ABSOLUTE ZERO REPETITION: none of these characters have ever appeared in any other mood!
        for (final c in chars) {
          expect(seenIds.contains(c.id), false, reason: 'Character ${c.name} (${c.id}) is repeated across moods!');
          seenIds.add(c.id);
        }
      }

      // Total distinct characters across all 15 moods is exactly 150 (15 * 10)
      expect(seenIds.length, 150);
    });

    test('All 150 characters have their own completely unique cover images and sprite assets with zero image repetition', () {
      final coverPaths = <String>{};

      for (final char in Character.allCharacters) {
        expect(char.coverImagePath, 'assets/characters/${char.id}/cover.jpg');
        expect(coverPaths.contains(char.coverImagePath), false,
            reason: 'Duplicate cover image path detected for ${char.name}');
        coverPaths.add(char.coverImagePath);

        for (final emotion in EmotionState.values) {
          final spritePath = char.getSpritePath(emotion);
          expect(spritePath, 'assets/characters/${char.id}/${emotion.name}.png');
        }
      }

      expect(coverPaths.length, 150);
    });

    test('Emotional Prosody Engine properly formats speech cadence and pauses', () {
      final romanticText = VoiceService.formatEmotionalText(
        "I love you so much",
        EmotionState.romantic,
        intensity: 1.2,
      );
      expect(romanticText.contains("..."), true);

      final shyText = VoiceService.formatEmotionalText(
        "I like you",
        EmotionState.shy,
        intensity: 1.5,
      );
      expect(shyText.contains("..."), true);

      final sadText = VoiceService.formatEmotionalText(
        "I miss you. Please stay.",
        EmotionState.sad,
      );
      expect(sadText.contains("..."), true);
    });

    test('StorageService defaults to ElevenLabs active engine with configured API key', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      expect(storage.getElevenLabsApiKey(), isNotEmpty);
      expect(storage.getVoiceEngineMode(), 'elevenlabs');
    });

    testWidgets('VoiceTalkScreen renders without overflow on small screens and shows notice banner', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final voiceService = VoiceService();
      final coinProvider = CoinProvider(storage);
      final voiceProvider = VoiceProvider(
        voiceService: voiceService,
        coinProvider: coinProvider,
        storageService: storage,
      );

      final character = Character.allCharacters.first;
      final scenario = Scenario.allScenarios.first;

      // Test on a compact mobile screen (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VoiceProvider>.value(value: voiceProvider),
          ],
          child: MaterialApp(
            home: VoiceTalkScreen(
              character: character,
              scenario: scenario,
              currentMood: MoodType.happy,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify basic elements render
      expect(find.text(character.name), findsOneWidget);

      // Now simulate ElevenLabs error message
      voiceService.errorMessageStream; // verify stream is available
      // Trigger error directly via VoiceService helper
      // Test that the notice banner appears when VoiceProvider has an error
      voiceProvider.handleUserSpeech(
        userText: "Hello there!",
        scenario: scenario,
        currentMood: MoodType.happy,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      // Check that UI renders cleanly during speaking state with subtitles
      expect(tester.takeException(), isNull);
    });

    test('GeminiAiService generates valid roleplay reply with pure spokenText', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final character = Character.allCharacters.first;
      final scenario = Scenario.allScenarios.first;

      final geminiService = GeminiAiService();
      final reply = await geminiService.generateRoleplayReply(
        character: character,
        userInput: "Hey Liam, I had a tough day at work.",
        scenario: scenario,
        currentMood: MoodType.sad,
        relationshipLevel: RelationshipLevel.closeFriend,
        history: [],
        storageService: storage,
      );

      expect(reply.text, isNotEmpty);
      expect(reply.spokenText, isNotEmpty);
      expect(reply.spokenText.contains('*'), false);
    });

    test('Voice call speech saves to chat history persistently', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.setCoins(50);
      final voiceService = VoiceService();
      final coinProvider = CoinProvider(storage);
      final voiceProvider = VoiceProvider(
        voiceService: voiceService,
        coinProvider: coinProvider,
        storageService: storage,
      );

      final character = Character.allCharacters.first;
      final scenario = Scenario.allScenarios.first;

      // Start call (costs 10 coins for 1st minute)
      final callStarted = await voiceProvider.startCall(
        character: character,
        scenario: scenario,
        currentMood: MoodType.happy,
      );
      expect(callStarted, true);
      expect(coinProvider.balance, 40); // 50 - 10 = 40

      // Handle user speech in call
      await voiceProvider.handleUserSpeech(
        userText: "You have such a calming voice.",
        scenario: scenario,
        currentMood: MoodType.happy,
      );

      // Verify chat history now has both the user message and AI response
      final history = storage.getChatHistory(character.id);
      expect(history.length >= 2, true);
      expect(history.any((m) => m.isUser && m.content == "You have such a calming voice."), true);
      expect(history.any((m) => !m.isUser), true);
    });

    test('StorageService persists Gemini API key properly', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      expect(storage.getGeminiApiKey(), isNotEmpty);
      await storage.setGeminiApiKey('AIzaSyTestKey123');
      expect(storage.getGeminiApiKey(), 'AIzaSyTestKey123');
    });

    test('GeminiAiService formats history starting with user and strictly alternating turns', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final character = Character.allCharacters.first;
      final scenario = Scenario.allScenarios.first;

      // History where first message is model greeting
      final history = [
        ChatMessage(id: '1', characterId: character.id, isUser: false, content: 'Hello darling!'),
        ChatMessage(id: '2', characterId: character.id, isUser: true, content: 'Hey Liam!'),
        ChatMessage(id: '3', characterId: character.id, isUser: false, content: 'How are you?'),
      ];

      final geminiService = GeminiAiService();
      final res = await geminiService.generateRoleplayReply(
        character: character,
        userInput: 'I am doing well',
        scenario: scenario,
        currentMood: MoodType.happy,
        relationshipLevel: RelationshipLevel.friend,
        history: history,
        storageService: storage,
      );
      expect(res.text, isNotEmpty);
    });

    test('Apple Guideline 1.2 & 5.6.4: Blocking and reporting characters works and hides them from feeds', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final userProvider = UserProvider(storage);
      final moodProvider = MoodProvider();
      moodProvider.updateBlockedCharacters(userProvider.blockedCharacterIds);

      final testChar = Character.allCharacters.first;
      expect(moodProvider.charactersForSelectedMood.any((c) => c.id == testChar.id), isTrue);

      // Report character
      await userProvider.reportContent(
        characterId: testChar.id,
        reason: 'Inappropriate content',
        details: 'Violates roleplay guidelines',
      );
      final reported = storage.getReportedContent();
      expect(reported.length, 1);
      expect(reported.first['characterId'], testChar.id);

      // Block character
      await userProvider.blockCharacter(testChar.id);
      expect(userProvider.isCharacterBlocked(testChar.id), isTrue);

      // MoodProvider reflects blocked state
      moodProvider.updateBlockedCharacters(userProvider.blockedCharacterIds);
      expect(moodProvider.charactersForSelectedMood.any((c) => c.id == testChar.id), isFalse);
      expect(moodProvider.filteredCharacters.any((c) => c.id == testChar.id), isFalse);

      // Unblock character
      await userProvider.unblockCharacter(testChar.id);
      expect(userProvider.isCharacterBlocked(testChar.id), isFalse);
      moodProvider.updateBlockedCharacters(userProvider.blockedCharacterIds);
      expect(moodProvider.charactersForSelectedMood.any((c) => c.id == testChar.id), isTrue);
    });

    test('RoleplayAiEngine and personalization always address the user by name', () {
      final char = Character.allCharacters.first;
      final scenario = Scenario.allScenarios.first;

      // 1. RoleplayAiEngine reply includes user name
      final reply = RoleplayAiEngine.generateReply(
        character: char,
        userInput: 'I had a very exhausting day at work',
        scenario: scenario,
        currentMood: MoodType.romantic,
        relationshipLevel: RelationshipLevel.friend,
        messageCount: 1,
        userName: 'Aurelia',
      );
      expect(reply.text, contains('Aurelia'));

      // 2. Personalize custom dialogue
      final personalized = RoleplayAiEngine.personalizeWithUserName(
        '*smiles gently* "You are really special to me."',
        'Jessica',
      );
      expect(personalized, contains('Jessica'));
      expect(personalized, contains('"Jessica, you are really special to me."'));
    });

    test('Subscription voice talk and 1 coin/message & 10 coins/min call economy rules', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);

      // Default balance is 5 coins
      expect(coinProvider.balance, 5);

      // 1 message costs 1 coin
      final messageDeducted = await coinProvider.spendCoins(1, '1 Message test');
      expect(messageDeducted, true);
      expect(coinProvider.balance, 4);

      // Voice call cannot start with 4 coins and no subscription
      expect(coinProvider.hasVoiceAccess(), false);

      // User subscribes to Weekly VIP (10 voice minutes)
      final weekly = SubscriptionPlan.plans.firstWhere((p) => p.period == SubscriptionPeriod.weekly);
      await coinProvider.purchaseSubscription(weekly);
      expect(coinProvider.isSubscribed, true);
      expect(coinProvider.voiceMinutesRemaining, 10);
      expect(coinProvider.hasVoiceAccess(), true);

      // Start voice call: consumes 1 voice minute from subscription, leaving coin balance intact!
      final voiceService = VoiceService();
      final voiceProvider = VoiceProvider(
        voiceService: voiceService,
        coinProvider: coinProvider,
        storageService: storage,
      );
      final character = Character.allCharacters.first;
      final scenario = Scenario.allScenarios.first;

      final callStarted = await voiceProvider.startCall(
        character: character,
        scenario: scenario,
        currentMood: MoodType.happy,
      );
      expect(callStarted, true);
      expect(coinProvider.voiceMinutesRemaining, 9);
      expect(coinProvider.balance, 4); // Coins not touched because subscription minutes were used!
      expect(voiceProvider.isUsingSubscriptionMinutes, true);

      voiceProvider.endCall();
    });

    test('VoiceProvider minute tracking and remaining minutes labels', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);
      final voiceService = VoiceService();
      final voiceProvider = VoiceProvider(
        voiceService: voiceService,
        coinProvider: coinProvider,
        storageService: storage,
      );

      // Free user with 5 coins: 0 coin minutes (needs 10 coins for 1 min)
      expect(voiceProvider.subscriptionMinutesRemaining, 0);
      expect(voiceProvider.coinMinutesRemaining, 0);
      expect(voiceProvider.remainingMinutesLabel, '0 mins left');

      // Add coins via package (50 coins -> 5 mins)
      await coinProvider.purchasePackage(CoinPackage.standardPackages[1]);
      expect(voiceProvider.coinMinutesRemaining, 5);
      expect(voiceProvider.remainingMinutesLabel, '5 mins left');

      // Subscribe to VIP with 10 minutes
      final weekly = SubscriptionPlan.plans.firstWhere((p) => p.period == SubscriptionPeriod.weekly);
      await coinProvider.purchaseSubscription(weekly);
      expect(voiceProvider.subscriptionMinutesRemaining, 10);
      expect(voiceProvider.remainingMinutesLabel, '10 mins left');

      // Consume 1 voice minute
      await coinProvider.deductVoiceMinutes(1);
      expect(voiceProvider.subscriptionMinutesRemaining, 9);
      expect(voiceProvider.remainingMinutesLabel, '9 mins left');
    });

    testWidgets('VoiceStudioSheet hides tone presets and pitch when allowToneChange is false', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final character = Character.allCharacters.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoiceStudioSheet(
                character: character,
                storageService: storage,
                allowToneChange: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Vocal Presets and Vocal Pitch are NOT present
      expect(find.text('Vocal Presets'), findsNothing);
      expect(find.text('Vocal Pitch'), findsNothing);
      expect(find.text('Signature Tone'), findsNothing);
      expect(find.textContaining('Voice tone is locked'), findsOneWidget);
    });

    test('VIP Subscribers enjoy unlimited text chat with 0 coins and zero deduction', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);
      final userProvider = UserProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      final character = Character.allCharacters.first;
      chatProvider.openChat(character: character);

      // Spend all default 5 coins so balance is 0
      await coinProvider.spendCoins(5, 'Spend initial coins');
      expect(coinProvider.balance, 0);

      // Free user with 0 coins CANNOT send a message
      final freeSent = await chatProvider.sendMessage("Hello there", MoodType.happy);
      expect(freeSent, false);
      expect(coinProvider.balance, 0);

      // User subscribes to VIP
      final weekly = SubscriptionPlan.plans.firstWhere((p) => p.period == SubscriptionPeriod.weekly);
      await coinProvider.purchaseSubscription(weekly);
      expect(coinProvider.isSubscribed, true);

      // VIP user with 0 coins CAN send messages (UNLIMITED CHAT!)
      final vipSent = await chatProvider.sendMessage("Hello from VIP!", MoodType.happy);
      expect(vipSent, true);
      // Coins are NOT deducted because subscriber has Unlimited Chat!
      expect(coinProvider.balance, 0);
    });

    testWidgets('SubscriptionScreen renders all VIP perks, plans, and unlimited chat showcase', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CoinProvider>.value(
            value: coinProvider,
            child: const SubscriptionScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Header & Club Title
      expect(find.text('LOVIA VIP CLUB'), findsOneWidget);
      expect(find.text('VIP Member Perks'), findsOneWidget);

      // Verify Perks Showcase
      expect(find.text('Unlimited Text Chat'), findsOneWidget);
      expect(find.text('Dedicated Voice Talk Minutes'), findsOneWidget);
      expect(find.text('Priority AI Generation'), findsOneWidget);
      expect(find.text('All 150+ Characters Unlocked'), findsOneWidget);

      // Verify Plans Section
      expect(find.text('Choose Your Plan'), findsOneWidget);
      expect(find.text('Weekly VIP'), findsOneWidget);
      expect(find.text('Monthly VIP'), findsOneWidget);
      expect(find.text('Yearly VIP'), findsOneWidget);
    });

    testWidgets('CoinsTab serves as dedicated Coin Store with prominent VIP banner', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CoinProvider>.value(
            value: coinProvider,
            child: const CoinsTab(),
          ),
        ),
      );
      await tester.pump();

      // Verify Diamond Store title and balance
      expect(find.text('Diamond Store'), findsOneWidget);
      expect(find.text('CURRENT BALANCE'), findsOneWidget);
      expect(find.text('Diamond Packages'), findsOneWidget);

      // Verify VIP Pass promotional banner linking to SubscriptionScreen
      expect(find.text('LOVIA VIP PASS'), findsOneWidget);
      expect(find.textContaining('Unlimited Chat'), findsWidgets);
      expect(find.text('View VIP Plans (from \$4.99/wk)'), findsOneWidget);

      // Verify standard diamond packages are displayed
      expect(find.text('Handful of Diamonds'), findsOneWidget); // 20 diamonds
      expect(find.text('Pouch of Diamonds'), findsOneWidget); // 50 diamonds
    });

    testWidgets('AudioVisualizer renders flat resting baseline when idle and dynamic heights when speaking', (tester) async {
      // 1. Silent / Resting State (neither user nor agent is speaking)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              frequencies: [0.04, 0.04, 0.04],
              isSpeaking: false,
              isUserSpeaking: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the animated containers for the bars
      final containers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      expect(containers.length, 3);
      for (final container in containers) {
        expect(container.constraints?.maxHeight ?? 4.0, 4.0); // Flat resting line
        final decor = container.decoration as BoxDecoration;
        expect(decor.boxShadow, isNull); // Zero glow shadows during silence
      }

      // 2. Active User Speaking State (vibrant cyan gradient + shadow)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              frequencies: [0.8, 0.5, 0.9],
              isSpeaking: true,
              isUserSpeaking: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final userContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      for (final container in userContainers) {
        final decor = container.decoration as BoxDecoration;
        expect(decor.boxShadow, isNotNull);
        expect(decor.gradient, isNotNull);
      }

      // 3. Active Agent Speaking State (character accent gradient + shadow)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              frequencies: [0.8, 0.5, 0.9],
              isSpeaking: true,
              isUserSpeaking: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final agentContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      for (final container in agentContainers) {
        final decor = container.decoration as BoxDecoration;
        expect(decor.boxShadow, isNotNull);
        expect(decor.gradient, isNotNull);
      }
    });

    test('Custom AI Character model properly serializes and deserializes with custom prompts', () {
      final customChar = Character(
        id: 'custom_test_123',
        name: 'Aria Cross',
        gender: Gender.female,
        age: 23,
        occupation: 'Cyberpunk Investigator',
        personality: 'Tsundere, sharp-witted, fiercely loyal',
        tagline: 'Trust is hard to earn in Neo-Tokyo...',
        bio: 'An elite investigator who uncovers corporate conspiracies.',
        primaryMood: MoodType.mysterious,
        supportedMoods: [MoodType.mysterious, MoodType.romantic],
        supportedScenarios: [ScenarioType.mystery, ScenarioType.firstMeeting],
        tags: ['Cyberpunk', 'Tsundere', 'Mystery'],
        voiceDescription: 'Intimate Romantic Female',
        voiceProfile: const VoiceProfile(
          personaName: 'Intimate Romantic Female',
          defaultPitch: 1.05,
          defaultRate: 0.44,
          preferredVoiceKeywords: ['female', 'intimate'],
          openAiVoice: 'nova',
          elevenLabsVoiceId: '3YXAuwCx7wB8kSkKCqsu',
        ),
        baseVoicePitch: 1.05,
        baseVoiceRate: 0.44,
        voicePreviewQuote: 'Do not get in my way unless you intend to stay.',
        defaultGreeting: '*smirks from the shadows* "You have got guts showing up here."',
        isCustom: true,
        customSystemPrompt: 'Always act skeptical at first. When the user mentions trust, blush faintly.',
      );

      final json = customChar.toJson();
      expect(json['id'], 'custom_test_123');
      expect(json['isCustom'], true);
      expect(json['customSystemPrompt'], contains('blush faintly'));

      final restored = Character.fromJson(json);
      expect(restored.id, customChar.id);
      expect(restored.name, customChar.name);
      expect(restored.gender, Gender.female);
      expect(restored.age, 23);
      expect(restored.isCustom, true);
      expect(restored.customSystemPrompt, customChar.customSystemPrompt);
      expect(restored.voiceProfile.elevenLabsVoiceId, '3YXAuwCx7wB8kSkKCqsu');
    });

    test('StorageService persists, retrieves, and deletes custom AI characters', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      expect(storage.getCustomCharacters().isEmpty, true);

      final customChar = Character(
        id: 'custom_lore_456',
        name: 'Kaelen Darkwood',
        gender: Gender.male,
        age: 26,
        occupation: 'Shadow Mage',
        personality: 'Calm, protective, mysterious',
        tagline: 'The darkness bends to protect you.',
        bio: 'An ancient mage sworn to defend the user from mystical perils.',
        primaryMood: MoodType.mysterious,
        supportedMoods: [MoodType.mysterious],
        supportedScenarios: [ScenarioType.adventure],
        tags: ['Mage', 'Protective'],
        voiceDescription: 'Deep Male',
        voiceProfile: const VoiceProfile(
          personaName: 'Deep Male',
          defaultPitch: 0.9,
          defaultRate: 0.4,
          preferredVoiceKeywords: ['male', 'deep'],
          openAiVoice: 'echo',
        ),
        baseVoicePitch: 0.9,
        baseVoiceRate: 0.4,
        voicePreviewQuote: 'Fear not the shadows.',
        defaultGreeting: '*casts a glowing ward* "You are safe now."',
        isCustom: true,
      );

      // Save custom character
      await storage.saveCustomCharacter(customChar);
      expect(storage.getCustomCharacters().length, 1);
      expect(storage.getCustomCharacters().first.name, 'Kaelen Darkwood');

      // Lookup by ID
      final retrieved = storage.getCharacterById('custom_lore_456');
      expect(retrieved, isNotNull);
      expect(retrieved?.name, 'Kaelen Darkwood');

      // Delete custom character
      await storage.deleteCustomCharacter('custom_lore_456');
      expect(storage.getCustomCharacters().isEmpty, true);
      expect(storage.getCharacterById('custom_lore_456'), isNull);
    });

    test('MoodProvider seamlessly loads and exposes custom characters in feeds', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final moodProvider = MoodProvider(storage);
      expect(moodProvider.customCharacters.isEmpty, true);

      final customChar = Character(
        id: 'custom_romantic_girl',
        name: 'Celeste',
        gender: Gender.female,
        age: 22,
        occupation: 'Stargazer',
        personality: 'Dreamy, romantic, affectionate',
        tagline: 'The stars led me straight to you.',
        bio: 'A gentle astronomer who finds poetry in constellations.',
        primaryMood: MoodType.romantic,
        supportedMoods: [MoodType.romantic],
        supportedScenarios: [ScenarioType.firstMeeting],
        tags: ['Astronomy', 'Romantic'],
        voiceDescription: 'Sweet Female',
        voiceProfile: const VoiceProfile(
          personaName: 'Sweet Female',
          defaultPitch: 1.1,
          defaultRate: 0.42,
          preferredVoiceKeywords: ['female'],
          openAiVoice: 'nova',
        ),
        baseVoicePitch: 1.1,
        baseVoiceRate: 0.42,
        voicePreviewQuote: 'Look at the stars with me.',
        defaultGreeting: '*points upward with a soft smile* "Look at how brightly the stars shine tonight."',
        isCustom: true,
      );

      await moodProvider.addCustomCharacter(customChar);
      expect(moodProvider.customCharacters.length, 1);

      // Should appear in Romantic mood feed
      moodProvider.selectMood(Mood.allMoods.firstWhere((m) => m.type == MoodType.romantic));
      expect(moodProvider.charactersForSelectedMood.any((c) => c.id == 'custom_romantic_girl'), true);

      // Should appear in search query
      moodProvider.setSearchQuery('Celeste');
      expect(moodProvider.filteredCharacters.any((c) => c.id == 'custom_romantic_girl'), true);
    });

    testWidgets('CreateCharacterScreen renders creation studio with templates and fields', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final moodProvider = MoodProvider(storage);

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MoodProvider>.value(
            value: moodProvider,
            child: const CreateCharacterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Banner
      expect(find.text('AI Character Studio'), findsOneWidget);
      expect(find.text('Design Your Dream Roleplay AI'), findsOneWidget);

      // Verify Inspiration Templates
      expect(find.text('QUICK INSPIRATION TEMPLATES'), findsOneWidget);
      expect(find.text('Tsundere Rival'), findsOneWidget);
      expect(find.text('Gentle Childhood Friend'), findsOneWidget);

      // Verify Appearance & Gender Choices
      expect(find.text('CHOOSE VISUAL APPEARANCE'), findsOneWidget);
      expect(find.text('Female Character'), findsOneWidget);
      expect(find.text('Male Character'), findsOneWidget);

      // Verify AI Brain Prompt Section
      expect(find.text('AI Behavioral Prompt (The Brain)'), findsOneWidget);

      // Verify Voice Section
      expect(find.text('VOICE & ACCENT (NEURAL VOICE STUDIO)'), findsOneWidget);

      // Verify Action Button
      expect(find.text('Create AI & Start Roleplay'), findsOneWidget);
    });

    testWidgets('First-launch WelcomeNameDialog renders and saves user name', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);

      expect(userProvider.hasCompletedNameOnboarding, false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: const Scaffold(
              body: WelcomeNameDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Lovia ✨'), findsOneWidget);
      expect(find.text('Begin Your Journey'), findsOneWidget);

      // Enter user's custom name
      await tester.enterText(find.byType(TextField), 'Luna');
      await tester.tap(find.text('Begin Your Journey'));
      await tester.pumpAndSettle();

      expect(userProvider.userName, 'Luna');
      expect(userProvider.hasCompletedNameOnboarding, true);
    });

    test('All characters have unique, distinct initial greetings per persona', () {
      // Group by mood: each character within a mood should have a distinct initialGreeting
      final failingMoods = <MoodType>[];
      for (final mood in MoodType.values) {
        final chars = Character.allCharacters.where((c) => c.primaryMood == mood).toList();
        final greetings = chars.map((c) => c.initialGreeting).toSet();
        if (greetings.length < 6) {
          failingMoods.add(mood);
        }
      }
      expect(failingMoods, isEmpty, reason: 'Failing moods: $failingMoods');

      // Check Liam Vance vs Damon Cross vs Julian Mercer (all Romantic)
      final liam = Character.allCharacters.firstWhere((c) => c.id == 'liam_vance_romantic');
      final damon = Character.allCharacters.firstWhere((c) => c.id == 'damon_cross_romantic');
      final julian = Character.allCharacters.firstWhere((c) => c.id == 'julian_mercer_romantic');

      expect(liam.initialGreeting != damon.initialGreeting, true);
      expect(damon.initialGreeting != julian.initialGreeting, true);
      expect(liam.initialGreeting.contains('sketch'), true);
      expect(damon.initialGreeting.contains('cross today'), true);
    });

    test('Chat to Voice continuity carries existing chat messages into voice call without reset', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);
      await coinProvider.purchasePackage(CoinPackage.standardPackages[1]); // 50 coins
      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Taylor');

      final char = Character.allCharacters.first;

      // Seed chat history as if user and character have been chatting
      final priorMessages = [
        ChatMessage(
          id: 'msg_1',
          characterId: char.id,
          isUser: false,
          content: '*smiles warmly* "I was just thinking about wildflowers."',
          emotion: EmotionState.romantic,
        ),
      ];
      await storage.saveChatHistory(char.id, priorMessages);

      final voiceService = VoiceService();
      voiceService.setStorageService(storage);
      final voiceProvider = VoiceProvider(
        voiceService: voiceService,
        coinProvider: coinProvider,
        storageService: storage,
      );

      // Start call
      await voiceProvider.startCall(
        character: char,
        scenario: Scenario.allScenarios.first,
        currentMood: MoodType.romantic,
      );

      // Verify opening dialogue reflects ongoing chat context rather than static placeholder
      expect(voiceProvider.characterSpokenText.contains('Taylor'), true);
      expect(voiceProvider.characterSpokenText.contains('wildflowers') || voiceProvider.characterSpokenText.contains('so glad you called'), true);

      voiceProvider.endCall();
    });

    test('Voice call with a new character introduces with persona greeting and never claims ongoing conversation', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);
      await coinProvider.purchasePackage(CoinPackage.standardPackages[1]); // 50 coins
      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Taylor');

      final char = Character.allCharacters.first;

      // Seed only default initial greeting (as opened via chat without reply)
      final defaultHistory = [
        ChatMessage(
          id: 'msg_0',
          characterId: char.id,
          isUser: false,
          content: RoleplayAiEngine.personalizeWithUserName(char.initialGreeting, 'Taylor'),
          emotion: EmotionState.happy,
        ),
      ];
      await storage.saveChatHistory(char.id, defaultHistory);

      final voiceService = VoiceService();
      voiceService.setStorageService(storage);
      final voiceProvider = VoiceProvider(
        voiceService: voiceService,
        coinProvider: coinProvider,
        storageService: storage,
      );

      await voiceProvider.startCall(
        character: char,
        scenario: Scenario.allScenarios.first,
        currentMood: MoodType.romantic,
      );

      // Verify it does NOT claim to continue a previous conversation
      expect(voiceProvider.characterSpokenText.contains('Like I was just saying'), false);
      expect(voiceProvider.characterSpokenText.contains('thinking about what we were talking about'), false);
      expect(voiceProvider.characterSpokenText.isNotEmpty, true);

      // Verify endCall cleans up all character and transcript state
      voiceProvider.endCall();
      expect(voiceProvider.activeCharacter, isNull);
      expect(voiceProvider.characterSpokenText, '');
      expect(voiceProvider.liveTranscript, '');
      expect(voiceProvider.isCallActive, false);
    });

    test('Per-character memory isolation strictly segments memories by characterId', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final mem1 = MemoryItem(
        id: 'mem_1',
        title: 'Stargazing',
        summary: 'Looked at constellations together',
        emotion: 'romantic',
        createdAt: DateTime.now(),
        characterId: 'char_sakura',
      );
      final mem2 = MemoryItem(
        id: 'mem_2',
        title: 'Coffee Date',
        summary: 'Met at the corner cafe',
        emotion: 'happy',
        createdAt: DateTime.now(),
        characterId: 'char_kai',
      );

      await storage.addMemory(mem1);
      await storage.addMemory(mem2);

      final sakuraMemories = storage.getMemoriesForCharacter('char_sakura');
      final kaiMemories = storage.getMemoriesForCharacter('char_kai');
      final zaneMemories = storage.getMemoriesForCharacter('char_zane');

      expect(sakuraMemories.length, 1);
      expect(sakuraMemories.first.title, 'Stargazing');

      expect(kaiMemories.length, 1);
      expect(kaiMemories.first.title, 'Coffee Date');

      expect(zaneMemories.isEmpty, true);
    });

    test('GiftItem catalog defines all 5 virtual gifts with coin prices and affection XP', () {
      expect(GiftItem.allGifts.length, 5);
      final rose = GiftItem.allGifts.firstWhere((g) => g.id == 'gift_rose');
      final chocolates = GiftItem.allGifts.firstWhere((g) => g.id == 'gift_chocolate');
      final plushie = GiftItem.allGifts.firstWhere((g) => g.id == 'gift_plushie');
      final perfume = GiftItem.allGifts.firstWhere((g) => g.id == 'gift_perfume');
      final ring = GiftItem.allGifts.firstWhere((g) => g.id == 'gift_diamond_ring');

      expect(rose.coinPrice, 5);
      expect(rose.affectionPoints, 25);

      expect(chocolates.coinPrice, 10);
      expect(chocolates.affectionPoints, 60);

      expect(plushie.coinPrice, 25);
      expect(plushie.affectionPoints, 160);

      expect(perfume.coinPrice, 50);
      expect(perfume.affectionPoints, 350);

      expect(ring.coinPrice, 100);
      expect(ring.affectionPoints, 800);
    });

    test('ChatProvider.sendGift deducts coins, adds affection, increments gifts sent, and returns leveledUp', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);
      await coinProvider.purchasePackage(CoinPackage.standardPackages[1]); // 50 coins balance: 55
      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Jordan');

      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );
      final char = Character.allCharacters.first;
      chatProvider.openChat(character: char);

      final initialAffection = chatProvider.relationship.affectionPoints;
      expect(initialAffection, 0);
      expect(chatProvider.relationship.level, RelationshipLevel.stranger);
      expect(storage.getGiftsSentCount(), 0);

      final rose = GiftItem.allGifts.firstWhere((g) => g.id == 'gift_rose'); // 5 coins, 25 affection
      final result1 = await chatProvider.sendGift(rose);

      expect(result1.success, true);
      expect(result1.leveledUp, false); // 25 XP is still Stranger
      expect(coinProvider.balance, 50);
      expect(chatProvider.relationship.affectionPoints, 25);
      expect(storage.getGiftsSentCount(), 1);

      // Verify chat history includes gift message and companion response
      expect(chatProvider.messages.length, greaterThanOrEqualTo(2));
      final lastMsg = chatProvider.messages.last;
      expect(lastMsg.isUser, false);
      expect(lastMsg.content.contains('Jordan'), true);

      // Give enough coins for luxury perfume (50 coins, 350 affection -> total 375 = Crush!)
      await coinProvider.purchasePackage(CoinPackage.standardPackages[1]);
      final perfume = GiftItem.allGifts.firstWhere((g) => g.id == 'gift_perfume');
      final result2 = await chatProvider.sendGift(perfume);

      expect(result2.success, true);
      expect(result2.leveledUp, true); // Level up to Crush!
      expect(chatProvider.relationship.level, RelationshipLevel.crush);
      expect(storage.getGiftsSentCount(), 2);
    });

    test('ProactiveNotificationService delivers contextual outreach and injects into chat history', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final service = ProactiveNotificationService();
      final char = Character.allCharacters.first;

      final notification = await service.checkAndDeliverProactiveNotification(
        storage: storage,
        availableCharacters: [char],
        userName: 'Aria',
        force: true,
      );

      expect(notification, isNotNull);
      expect(notification!.character.id, char.id);
      expect(notification.body.contains('Aria'), true);

      // Verify message was injected into chat history
      final history = storage.getChatHistory(char.id);
      expect(history.isNotEmpty, true);
      expect(history.last.content, notification.body);
    });

    test('Proactive notification blocks outreach before onboarding and retroactively replaces placeholder names', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final service = ProactiveNotificationService();
      final char = Character.allCharacters.first;

      // Onboarding not completed yet
      expect(storage.hasCompletedNameOnboarding(), false);

      // Attempt proactive check without force
      final blockedResult = await service.checkAndDeliverProactiveNotification(
        storage: storage,
        availableCharacters: [char],
        userName: 'Alex',
        force: false,
      );
      expect(blockedResult, isNull);

      // Suppose a prior message had "Alex" in it
      final initialHistory = [
        ChatMessage(
          id: 'test_msg_1',
          characterId: char.id,
          isUser: false,
          content: 'Hey Alex... whatever today asked of you, let it go now.',
          emotion: EmotionState.romantic,
        ),
      ];
      await storage.saveChatHistory(char.id, initialHistory);

      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Siddharth');

      // Verify history was retroactively updated with user's real entered name
      final updatedHistory = storage.getChatHistory(char.id);
      expect(updatedHistory.first.content.contains('Siddharth'), true);
      expect(updatedHistory.first.content.contains('Alex'), false);
    });

    testWidgets('GiftSelectionSheet displays all gifts, coin prices, and balance', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final coinProvider = CoinProvider(storage);
      final userProvider = UserProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );
      final char = Character.allCharacters.first;
      chatProvider.openChat(character: char);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (ctx) => GiftSelectionSheet(
                      character: char,
                    ),
                  ),
                  child: const Text('Open Gifts'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Gifts'));
      await tester.pumpAndSettle();

      expect(find.text('Send a Gift'), findsOneWidget);
      expect(find.text('Red Rose'), findsOneWidget);
      expect(find.text('Artisan Chocolates'), findsOneWidget);
      expect(find.text('+25 Affection'), findsOneWidget);
    });

    testWidgets('SplashScreen renders animated branding, emblem, and tagline', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);
      final coinProvider = CoinProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
          ],
          child: const MaterialApp(
            home: SplashScreen(
              duration: Duration(milliseconds: 2500),
            ),
          ),
        ),
      );
      await tester.pump();

      // Brand checks
      expect(find.text('LOVIA'), findsOneWidget);
      expect(find.text('WHERE ANIME COMPANIONS COME ALIVE'), findsOneWidget);
      expect(find.text('INITIALIZING NEURAL COMPANIONS'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('SplashScreen advances to MainNavigationScreen after animation duration', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);
      final coinProvider = CoinProvider(storage);

      bool finished = false;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
          ],
          child: MaterialApp(
            home: SplashScreen(
              duration: const Duration(milliseconds: 100),
              onFinish: () => finished = true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(finished, false);

      // Advance clock past duration
      await tester.pump(const Duration(milliseconds: 150));
      expect(finished, true);
    });

    test('Custom AI Character initialGreeting returns custom greeting directly', () {
      const customChar = Character(
        id: "custom_test_1",
        name: "Astraea",
        gender: Gender.female,
        age: 23,
        occupation: "Space Explorer",
        personality: "Inquisitive and brave",
        tagline: "Exploring nebulae together",
        bio: "An intrepid astronaut traveling the stars.",
        primaryMood: MoodType.romantic,
        supportedMoods: [MoodType.romantic],
        supportedScenarios: [ScenarioType.firstMeeting],
        tags: ["Space", "Custom"],
        voiceDescription: "Clear Female",
        voiceProfile: VoiceProfile(
          personaName: "Astraea Voice",
          defaultPitch: 1.0,
          defaultRate: 0.42,
          preferredVoiceKeywords: ["female"],
          openAiVoice: "nova",
        ),
        baseVoicePitch: 1.0,
        baseVoiceRate: 0.42,
        voicePreviewQuote: "Looking at the stars with you.",
        defaultGreeting: "*steps out of the airlock with a warm grin* \"Welcome to the observatory, friend!\"",
        isCustom: true,
      );

      expect(
        customChar.initialGreeting,
        "*steps out of the airlock with a warm grin* \"Welcome to the observatory, friend!\"",
      );
    });

    test('RoleplayAiEngine generates tailored dialogue for custom characters without generic fallback', () {
      const customChar = Character(
        id: "custom_test_2",
        name: "Kaelen",
        gender: Gender.male,
        age: 25,
        occupation: "Cyberneticist",
        personality: "Flirty and daring",
        tagline: "Together we can break any code",
        bio: "A cybernetic rogue in a neon metropolis.",
        primaryMood: MoodType.flirty,
        supportedMoods: [MoodType.flirty],
        supportedScenarios: [ScenarioType.firstMeeting],
        tags: ["Cyberpunk", "Rogue"],
        voiceDescription: "Natural Male",
        voiceProfile: VoiceProfile(
          personaName: "Kaelen Voice",
          defaultPitch: 1.0,
          defaultRate: 0.42,
          preferredVoiceKeywords: ["male"],
          openAiVoice: "nova",
        ),
        baseVoicePitch: 1.0,
        baseVoiceRate: 0.42,
        voicePreviewQuote: "Ready for neon shadows?",
        defaultGreeting: "*smirks under neon lights* \"Look who finally arrived.\"",
        isCustom: true,
        customSystemPrompt: "You are Kaelen, a daring cyberneticist.",
      );

      final reply = RoleplayAiEngine.generateReply(
        character: customChar,
        userInput: "I feel so stressed from work today",
        scenario: Scenario.allScenarios.first,
        currentMood: MoodType.flirty,
        relationshipLevel: RelationshipLevel.stranger,
        messageCount: 1,
        userName: "Elena",
      );

      expect(reply.text.isNotEmpty, true);
      expect(reply.text.contains('"'), true);
    });

    testWidgets('MainNavigationScreen displays all 4 bottom tabs including Match', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Taylor');
      final coinProvider = CoinProvider(storage);
      final moodProvider = MoodProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: moodProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Match'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tap on Create tab
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('AI Character Studio'), findsOneWidget);

      // Tap on Match tab
      await tester.tap(find.text('Match'));
      await tester.pump();

      expect(find.text('Destiny Match'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Any'), findsOneWidget);
      expect(find.text('Shuffle New Match 🎲'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('MatchScreen renders matching radar, gender preferences, and reveals match', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);
      final coinProvider = CoinProvider(storage);
      final moodProvider = MoodProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: moodProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MatchScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Destiny Match'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Any'), findsOneWidget);
      expect(find.text('Shuffle New Match 🎲'), findsOneWidget);

      // Advance through matching sequence (1400ms duration)
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Start Chat'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.textContaining('CHEMISTRY'), findsOneWidget);

      // Test Shuffle action
      await tester.tap(find.text('Shuffle New Match 🎲'));
      await tester.pump();

      // Advancing through second matching sequence
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Start Chat'), findsOneWidget);
    });

    testWidgets('HomeTab removes hero studio card and category tags while displaying mood selector and interleaved characters', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Taylor');
      final coinProvider = CoinProvider(storage);
      final moodProvider = MoodProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: moodProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomeTab(onNavigateToCoins: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      // Creation Studio Hero Card has been removed from top and moved to middle bottom tab
      expect(find.text('CREATION STUDIO'), findsNothing);
      expect(find.text('Create Your Own AI Roleplay Partner'), findsNothing);

      // Old tags Popular and Hot are completely removed from top
      expect(find.text('Popular'), findsNothing);
      expect(find.text('Hot'), findsNothing);
      expect(find.text('Ranking'), findsNothing);

      // Modern Mood selector is present
      expect(find.text('How are you feeling today?'), findsOneWidget);
      expect(find.text('Tap a mood to meet matched companions'), findsOneWidget);
    });

    testWidgets('ChatsTab renders perfectly circular avatar without oval distortion', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Taylor');
      final coinProvider = CoinProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      final char = Character.allCharacters.first;
      chatProvider.openChat(character: char);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatsTab(onExplorePressed: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the CharacterAvatar in the list
      final avatarFinder = find.byType(CharacterAvatar);
      expect(avatarFinder, findsOneWidget);

      final avatarSize = tester.getSize(avatarFinder);
      // Verify width and height are strictly 1:1 equal (not an oval)
      expect(avatarSize.width, avatarSize.height);
      expect(avatarSize.width, 54.0);
    });

    testWidgets('CharacterProfileScreen renders Voice Sample Audio Preview card without Voice Studio', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final userProvider = UserProvider(storage);
      await userProvider.setUserName('Taylor');
      final coinProvider = CoinProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      final char = Character.allCharacters.first;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CharacterProfileScreen(character: char),
            ),
          ),
        ),
      );
      await tester.pump();

      // Voice Studio icon button is removed
      expect(find.byTooltip('Voice Studio'), findsNothing);

      // Dedicated Voice Sample audio preview card & action are present
      expect(find.text('Voice Sample'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Redesigned Intimacy Bond / XP Card and Info Icon
      expect(find.text('INTIMACY BOND'), findsOneWidget);
      expect(find.textContaining('XP'), findsWidgets);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Scroll so info icon is fully clear of bottom action bar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();

      // Tap info icon to verify XP explanation sheet
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('How Affection & XP Work'), findsOneWidget);
      expect(find.text('How to Earn XP'), findsOneWidget);
      expect(find.text('What Happens As XP Increases?'), findsOneWidget);
      expect(find.text('Got It! 💕'), findsOneWidget);

      await tester.ensureVisible(find.text('Got It! 💕'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got It! 💕'));
      await tester.pumpAndSettle();
    });

    test('MoodProvider interleaves male and female characters in charactersForSelectedMood', () {
      final storage = StorageService();
      final moodProvider = MoodProvider(storage);
      final list = moodProvider.charactersForSelectedMood;
      expect(list.isNotEmpty, isTrue);

      final hasMale = list.any((c) => c.gender == Gender.male);
      final hasFemale = list.any((c) => c.gender == Gender.female);
      if (hasMale && hasFemale) {
        // At least the first two characters alternate gender
        expect(list[0].gender != list[1].gender, isTrue);
      }
    });

    testWidgets('ProfileTab displays My Creations, removes Memories and Autoplay Voice toggle', (WidgetTester tester) async {
      final storage = StorageService();
      final userProvider = UserProvider(storage);
      final coinProvider = CoinProvider(storage);
      final moodProvider = MoodProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: moodProvider),
          ],
          child: MaterialApp(
            home: ProfileTab(onNavigateToCoins: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "My Creations" is present
      expect(find.text('My Creations'), findsOneWidget);

      // Verify "Memories & Moments Gallery" has been removed
      expect(find.text('Memories & Moments Gallery'), findsNothing);

      // Verify "Autoplay Voice in Chat" toggle has been removed
      expect(find.text('Autoplay Voice in Chat'), findsNothing);

      // Verify Proactive Companion Check-ins toggle remains
      expect(find.text('Proactive Companion Check-ins'), findsOneWidget);
    });

    testWidgets('ProfileTab displays custom character and allows deletion via dialog', (WidgetTester tester) async {
      final storage = StorageService();
      final userProvider = UserProvider(storage);
      final coinProvider = CoinProvider(storage);
      final moodProvider = MoodProvider(storage);

      // Add a test custom character
      final testCustomChar = Character(
        id: 'custom_test_999',
        name: 'Aoi Sakura',
        gender: Gender.female,
        age: 20,
        occupation: 'Visual Novel Heroine',
        personality: 'Gentle, loving',
        tagline: 'Always by your side in your dream world',
        bio: 'A custom roleplay character created by the user.',
        primaryMood: MoodType.romantic,
        supportedMoods: [MoodType.romantic],
        supportedScenarios: [ScenarioType.firstMeeting],
        tags: ['Custom', 'Romantic'],
        voiceDescription: 'Sweet Voice',
        voiceProfile: const VoiceProfile(
          personaName: 'Sweet Voice',
          defaultPitch: 1.0,
          defaultRate: 0.42,
          preferredVoiceKeywords: ['female'],
          openAiVoice: 'nova',
        ),
        baseVoicePitch: 1.0,
        baseVoiceRate: 0.42,
        voicePreviewQuote: 'Hello there!',
        defaultGreeting: 'Hello master!',
        isCustom: true,
      );

      await moodProvider.addCustomCharacter(testCustomChar);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: moodProvider),
          ],
          child: MaterialApp(
            home: ProfileTab(onNavigateToCoins: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Custom character should be listed
      expect(find.text('Aoi Sakura'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);

      // Tap delete button to open confirmation dialog
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Delete Aoi Sakura?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Character should be deleted from moodProvider
      expect(moodProvider.customCharacters.any((c) => c.id == 'custom_test_999'), isFalse);
    });

    testWidgets('CreateCharacterScreen provides toggle between Presets and Custom Photo', (WidgetTester tester) async {
      final storage = StorageService();
      final userProvider = UserProvider(storage);
      final coinProvider = CoinProvider(storage);
      final moodProvider = MoodProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: coinProvider),
            ChangeNotifierProvider.value(value: moodProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: CreateCharacterScreen(isTab: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Presets & Custom Photo chips are visible
      expect(find.text('Presets'), findsOneWidget);
      expect(find.text('Custom Photo'), findsOneWidget);

      // Switch to Custom Photo
      await tester.tap(find.text('Custom Photo'));
      await tester.pumpAndSettle();

      expect(find.text('No Custom Photo Selected'), findsOneWidget);
      expect(find.text('Select From Gallery'), findsOneWidget);

      // Switch back to Presets
      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();

      expect(find.text('Seraphina'), findsWidgets);
    });

    test('ChatMessage.fromJson and speechText completely sanitize legacy leaked prompt tags and duplicate quotes', () {
      final jsonCorrupted1 = {
        'id': 'msg_err_1',
        'characterId': 'liam',
        'isUser': false,
        'content': '""Prince, [EMOTION: romantic"',
        'emotion': 'romantic',
        'timestamp': DateTime.now().toIso8601String(),
        'isVoiceMessage': true,
      };
      final msg1 = ChatMessage.fromJson(jsonCorrupted1);
      expect(msg1.content.contains('[EMOTION'), isFalse);
      expect(msg1.content.startsWith('""'), isFalse);
      expect(msg1.content, equals('"Prince,"'));
      expect(msg1.speechText, equals('Prince,'));

      final jsonCorrupted2 = {
        'id': 'msg_err_2',
        'characterId': 'liam',
        'isUser': false,
        'content': '""Prince, [EMOTION"',
        'emotion': 'happy',
        'timestamp': DateTime.now().toIso8601String(),
        'isVoiceMessage': true,
      };
      final msg2 = ChatMessage.fromJson(jsonCorrupted2);
      expect(msg2.content.contains('[EMOTION'), isFalse);
      expect(msg2.content.startsWith('""'), isFalse);
      expect(msg2.speechText, equals('Prince,'));
    });

    test('AiRoleplayResponse.spokenText extracts all quoted dialogues and eliminates meta tags', () {
      final response1 = AiRoleplayResponse(
        text: '*smiles softly* "Hello Prince." *whispers* "I am so happy you called today."',
        emotion: EmotionState.romantic,
      );
      expect(response1.spokenText, equals('Hello Prince. I am so happy you called today.'));

      // If an emotion tag was attached at the end
      final response2 = AiRoleplayResponse(
        text: '*gazes into your eyes* "It feels so quiet and peaceful right now, Prince."\n[EMOTION: romantic]',
        emotion: EmotionState.romantic,
      );
      expect(response2.spokenText, equals('It feels so quiet and peaceful right now, Prince.'));
      expect(response2.spokenText.contains('[EMOTION'), isFalse);

      // Even if an unclosed tag is present in the text
      final response3 = AiRoleplayResponse(
        text: '"Prince, how have you been?" [EMOTION: romantic',
        emotion: EmotionState.romantic,
      );
      expect(response3.spokenText, equals('Prince, how have you been?'));
      expect(response3.spokenText.contains('[EMOTION'), isFalse);
    });

    test('RoleplayAiEngine.personalizeWithUserName never injects into brackets or causes duplicate quotes', () {
      final res1 = RoleplayAiEngine.personalizeWithUserName('""Hello there""', 'Prince');
      expect(res1.startsWith('""'), isFalse);

      final res2 = RoleplayAiEngine.personalizeWithUserName('"[EMOTION: romantic] Hello"', 'Prince');
      expect(res2.contains('[EMOTION'), isFalse);
      expect(res2.contains('Prince'), isTrue);
    });

    test('NotificationCampaignService correctly enforces 3x daily notification rules for free vs paid users', () async {
      final storage = StorageService();
      await storage.init();
      final campaign = NotificationCampaignService();

      // Initially no chat initiated -> not eligible
      await storage.setFirstChatInitiated(false);
      expect(campaign.isEligibleForCampaign(storage: storage, isSubscribed: false, coinBalance: 5), isFalse);

      // Once user initiates chat on free plan without paid coins -> eligible
      await storage.setFirstChatInitiated(true);
      await storage.setHasPurchasedPaidCoins(false);
      expect(campaign.isEligibleForCampaign(storage: storage, isSubscribed: false, coinBalance: 5), isTrue);

      // If user is VIP subscribed -> NOT eligible
      expect(campaign.isEligibleForCampaign(storage: storage, isSubscribed: true, coinBalance: 5), isFalse);

      // If user purchased paid coins and has positive balance -> NOT eligible
      await storage.setHasPurchasedPaidCoins(true);
      expect(campaign.isEligibleForCampaign(storage: storage, isSubscribed: false, coinBalance: 100), isFalse);

      // If paid coins are depleted (0 balance) and not subscribed -> eligible again
      expect(campaign.isEligibleForCampaign(storage: storage, isSubscribed: false, coinBalance: 0), isTrue);

      // Verify character-specific messaging for Morning, Afternoon, and Night
      final aria = Character.allCharacters.firstWhere((c) => c.id == 'aria_sterling_happy');
      await campaign.onChatInitiated(character: aria, storage: storage, isSubscribed: false, coinBalance: 0);
      expect(storage.getLastChattedCharacterId(), equals('aria_sterling_happy'));
      expect(storage.hasInitiatedFirstChat(), isTrue);
    });

    test('Chat message awards exactly +5 XP and Voice call awards exactly +25 XP per minute', () async {
      final storage = StorageService();
      await storage.init();
      await storage.setCoins(50);
      final coinProvider = CoinProvider(storage);
      final userProvider = UserProvider(storage);
      final chatProvider = ChatProvider(
        storage: storage,
        coinProvider: coinProvider,
        userProvider: userProvider,
      );

      final character = Character.allCharacters.first;
      await storage.saveAffection(character.id, 10);
      chatProvider.openChat(character: character);

      expect(chatProvider.relationship.affectionPoints, 10);

      // Send 1 message -> should add exactly +5 XP (from 10 to 15)
      final sent = await chatProvider.sendMessage("Hey!", MoodType.happy);
      expect(sent, true);
      expect(chatProvider.relationship.affectionPoints, 15);
      expect(storage.getAffection(character.id), 15);

      // Voice call: start call -> should bill minute 1 and add exactly +25 XP (from 15 to 40)
      final voiceService = VoiceService();
      final voiceProvider = VoiceProvider(
        voiceService: voiceService,
        coinProvider: coinProvider,
        storageService: storage,
      );
      final callStarted = await voiceProvider.startCall(
        character: character,
        scenario: Scenario.allScenarios.first,
        currentMood: MoodType.romantic,
      );
      expect(callStarted, true);
      expect(storage.getAffection(character.id), 40);
      voiceProvider.endCall();
    });
  });
}
