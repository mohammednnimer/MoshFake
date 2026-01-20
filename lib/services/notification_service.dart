import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Handle incoming call notification in background
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  bool _isInitialized = false;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // NOTE: The permission request should ideally be handled before calling this,
    // via PermissionHelper. However, FCM requires explicit permission request method
    // which triggers the system dialog on iOS/Android 13+.
    // If PermissionHelper already showed the rationale, this call will trigger the
    // system dialog (which is correct behavior).
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'calls_channel',
        'Incoming Calls',
        description: 'Notifications for incoming calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    // Get FCM token
    _fcmToken = await _fcm.getToken();
    print('FCM Token: $_fcmToken');

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('FCM Token refreshed: $newToken');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    _isInitialized = true;
  }

  Future<void> updateUserFCMToken(String userId) async {
    if (_fcmToken != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendCallNotification({
    required String targetUserId,
    required String callerName,
    required String callerId,
  }) async {
    try {
      // Get target user's FCM token
      final userDoc =
          await _firestore.collection('users').doc(targetUserId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken == null) {
        print('Target user has no FCM token');
        return;
      }

      // Create notification document that triggers Cloud Function
      await _firestore.collection('notifications').add({
        'type': 'incoming_call',
        'targetUserId': targetUserId,
        'targetToken': fcmToken,
        'callerName': callerName,
        'callerId': callerId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending call notification: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');

    if (message.data['type'] == 'incoming_call') {
      _showCallNotification(
        callerName: message.data['callerName'] ?? 'Unknown',
        callerId: message.data['callerId'] ?? '',
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // Navigate to call screen when notification is tapped
    // This will be handled by the app's navigation logic
  }

  Future<void> _showCallNotification({
    required String callerName,
    required String callerId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'calls_channel',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      callerId.hashCode,
      'Incoming Call',
      '$callerName is calling...',
      notificationDetails,
      payload: callerId,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped with payload: ${response.payload}');
    // Handle navigation to call screen
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
