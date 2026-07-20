import 'package:flutter/material.dart';
import 'package:my_chat_app/core/auth/auth_gate.dart';
import 'package:my_chat_app/features/app_shell/presentation/pages/main__screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");


  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),

        textTheme: const TextTheme(
          titleMedium:TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color:Colors.white,
           ),
           bodyMedium: TextStyle(
            fontSize: 13,
            color:Colors.white,
           ),
           bodySmall: TextStyle(
            fontSize: 11,
            color: Colors.white54,
           )
        ),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
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
  }
}
