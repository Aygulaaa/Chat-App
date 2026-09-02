import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';

class AuthCard extends StatelessWidget {
  final bool isLogin;
  final AuthState state;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final FocusNode usernameFocusNode;
  final FocusNode passwordFocusNode;
  final FocusNode confirmPasswordFocusNode;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onToggle;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final bool isFormValid;
  final bool isFormDisabled;

  const AuthCard({
    super.key,
    required this.isLogin,
    required this.state,
    required this.usernameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.usernameFocusNode,
    required this.passwordFocusNode,
    required this.confirmPasswordFocusNode,
    required this.onLogin,
    required this.onRegister,
    required this.onToggle,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.isFormValid,
    required this.isFormDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(
          color: context.glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isLight ? 0.1 : 0.5),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLogin ? "Welcome Back!" : "Create Account",
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: 28.h),

          _AuthTextField(
            controller: usernameController,
            focusNode: usernameFocusNode,
            label: "Username",
            hint: "Enter your username",
            icon: Icons.alternate_email_rounded,
            enabled: !isFormDisabled,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: 16.h),
          
          _AuthTextField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            label: "Password",
            hint: "Enter your password",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: obscurePassword,
            onToggleVisibility: onTogglePasswordVisibility,
            enabled: !isFormDisabled,
            textInputAction: isLogin ? TextInputAction.done : TextInputAction.next,
            onSubmitted: isLogin ? (_) => onLogin() : null,
          ),

          if (!isLogin) ...[
            SizedBox(height: 16.h),
            _AuthTextField(
              controller: confirmPasswordController,
              focusNode: confirmPasswordFocusNode,
              label: "Confirm Password",
              hint: "Re-enter your password",
              icon: Icons.shield_outlined,
              isPassword: true,
              obscureText: obscureConfirmPassword,
              onToggleVisibility: onToggleConfirmPasswordVisibility,
              enabled: !isFormDisabled,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onRegister(),
            ),
          ],

          SizedBox(height: 28.h),

          state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                )
              : Container(
                  width: double.infinity,
                  height: 52.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    gradient: isFormValid ? AppColors.primaryGradient : null,
                    color: isFormValid ? null : Colors.grey.withValues(alpha: 0.2),
                    boxShadow: isFormValid
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: isFormValid ? (isLogin ? onLogin : onRegister) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      disabledBackgroundColor: Colors.transparent,
                    ),
                    child: Text(
                      isLogin ? "Login" : "Get Started",
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: isFormValid ? Colors.white : context.textSecondary,
                      ),
                    ),
                  ),
                ),

          SizedBox(height: 20.h),

          Center(
            child: TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                foregroundColor: context.textSecondary,
              ),
              child: RichText(
                text: TextSpan(
                  text: isLogin ? "Don't have an account? " : "Already have an account? ",
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13.sp,
                  ),
                  children: [
                    TextSpan(
                      text: isLogin ? "Sign Up" : "Log in",
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _AuthTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required IconData this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleVisibility,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword ? obscureText : false,
          enabled: enabled,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: TextStyle(
            color: enabled ? context.textPrimary : context.textSecondary,
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.textTertiary, fontSize: 14.sp),
            prefixIcon: Icon(icon, size: 20.sp, color: AppColors.primary),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: context.textSecondary,
                      size: 20.sp,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: context.inputFill,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: context.border,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}