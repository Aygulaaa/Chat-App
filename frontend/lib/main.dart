import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/auth/auth_gate.dart';
import 'package:my_chat_app/core/constants/api_config.dart';
import 'package:my_chat_app/features/app_shell/presentation/pages/main__screen.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {

    await dotenv.load(fileName: ".env");
    print('✅ .env loaded successfully!');

    ApiConfig.init();
  } catch (e) {
    print('❌ Error: $e');
    ApiConfig.init(); 
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
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Chat App',
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFFF1F5F9),
              foregroundColor: Color(0xFF0F172A),
            ),
            textTheme: const TextTheme(
              titleMedium: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              bodySmall: TextStyle(fontSize: 11, color: Color(0xFF475569)),
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
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF090D16),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFF090D16),
              foregroundColor: Colors.white,
            ),
            textTheme: const TextTheme(
              titleMedium: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              bodyMedium: TextStyle(fontSize: 13, color: Colors.white),
              bodySmall: TextStyle(fontSize: 11, color: Colors.white54),
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
        );
      },
    );
  }
}
