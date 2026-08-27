import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';

class AuthCard extends StatelessWidget {
  final bool isLogin;
  final AuthState state;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onToggle;
  
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final bool isFormValid;
  final bool isFormDisabled;
  final String? errorMessage; // Human-readable error message passed from AuthForm

  const AuthCard({
    super.key,
    required this.isLogin,
    required this.state,
    required this.usernameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onLogin,
    required this.onRegister,
    required this.onToggle,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.isFormValid,
    required this.isFormDisabled,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main Auth Card Container (Glassmorphism)
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 24.w),
                  padding: EdgeInsets.all(32.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(32.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
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
                          color: Colors.white,
                        ),
                      ),
                      
                      SizedBox(height: 28.h),

                      _buildTextField(
                        controller: usernameController,
                        label: "Username",
                        hint: "Enter your username",
                        icon: Icons.alternate_email_rounded,
                        enabled: !isFormDisabled,
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField(
                        controller: passwordController,
                        label: "Password",
                        hint: "Enter your password",
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: obscurePassword,
                        onToggleVisibility: onTogglePasswordVisibility,
                        enabled: !isFormDisabled,
                      ),

                      if (!isLogin) ...[
                        SizedBox(height: 16.h),
                        _buildTextField(
                          controller: confirmPasswordController,
                          label: "Confirm Password",
                          hint: "Re-enter your password",
                          icon: Icons.shield_outlined,
                          isPassword: true,
                          obscureText: obscureConfirmPassword,
                          onToggleVisibility: onToggleConfirmPasswordVisibility,
                          enabled: !isFormDisabled,
                        ),
                      ],

                      SizedBox(height: 28.h),

                      // Gradient Button (primary → accent)
                      state.isLoading
                          ? Center(
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
                                boxShadow: isFormValid ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ] : [],
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
                                    color: isFormValid ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),

                      // Inline Human-Readable Error Banner at bottom of Card
                      if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 20.h),

                      // Toggle Button
                      Center(
                        child: TextButton(
                          onPressed: onToggle,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[400],
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: isLogin
                                  ? "Don't have an account? "
                                  : "Already have an account? ",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13.sp,
                              ),
                              children: [
                                TextSpan(
                                  text: isLogin ? "Sign Up" : "Log in",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          obscureText: isPassword ? obscureText : false,
          enabled: enabled,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey[400],
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
            prefixIcon: Icon(icon, size: 20.sp, color: AppColors.primary),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey[400],
                      size: 20.sp,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: AppColors.darkInputFill,
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
                color: Colors.white.withValues(alpha: 0.05),
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
                color: Colors.white.withValues(alpha: 0.02),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}