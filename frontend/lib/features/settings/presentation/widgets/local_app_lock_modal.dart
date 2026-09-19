import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class LocalAppLockModal extends ConsumerStatefulWidget {
  const LocalAppLockModal({super.key});

  @override
  ConsumerState<LocalAppLockModal> createState() => _LocalAppLockModalState();
}

class _LocalAppLockModalState extends ConsumerState<LocalAppLockModal> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void _savePassword() {
    final pwd = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (pwd.isEmpty || pwd.length < 4) {
      _showError('Password must be at least 4 characters');
      return;
    }

    if (pwd != confirm) {
      _showError('Passwords do not match');
      return;
    }

    ref.read(localAuthProvider.notifier).setLocalPassword(pwd);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local App Lock enabled')),
    );
  }

  void _removePassword() {
    ref.read(localAuthProvider.notifier).removeLocalPassword();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local App Lock disabled')),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localAuthState = ref.watch(localAuthProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20.w,
        right: 20.w,
        top: 24.h,
      ),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: context.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            localAuthState.isPasswordSet ? 'Change App Lock Password' : 'Set App Lock Password',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'This password will be required when launching the app.',
            style: TextStyle(color: context.textSecondary, fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),

          TextField(
            controller: _passwordController,
            obscureText: true,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'New Password',
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.appBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Confirm Password',
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
            child: ElevatedButton(
              onPressed: _savePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save Password',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          if (localAuthState.isPasswordSet) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: TextButton(
                onPressed: _removePassword,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Remove App Lock',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
