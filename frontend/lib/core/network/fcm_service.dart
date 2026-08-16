import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-Level background handler (MUST remain outside the class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background push received: ${message.messageId}');
}

class FcmService {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FcmService({
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

  /// Registers background messaging handler early
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> initialize({
    required Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    // 1. Request Permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('⚠️ User declined push permissions');
      return;
    }

    // 2. Local Notifications Setup
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

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

    // 3. Foreground Banner Execution (Fixed for both Android & iOS)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;

      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
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
          payload: jsonEncode(message.data),
        );
      }
    });

    // 4. Background Tap Handler
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onNotificationTap(message.data);
    });

    // 5. Terminated App Launch Handler
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      onNotificationTap(initialMessage.data);
    }
  }

  /// Safe Token Getter with APNs Handling for iOS
  Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
        }
        if (apnsToken == null) {
          print('⚠️ APNs token not available yet (iOS Simulator or network lag).');
          return null;
        }
      }
      return await _messaging.getToken();
    } catch (e) {
      print('❌ Error fetching FCM Token: $e');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}