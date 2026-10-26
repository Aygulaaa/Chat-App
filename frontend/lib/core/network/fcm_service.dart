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

    // Same per-chat tag the server puts on notification-type pushes, so a
    // chat has ONE notification however it was posted — and one that the app
    // can clear by tag once the chat is read.
    final chatId = int.tryParse(message.data['chatId']?.toString() ?? '');
    final tag = message.data['tag']?.toString() ??
        (chatId != null ? FcmService.chatTag(chatId) : null);

    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for incoming chat messages',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_notification',
      tag: tag,
    );

    final title = message.data['title'] ?? 'New Message';
    final body = message.data['body'] ?? message.data['text'] ?? '';

    await localNotifications.show(
      // Keyed by chat so a later message replaces this one instead of
      // stacking, and so cancelling by chat id finds it.
      chatId ?? message.hashCode,
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

  /// The tag every notification for one chat carries. Must match the server's
  /// `chatNotificationTag` in notificationService.ts.
  static String chatTag(int chatId) => 'chat_$chatId';

  /// Clears the notification tray for one chat — call it once the messages in
  /// it have actually been read, so a chat the user has already opened does
  /// not keep sitting in the shade.
  ///
  /// Android: notifications are addressed by (tag, id). The Firebase SDK posts
  /// notification-type pushes as `notify(tag, 0)`, while the background
  /// handler above posts data-only ones under the chat id — so both are
  /// cancelled here.
  ///
  /// iOS: only notifications this app posted itself can be removed by
  /// identifier. Ones the system displayed from an APNs payload are replaced
  /// (via `apns-collapse-id`) rather than removed, and clear when tapped.
  Future<void> cancelChatNotifications(int chatId) async {
    final tag = chatTag(chatId);
    try {
      await _localNotifications.cancel(0, tag: tag);
      await _localNotifications.cancel(chatId, tag: tag);
    } catch (e) {
      debugPrint('❌ Failed to clear notifications for chat $chatId: $e');
    }
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