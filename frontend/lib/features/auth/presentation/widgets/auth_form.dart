import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/widgets/auth_card.dart';
import 'dart:ui';

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
    ref
        .read(authProvider.notifier)
        .login(usernameController.text.trim(), passwordController.text.trim());
  }

  void register() {
    if (passwordController.text != confirmPasswordController.text) return;

    ref
        .read(authProvider.notifier)
        .register(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.darkAuthBg,
        body: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.authBgGradient,
                ),
              ),
            ),

            // Bottom glow effect using brand primary
            Positioned(
              bottom: -100,
              left: 0,
              right: 0,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 0.8,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.4),
                      AppColors.accent.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Glassmorphism blur overlay (subtle)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(color: Colors.transparent),
              ),
            ),

            // Main Auth Card
            Center(
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
            ),
          ],
        ),
      ),
    );
  }
}