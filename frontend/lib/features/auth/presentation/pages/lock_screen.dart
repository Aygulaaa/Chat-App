import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passwordController = TextEditingController();
  final _accountPasswordController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;

  void _unlock() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    final success = ref.read(localAuthProvider.notifier).unlockWithPassword(password);
    if (!success) {
      setState(() {
        _errorText = 'Incorrect local password';
      });
    } else {
      setState(() {
        _errorText = null;
      });
      // Router will automatically redirect based on isLocked state change
    }
  }

  Future<void> _forgotPassword() async {
    showModalBottomSheet(
      context: context,
      // Above the app shell, so the bottom nav bar can't sit on top of it
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20.w,
            right: 20.w,
            top: 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Forgot Local Password?',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Enter your account password to remove the local app lock.',
                style: TextStyle(color: context.textSecondary, fontSize: 14.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: _accountPasswordController,
                obscureText: true,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Account Password',
                  hintStyle: TextStyle(color: context.textTertiary),
                  filled: true,
                  fillColor: context.appBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: Consumer(
                  builder: (context, ref, child) {
                    return ElevatedButton(
                      onPressed: () async {
                        final pwd = _accountPasswordController.text.trim();
                        if (pwd.isEmpty) return;

                        setState(() => _isLoading = true);
                        try {
                          final success = await ref
                              .read(localAuthProvider.notifier)
                              .verifyBackendPassword(pwd);
                          if (success) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            // Local password is removed and app is unlocked.
                            // Router redirects automatically.
                          } else {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Incorrect account password')),
                              );
                            }
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ErrorHandler.getReadableErrorMessage(e),
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Verify & Unlock',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _accountPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 80.r, color: AppColors.primary),
              SizedBox(height: 24.h),
              Text(
                'App Locked',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Enter your local password to continue.',
                style: TextStyle(color: context.textSecondary, fontSize: 14.sp),
              ),
              SizedBox(height: 40.h),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _unlock(),
                style: TextStyle(color: context.textPrimary, fontSize: 16.sp),
                decoration: InputDecoration(
                  hintText: 'Local Password',
                  hintStyle: TextStyle(color: context.textTertiary),
                  filled: true,
                  fillColor: context.cardBg,
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: _unlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Unlock',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: _forgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: AppColors.primary, fontSize: 14.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
