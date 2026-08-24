import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    // Listen to text changes so the button enablement updates dynamically
    usernameController.addListener(_validateForm);
    passwordController.addListener(_validateForm);
    confirmPasswordController.addListener(_validateForm);
  }

  void _validateForm() {
    setState(() {});
  }

  bool get _isFormValid {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      return false;
    }

    if (!isLogin) {
      if (confirmPassword.isEmpty || password != confirmPassword) {
        return false;
      }
    }

    return true;
  }

  void login() {
    if (!_isFormValid) return;
    ref
        .read(authProvider.notifier)
        .login(usernameController.text.trim(), passwordController.text.trim());
  }

  void register() {
    if (!_isFormValid) return;

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
    // Disable form inputs if loading/submitting OR if the button is enabled (as requested)
    final bool isFormDisabled = state.isLoading;

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
              bottom: -100.h,
              left: 0,
              right: 0,
              child: Container(
                height: 400.h,
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
                  // Pass visibility toggles and states to AuthCard if it accepts them,
                  // or manage text field properties inside your AuthCard implementation.
                  obscurePassword: _obscurePassword,
                  obscureConfirmPassword: _obscureConfirmPassword,
                  onTogglePasswordVisibility: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  onToggleConfirmPasswordVisibility: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  isFormValid: _isFormValid,
                  isFormDisabled: isFormDisabled,
                  onLogin: login,
                  onRegister: register,
                  onToggle: () {
                    setState(() {
                      isLogin = !isLogin;
                      usernameController.clear();
                      passwordController.clear();
                      confirmPasswordController.clear();
                    });
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
