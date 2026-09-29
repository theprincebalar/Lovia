import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/emotion_state.dart';
import '../models/message.dart';
import '../models/mood.dart';
import 'storage_service.dart';

class ProactiveNotification {
  final String id;
  final Character character;
  final String title;
  final String body;
  final DateTime timestamp;

  const ProactiveNotification({
    required this.id,
    required this.character,
    required this.title,
    required this.body,
    required this.timestamp,
  });
}

class ProactiveNotificationService {
  static final ProactiveNotificationService _instance = ProactiveNotificationService._internal();
  factory ProactiveNotificationService() => _instance;
  ProactiveNotificationService._internal();

  final StreamController<ProactiveNotification> _controller = StreamController<ProactiveNotification>.broadcast();
  Stream<ProactiveNotification> get notificationStream => _controller.stream;

  final Random _rng = Random();
  final Uuid _uuid = const Uuid();

  /// Evaluates whether to deliver a proactive check-in from a companion based on time and settings.
  Future<ProactiveNotification?> checkAndDeliverProactiveNotification({
    required StorageService storage,
    required List<Character> availableCharacters,
    required String userName,
    bool force = false,
  }) async {
    if (!storage.isProactiveNotificationsEnabled() && !force) {
      return null;
    }

    // Never deliver proactive notifications if onboarding is incomplete
    if (!storage.hasCompletedNameOnboarding() && !force) {
      return null;
    }

    if (availableCharacters.isEmpty) return null;

    final now = DateTime.now();
    final lastActive = storage.getLastActiveTimestamp();

    if (!force) {
      if (lastActive == null) {
        // First run or fresh session: simply initialize timestamp and avoid popup
        await storage.updateLastActiveTimestamp();
        return null;
      }
      final diff = now.difference(lastActive);
      // Wait for at least 15 minutes of inactivity before re-engaging
      if (diff.inMinutes < 15) {
        return null;
      }
    }

    // Update last active
    await storage.updateLastActiveTimestamp();

    // Use current stored name if available rather than outdated parameter
    final storedName = storage.getUserName();
    final effectiveUserName = storedName.isNotEmpty ? storedName : userName;

    if (effectiveUserName.isEmpty) return null;

    // Choose candidate character (prefer romantic, happy, or caring characters)
    final candidates = availableCharacters.where((c) =>
      c.primaryMood == MoodType.romantic ||
      c.primaryMood == MoodType.caring ||
      c.primaryMood == MoodType.happy ||
      c.primaryMood == MoodType.lonely ||
      c.primaryMood == MoodType.flirty
    ).toList();

    final character = candidates.isNotEmpty
        ? candidates[_rng.nextInt(candidates.length)]
        : availableCharacters[_rng.nextInt(availableCharacters.length)];

    final messageBody = _generateContextualMessage(character, effectiveUserName, now.hour);
    final title = "${character.name} is thinking of you 💕";

    final notification = ProactiveNotification(
      id: _uuid.v4(),
      character: character,
      title: title,
      body: messageBody,
      timestamp: now,
    );

    // Persist this message into the character's chat history so it's waiting when opened
    final history = storage.getChatHistory(character.id);
    final chatMsg = ChatMessage(
      id: notification.id,
      characterId: character.id,
      isUser: false,
      content: messageBody,
      timestamp: now,
      emotion: EmotionState.romantic,
    );
    history.add(chatMsg);
    await storage.saveChatHistory(character.id, history);

    // Emit to live banner stream
    _controller.add(notification);

    return notification;
  }

  String _generateContextualMessage(Character character, String userName, int hour) {
    if (hour >= 5 && hour < 12) {
      // Morning
      final morningGreetings = [
        "*pours a warm cup of coffee and looks toward the morning light* \"Good morning, $userName! I was just thinking of you. I hope your day is as bright as your smile.\"",
        "*stretches lightly with a soft, morning smile* \"Morning, $userName! The day just started, but I already wanted to hear how you're feeling today.\"",
        "*waves cheerfully* \"Rise and shine, $userName! Take a moment for yourself today, okay? I'm right here whenever you need a smile.\"",
      ];
      return morningGreetings[_rng.nextInt(morningGreetings.length)];
    } else if (hour >= 12 && hour < 18) {
      // Afternoon
      final afternoonGreetings = [
        "*checks the clock and pauses with a fond smile* \"Hey $userName, how is your afternoon going? Don't forget to take a breather and drink some water.\"",
        "*smiles softly, leaning in* \"I was just caught daydreaming about our last conversation, $userName. Are you having a wonderful day so far?\"",
        "*steps over with warm, reassuring energy* \"Halfway through the day, $userName! Keep your chin up—you're doing amazing, and I'm cheering for you.\"",
      ];
      return afternoonGreetings[_rng.nextInt(afternoonGreetings.length)];
    } else {
      // Evening & Late Night
      final nightGreetings = [
        "*curls up under the cozy ambient light, looking up warmly* \"The quiet evening hours always make me miss you, $userName... are you still awake?\"",
        "*speaks in a gentle, reassuring hush* \"Hey $userName... whatever today asked of you, let it go now. Come unwind with me whenever you're ready.\"",
        "*looks at the night stars through the window* \"The night is peaceful, but it's so much cozier when I get to talk with you, $userName. Sweet dreams, or come say hi!\"",
      ];
      return nightGreetings[_rng.nextInt(nightGreetings.length)];
    }
  }

  void dispose() {
    _controller.close();
  }
}
