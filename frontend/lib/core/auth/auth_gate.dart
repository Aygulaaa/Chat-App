import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/app_shell/presentation/pages/main__screen.dart';
import 'package:my_chat_app/features/auth/presentation/pages/auth_page.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/users/presentation/providers/user_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(authProvider.notifier).tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasLoggedIn = previous?.user != null;
      final isLoggedIn = next.user != null;

      if (!wasLoggedIn && isLoggedIn) {
        Future.delayed(const Duration(milliseconds: 100), () {
          ref.read(userProfileProvider.notifier).fetchProfile();
          ref.read(chatProvider.notifier).loadChats();
        });
      }

      // if (wasLoggedIn && !isLoggedIn) {
      //   // ✅ Just logged out — clear all state
      //   ref.read(chatProvider.notifier).clearChats();
      // }
    });

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (state.user != null) {
      return const MainScreen();
    }

    return const AuthPage();
  }
}
