import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Handle data-only payloads when app is in background/terminated
  if (message.notification == null && message.data.isNotEmpty) {
    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_notification');
    const iosSettings = DarwinInitializationSettings();
    
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for incoming chat messages',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_notification',
    );

    final title = message.data['title'] ?? 'New Message';
    final body = message.data['body'] ?? message.data['text'] ?? '';

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
      payload: jsonEncode(message.data),
    );
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal(); // Added missing private constructor

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for incoming chat messages',
    importance: Importance.max,
  );

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> initialize({
    required Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    // 1. Request iOS & Android 13+ Permissions
    await Permission.notification.request();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('🔔 FCM Auth Status: ${settings.authorizationStatus}');

    // 2. iOS Foreground Presentation — disabled so in-app overlay is used instead
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // 3. Android High-Importance Channel Setup
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_notification');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!);
            if (data is Map<String, dynamic>) {
              onNotificationTap(data);
            }
          } catch (e) {
            debugPrint('❌ Error parsing notification payload: $e');
          }
        }
      },
    );

    // 4. Foreground FCM Listener — NO OS notification; in-app overlay handles it
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📩 FCM Foreground (suppressed OS banner): ${message.messageId}');
      // In-app overlay is shown by ChatNotifier via socket 'message' event.
      // Do NOT call showLocalNotification here to avoid duplicate OS banners.
    });

    // 5. App Launch / Resume Handlers via Notification Taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onNotificationTap(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      onNotificationTap(initialMessage.data);
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_notification',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('🔑 FCM Registration Token: $token');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}