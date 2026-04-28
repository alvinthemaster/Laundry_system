import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level function for background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log(
    'Handling background message: ${message.messageId}',
    name: 'NotificationService',
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission for notifications
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      developer.log(
        'Notification permission status: ${settings.authorizationStatus}',
        name: 'NotificationService',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications for Android
        await _initializeLocalNotifications();

        // Get FCM token
        final token = await _messaging.getToken();
        if (token != null) {
          developer.log('FCM Token: $token', name: 'NotificationService');
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          developer.log(
            'FCM Token refreshed: $newToken',
            name: 'NotificationService',
          );
          // Note: Token will be saved when user logs in
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Handle notification taps (app opened from notification)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        _initialized = true;
      }
    } catch (e) {
      developer.log(
        'Error initializing notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    developer.log(
      'Foreground message received: ${message.notification?.title}',
      name: 'NotificationService',
    );

    // Show local notification when app is in foreground
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle message opened app (user tapped notification)
  void _handleMessageOpenedApp(RemoteMessage message) {
    developer.log(
      'Notification opened: ${message.notification?.title}',
      name: 'NotificationService',
    );
    // TODO: Navigate to specific screen based on message data
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    developer.log(
      'Notification tapped: ${response.payload}',
      name: 'NotificationService',
    );
    // TODO: Navigate to specific screen based on payload
  }

  /// Show local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'booking_status_channel',
      'Booking Status Notifications',
      channelDescription: 'Notifications for booking status updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Internal method for showing notifications from message handler
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showLocalNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Save FCM token to user's profile in Firestore
  Future<void> saveFCMToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        developer.log(
          'FCM token saved for user: $userId',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        'Error saving FCM token: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Remove FCM token from user's profile (on logout)
  Future<void> removeFCMToken(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      developer.log(
        'FCM token removed for user: $userId',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error removing FCM token: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
