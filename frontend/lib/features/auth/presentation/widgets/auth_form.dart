import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
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

  final usernameFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();
  final confirmPasswordFocusNode = FocusNode();

  Timer? _errorTimer;

  bool isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();

    usernameController.addListener(_onFieldChanged);
    passwordController.addListener(_onFieldChanged);
    confirmPasswordController.addListener(_onFieldChanged);

    usernameFocusNode.addListener(_onFocusChanged);
    passwordFocusNode.addListener(_onFocusChanged);
    confirmPasswordFocusNode.addListener(_onFocusChanged);
  }

  void _startErrorTimer() {
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 10), () {
      _clearErrorIfPresent();
    });
  }

  void _onFieldChanged() {
    _clearErrorIfPresent();
    setState(() {}); // Re-evaluates form validity for button state
  }

  void _onFocusChanged() {
    if (usernameFocusNode.hasFocus ||
        passwordFocusNode.hasFocus ||
        confirmPasswordFocusNode.hasFocus) {
      _clearErrorIfPresent();
    }
  }

  void _clearErrorIfPresent() {
    _errorTimer?.cancel();
    if (ref.read(authProvider).error != null) {
      ref.read(authProvider.notifier).clearError();
    }
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
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).login(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
  }

  void register() {
    if (!_isFormValid) return;
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).register(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
  }

  @override
  void dispose() {
    _errorTimer?.cancel();

    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        _startErrorTimer();
      }
    });

    final state = ref.watch(authProvider);

    String? readableErrorMessage;
    if (state.error != null) {
      readableErrorMessage = ErrorHandler.getReadableErrorMessage(state.error);
    }

    final bool isFormDisabled = state.isLoading;
    final bool hasError = readableErrorMessage != null && readableErrorMessage.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: context.authBgGradient,
                ),
              ),
            ),

            // Glow effect
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

            // Backdrop blur layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const SizedBox.expand(),
              ),
            ),

            // Form Content
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: hasError ? 80.h : 0),
                child: AuthCard(
                  isLogin: isLogin,
                  state: state,
                  usernameController: usernameController,
                  passwordController: passwordController,
                  confirmPasswordController: confirmPasswordController,
                  usernameFocusNode: usernameFocusNode,
                  passwordFocusNode: passwordFocusNode,
                  confirmPasswordFocusNode: confirmPasswordFocusNode,
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
                    _clearErrorIfPresent();
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

            // Error Floating Snackbar
            Positioned(
              left: 20.w,
              right: 20.w,
              bottom: 24.h,
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: hasError
                      ? Container(
                          key: ValueKey(readableErrorMessage),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.white,
                                size: 22.sp,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  readableErrorMessage,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}