import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background notification if custom payload needed
  debugPrint("Handling background FCM message: ${message.messageId}");
}

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  bool _isInitialized = false;
  FirebaseMessaging? _messaging;

  final StreamController<Map<String, dynamic>> _onNotificationClickController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationClick => _onNotificationClickController.stream;

  bool get isFirebaseAvailable => _isInitialized && _messaging != null;

  /// Safely initializes Firebase and FCM with graceful fallback if credentials are not yet configured.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase App (safe for tests or pre-config runs)
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      // 2. Register top-level background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Request Notification permissions (Android 13+ POST_NOTIFICATIONS & iOS)
      final settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint("FCM Notification Permission status: ${settings.authorizationStatus}");

      // 4. Retrieve and persist FCM Device Token
      final token = await _messaging!.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint("FCM Device Token retrieved: $token");
        await StorageService().setFcmToken(token);
      }

      // 5. Listen to token refresh
      _messaging!.onTokenRefresh.listen((newToken) async {
        debugPrint("FCM Device Token refreshed: $newToken");
        await StorageService().setFcmToken(newToken);
      });

      // 6. Handle foreground push notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Received foreground push notification: ${message.notification?.title}");
        if (message.data.isNotEmpty) {
          _onNotificationClickController.add(message.data);
        }
      });

      // 7. Handle notification click (when app is opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("User opened app via notification: ${message.data}");
        if (message.data.isNotEmpty) {
          _onNotificationClickController.add(message.data);
        }
      });

      // 8. Handle cold-start from notification
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        _onNotificationClickController.add(initialMessage.data);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint("Firebase Notification Service notice (Running in local-first sandbox mode): $e");
    }
  }

  /// Subscribe to campaign topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (_messaging != null) {
        await _messaging!.subscribeToTopic(topic);
        debugPrint("Subscribed to FCM topic: $topic");
      }
    } catch (e) {
      debugPrint("Could not subscribe to topic $topic: $e");
    }
  }

  /// Unsubscribe from campaign topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (_messaging != null) {
        await _messaging!.unsubscribeFromTopic(topic);
        debugPrint("Unsubscribed from FCM topic: $topic");
      }
    } catch (e) {
      debugPrint("Could not unsubscribe from topic $topic: $e");
    }
  }

  void dispose() {
    _onNotificationClickController.close();
  }
}
