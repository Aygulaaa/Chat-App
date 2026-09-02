import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:overlay_support/overlay_support.dart';

import 'package:my_chat_app/core/constants/api_config.dart';
import 'package:my_chat_app/core/network/fcm_service.dart';
import 'package:my_chat_app/core/router/app_router.dart';
import 'package:my_chat_app/core/theme/app_theme.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/notification/presentation/providers/notification_provider.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Local Cache Initialization
  await Hive.initFlutter();
  await Hive.openBox<String>('chats_cache');
  await Hive.openBox<String>('messages_cache');
  await Hive.openBox<String>('user_profile_cache');
  await Hive.openBox<String>('contacts_cache');

  // 2. Load Environment Variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('⚠️ .env load warning: $e');
  }

  ApiConfig.init();

  // 3. Initialize Firebase & Register Background Handler Isolate
  try {
    await Firebase.initializeApp();
    FcmService.registerBackgroundHandler();
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
  }

  // 4. Create explicit ProviderContainer to attempt Auto-Login before mounting UI
  final container = ProviderContainer();
  await container.read(authProvider.notifier).tryAutoLogin();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFcm();
    });
  }

  Future<void> _initFcm() async {
    final fcmService = ref.read(fcmServiceProvider);
    
    // Initialize notification channels, permissions, and click listeners
    await fcmService.initialize(
      onNotificationTap: (data) {
        if (!mounted) return;
        final chatId = data['chatId']?.toString();
        if (chatId != null && chatId.isNotEmpty) {
          ref.read(routerProvider).push('/chat/conversation/$chatId');
        }
      },
    );

    // Initial token sync on launch if already authenticated via auto-login
    final user = ref.read(authProvider).user;
    if (user != null) {
      await _syncCurrentToken();
    }

    // Single continuous subscription to token refreshes throughout app lifecycle
    fcmService.onTokenRefresh.listen((newToken) {
      final currentUser = ref.read(authProvider).user;
      if (currentUser != null) {
        ref.read(syncFcmTokenUseCaseProvider).call(newToken);
      }
    });
  }

  Future<void> _syncCurrentToken() async {
    try {
      final token = await ref.read(fcmServiceProvider).getToken();
      if (token != null && token.isNotEmpty) {
        await ref.read(syncFcmTokenUseCaseProvider).call(token);
        debugPrint('✅ FCM Token synced on startup');
      }
    } catch (e) {
      debugPrint('❌ Startup FCM token sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for authentication changes (e.g., transition from login screen to active user)
    ref.listen(authProvider, (previous, next) {
      if (previous?.user == null && next.user != null) {
        _syncCurrentToken();
      }
    });

    final settingsAsync = ref.watch(settingsProvider);
    final themeStr = settingsAsync.value?.theme ?? 'dark';
    final themeMode = themeStr == 'light' ? ThemeMode.light : ThemeMode.dark;
    final router = ref.watch(routerProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return OverlaySupport.global(
          child: MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            title: 'Navihat Chat',
            themeMode: themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
          ),
        );
      },
    );
  }
}