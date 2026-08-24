import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:overlay_support/overlay_support.dart';

import 'package:my_chat_app/core/auth/auth_gate.dart';
import 'package:my_chat_app/core/constants/api_config.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/app_shell/presentation/pages/main__screen.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/core/network/fcm_service.dart';

// Global Navigation Key for handling push notification routing
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load .env FIRST so API endpoints are available to services
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env loaded successfully!');
  } catch (e) {
    print('⚠️ .env load warning: $e');
  }

  // Initialize API Configuration synchronously
  ApiConfig.init();

  // 2. Initialize Firebase
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully!');

    // 3. Register FCM background isolates AFTER initializing Firebase
    FcmService.registerBackgroundHandler();

    final fcmService = FcmService();

    // Non-blocking initialization
    fcmService.initialize(
      onNotificationTap: (data) {
        print("🔔 Notification tapped with payload: $data");

        if (data.containsKey('chatId') && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed(
            '/chat',
            arguments: data['chatId'],
          );
        }
      },
    );

    final token = await fcmService.getToken();
    print('🔥 MY_FCM_TOKEN: $token');
  } catch (e) {
    print('❌ Firebase/FCM init Error: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final themeStr = settingsAsync.valueOrNull?.theme ?? 'dark';
    final themeMode = themeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return OverlaySupport.global(
          child: MaterialApp(
            navigatorKey:
                navigatorKey, // Attached for deep-linking from notifications
            debugShowCheckedModeBanner: false,
            title: 'Chat App',
            themeMode: themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: AppColors.lightBg,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: AppColors.lightBg,
                foregroundColor: AppColors.lightTextPrimary,
              ),
              textTheme: const TextTheme(
                titleMedium: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary,
                ),
                bodyMedium: TextStyle(
                  fontSize: 13,
                  color: AppColors.lightTextPrimary,
                ),
                bodySmall: TextStyle(
                  fontSize: 11,
                  color: AppColors.lightTextSecondary,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: AppColors.darkBg,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: AppColors.darkBg,
                foregroundColor: AppColors.darkTextPrimary,
              ),
              textTheme: const TextTheme(
                titleMedium: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkTextPrimary,
                ),
                bodyMedium: TextStyle(
                  fontSize: 13,
                  color: AppColors.darkTextPrimary,
                ),
                bodySmall: TextStyle(
                  fontSize: 11,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            home: const AuthGate(),
            routes: {'/home': (_) => const MainScreen()},
          ),
        );
      },
    );
  }
}
