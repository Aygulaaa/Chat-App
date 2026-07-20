import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/widgets/auth_card.dart';

class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({super.key});

  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLogin = true;

  void login() {
    ref.read(authProvider.notifier).login(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
  }

  void register() {
    if (passwordController.text != confirmPasswordController.text) return;

    ref.read(authProvider.notifier).register(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Center(
      child: SingleChildScrollView(
        child: AuthCard(
          isLogin: isLogin,
          state: state,
          usernameController: usernameController,
          passwordController: passwordController,
          confirmPasswordController: confirmPasswordController,
          onLogin: login,
          onRegister: register,
          onToggle: () {
            setState(() => isLogin = !isLogin);
          },
        ),
      ),
    );
  }
}