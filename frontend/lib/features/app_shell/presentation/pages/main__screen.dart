import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/contacts/presentation/pages/contacts_screen.dart';
import 'package:my_chat_app/features/app_shell/presentation/widgets/glass_nav_bar.dart';
import 'package:my_chat_app/features/chat/presentation/pages/home_page.dart';
import 'package:my_chat_app/features/users/presentation/pages/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const ContactsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: context.appBg,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: GlassNavBar(
        index: _currentIndex,
        onChanged: (val) => setState(() => _currentIndex = val),
      ),
    );
  }
}
