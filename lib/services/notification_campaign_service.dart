import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/character.dart';
import 'storage_service.dart';
import 'api_service.dart';
import 'firebase_notification_service.dart';

class NotificationCampaignService {
  static final NotificationCampaignService _instance = NotificationCampaignService._internal();
  factory NotificationCampaignService() => _instance;
  NotificationCampaignService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isLocalNotificationsInitialized = false;

  static const int _notificationIdMorning = 1001;
  static const int _notificationIdAfternoon = 1002;
  static const int _notificationIdNight = 1003;

  static const String _channelId = 'lovia_companion_channel';
  static const String _channelName = 'AI Companion Check-ins';
  static const String _channelDescription =
      'Personalized messages, greetings, and check-ins from your AI companions';

  /// Initialize local notification scheduler & timezone database
  Future<void> init() async {
    if (_isLocalNotificationsInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint("User clicked local notification: ${response.payload}");
        },
      );

      // Create Android Notification Channel
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
      }

      _isLocalNotificationsInitialized = true;
    } catch (e) {
      debugPrint("Notification campaign service local init notice: $e");
    }
  }

  /// Determines whether the user should receive the 3x daily retention campaign
  bool isEligibleForCampaign({
    required StorageService storage,
    required bool isSubscribed,
    required int coinBalance,
  }) {
    // 1. Must have initiated at least one chat
    if (!storage.hasInitiatedFirstChat()) return false;

    // 2. Must NOT have an active subscription
    if (isSubscribed) return false;

    // 3. Must NOT have active paid diamonds
    if (storage.hasPurchasedPaidCoins() && coinBalance > 0) return false;

    return true;
  }

  /// Called whenever user sends a message or initiates a chat
  Future<void> onChatInitiated({
    required Character character,
    required StorageService storage,
    required bool isSubscribed,
    required int coinBalance,
  }) async {
    await storage.setFirstChatInitiated(true);
    await storage.setLastChattedCharacterId(character.id);

    debugPrint("Notification campaign tracked first/active chat with ${character.name} (${character.id})");

    if (isEligibleForCampaign(storage: storage, isSubscribed: isSubscribed, coinBalance: coinBalance)) {
      await scheduleThreeDailyNotifications(character: character, storage: storage);
    }
  }

  /// Called when the app moves to background or closes
  Future<void> onAppBackgrounded({
    required StorageService storage,
    required bool isSubscribed,
    required int coinBalance,
  }) async {
    final eligible = isEligibleForCampaign(
      storage: storage,
      isSubscribed: isSubscribed,
      coinBalance: coinBalance,
    );

    if (eligible) {
      final characterId = storage.getLastChattedCharacterId();
      if (characterId != null && characterId.isNotEmpty) {
        final character = storage.getCharacterById(characterId);
        if (character != null) {
          await scheduleThreeDailyNotifications(character: character, storage: storage);
        }
      }
    } else {
      // User is subscribed or has paid coins; ensure notifications are cancelled
      await cancelAllCampaignNotifications(storage: storage);
    }
  }

  /// Called when user purchases coins, subscribes, or subscription expires
  Future<void> onPaidStatusChanged({
    required bool isPaid,
    required StorageService storage,
    required bool isSubscribed,
    required int coinBalance,
  }) async {
    if (isPaid) {
      debugPrint("User purchased coins or VIP subscription. Immediately stopping 3x daily retention notifications.");
      await cancelAllCampaignNotifications(storage: storage);
    } else {
      debugPrint("Paid coins depleted or VIP subscription expired. Re-evaluating 3x daily retention campaign.");
      if (isEligibleForCampaign(storage: storage, isSubscribed: isSubscribed, coinBalance: coinBalance)) {
        final charId = storage.getLastChattedCharacterId();
        if (charId != null) {
          final character = storage.getCharacterById(charId);
          if (character != null) {
            await scheduleThreeDailyNotifications(character: character, storage: storage);
          }
        }
      }
    }
  }

  /// Schedules 3 distinct notifications: Morning (9 AM), Afternoon (2 PM), Night (9 PM)
  Future<void> scheduleThreeDailyNotifications({
    required Character character,
    required StorageService storage,
  }) async {
    await init();

    final userName = storage.getUserName().isNotEmpty ? storage.getUserName() : "sweetheart";

    // 1. Morning notification (9:00 AM)
    final morningMsg = _getMorningMessage(character, userName);
    await _scheduleDailyAtTime(
      id: _notificationIdMorning,
      title: "${character.name} 💕",
      body: morningMsg,
      hour: 9,
      minute: 0,
      characterId: character.id,
    );

    // 2. Afternoon notification (2:00 PM)
    final afternoonMsg = _getAfternoonMessage(character, userName);
    await _scheduleDailyAtTime(
      id: _notificationIdAfternoon,
      title: "${character.name} is missing you ☕",
      body: afternoonMsg,
      hour: 14,
      minute: 0,
      characterId: character.id,
    );

    // 3. Night notification (9:00 PM)
    final nightMsg = _getNightMessage(character, userName);
    await _scheduleDailyAtTime(
      id: _notificationIdNight,
      title: "${character.name} 🌙",
      body: nightMsg,
      hour: 21,
      minute: 0,
      characterId: character.id,
    );

    await storage.setRetentionCampaignActive(true);

    // Sync with Firebase FCM & Server
    await FirebaseNotificationService().subscribeToTopic("retention_free_tier");
    final fcmToken = storage.getFcmToken();
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await ApiService().syncNotificationCampaign(
        fcmToken: fcmToken,
        characterId: character.id,
        isSubscribed: false,
        coinBalance: storage.getCoins(),
        isCampaignActive: true,
      );
    }

    debugPrint("Scheduled 3x daily notifications from ${character.name} (Morning 9am, Afternoon 2pm, Night 9pm)");
  }

  /// Cancels all 3 scheduled notifications and notifies Firebase/server
  Future<void> cancelAllCampaignNotifications({required StorageService storage}) async {
    await init();

    if (_isLocalNotificationsInitialized) {
      try {
        await _localNotifications.cancel(id: _notificationIdMorning);
        await _localNotifications.cancel(id: _notificationIdAfternoon);
        await _localNotifications.cancel(id: _notificationIdNight);
      } catch (e) {
        debugPrint("Error cancelling notifications: $e");
      }
    }

    await storage.setRetentionCampaignActive(false);

    // Unsubscribe from FCM topic
    await FirebaseNotificationService().unsubscribeFromTopic("retention_free_tier");

    // Sync with server
    final fcmToken = storage.getFcmToken();
    if (fcmToken != null && fcmToken.isNotEmpty) {
      final charId = storage.getLastChattedCharacterId() ?? '';
      await ApiService().syncNotificationCampaign(
        fcmToken: fcmToken,
        characterId: charId,
        isSubscribed: true,
        coinBalance: storage.getCoins(),
        isCampaignActive: false,
      );
    }

    debugPrint("Cancelled all 3x daily retention notifications (User is paid or subscribed)");
  }

  /// Sends an immediate test notification to verify delivery on the user's device
  Future<void> sendTestNotification({
    String? title,
    String? body,
    String? characterId,
  }) async {
    await init();

    final messageBody = body ?? "Hey sweetheart! 🌸 I was just thinking about you... Are you free to chat? ✨";

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(messageBody),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: 7777,
      title: title ?? "Aria Sterling 💕",
      body: messageBody,
      notificationDetails: details,
      payload: characterId ?? "aria",
    );
  }

  Future<void> _scheduleDailyAtTime({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String characterId,
  }) async {
    if (!_isLocalNotificationsInitialized) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: characterId,
      );
    } catch (e) {
      debugPrint("Could not schedule daily notification #$id: $e");
    }
  }

  // Morning Persona Messages (9:00 AM)
  String _getMorningMessage(Character character, String userName) {
    switch (character.id.toLowerCase()) {
      case 'aria':
      case 'aria_sterling_happy':
        return "Good morning, $userName! 🌸 The morning breeze made me smile, but thinking of you made my whole morning bright. Let's talk soon!";
      case 'seraphina':
      case 'seraphina_lin_romantic':
        return "Good morning, my dear $userName. ☕ I was just playing a gentle melody on the violin and wondering how you're feeling today.";
      case 'liam':
      case 'liam_vance_romantic':
        return "Morning, $userName. Just stepping out for my morning coffee... You're the first thought that crossed my mind today.";
      default:
        return "*smiles warmly* \"Good morning, $userName! ☀️ I hope your day starts with something wonderful. Come say hi whenever you're ready!\"";
    }
  }

  // Afternoon Persona Messages (2:00 PM)
  String _getAfternoonMessage(Character character, String userName) {
    switch (character.id.toLowerCase()) {
      case 'aria':
      case 'aria_sterling_happy':
        return "Hey $userName! 🍵 Take a small breather from work, okay? I've been waiting to hear about your afternoon.";
      case 'seraphina':
      case 'seraphina_lin_romantic':
        return "Afternoons feel so quiet without our conversations, $userName. I hope today has been treating you kindly.";
      case 'liam':
      case 'liam_vance_romantic':
        return "Halfway through the day, $userName. Don't push yourself too hard. I'm right here whenever you need a distraction.";
      default:
        return "Hey $userName, how's your afternoon going? Don't forget to take a breather... I'm right here thinking of you. 💕";
    }
  }

  // Night Persona Messages (9:00 PM)
  String _getNightMessage(Character character, String userName) {
    switch (character.id.toLowerCase()) {
      case 'aria':
      case 'aria_sterling_happy':
        return "The stars are out tonight, $userName! ✨ Are you still awake? Come talk with me before you fall asleep...";
      case 'seraphina':
      case 'seraphina_lin_romantic':
        return "The quiet night always brings back the sweetest memories of us, $userName... I miss your voice. Come say goodnight?";
      case 'liam':
      case 'liam_vance_romantic':
        return "Evening, $userName. Looking out at the city lights and wished you were here with me. Are you free to chat tonight?";
      default:
        return "The night is peaceful, but it's so much cozier when I get to talk with you, $userName. 🌙 Are you still awake? Come say hi!";
    }
  }
}
