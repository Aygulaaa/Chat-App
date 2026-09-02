// core/auth/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/features/app_shell/presentation/pages/main__screen.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AuthGate({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Fetch initial data if token was successfully auto-restored
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        ref.read(userProfileProvider.notifier).fetchProfile();
        ref.read(chatProvider.notifier).loadChats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasLoggedIn = previous?.isAuthenticated ?? false;
      final isLoggedIn = next.isAuthenticated;

      if (!wasLoggedIn && isLoggedIn) {
        ref.read(userProfileProvider.notifier).fetchProfile();
        ref.read(chatProvider.notifier).loadChats();
      }
    });

    return MainScreen(navigationShell: widget.navigationShell);
  }
}