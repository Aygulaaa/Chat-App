import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/app_shell/presentation/widgets/glass_nav_bar.dart';

/// App shell host for preserving state across shell branch tabs.
class MainScreen extends StatelessWidget {
  const MainScreen({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Handles tab switching safely and prevents out-of-bounds assertions.
  void _onTabChanged(int index) {
    if (index < 0 || index >= 3) return;

    navigationShell.goBranch(
      index,
      // Reset branch stack when tapping the active tab again
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      extendBody: true,
      // StatefulNavigationShell renders the current branch directly
      // preserving state across routes automatically.
      body: navigationShell,
      bottomNavigationBar: GlassNavBar(
        index: navigationShell.currentIndex.clamp(0, 2),
        onChanged: _onTabChanged,
      ),
    );
  }
}