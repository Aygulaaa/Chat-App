import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// Top-Level background handler (Runs in a separate Dart Isolate)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
try {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    if (!notificationsEnabled) return;
  } catch (e) {
    print('⚠️ Could not read SharedPreferences in background isolate: $e');
  }

  // If the backend sends a data-only payload, display it manually in the background isolate
  if (message.notification == null && message.data.isNotEmpty) {
    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    print("message background  $message");

    final title = message.data['title'] ?? 'New Message';
    final body = message.data['body'] ?? message.data['text'] ?? '';

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FcmService._internal({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

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
    // 1. Android & iOS Notification Permissions
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.createNotificationChannel(_channel);

    var status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Prevent duplicate system banners on iOS while app is in foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    // 3. Initialize Local Notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          final data = jsonDecode(response.payload!);
          onNotificationTap(data);
        }
      },
    );

    // 4. Foreground FCM Listener (Only active if FCM Push is received while in app)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('notificationsEnabled') ?? true)) return;

      // Note: In-app overlay is handled by WebSocket in ChatNotifier.
      // If backend sends FCM while in foreground, local notification triggers here only if needed.
    });

    // 5. Background & Terminated Launch Handlers
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onNotificationTap(message.data);
    });

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
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
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notificationsEnabled') ?? true)) return;

    _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
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
      return await _messaging.getToken();
    } catch (e) {
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}