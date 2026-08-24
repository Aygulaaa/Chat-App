import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class AvatarPickerSheet extends StatelessWidget {
  final bool hasAvatar;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const AvatarPickerSheet({
    required this.hasAvatar,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppColors.darkBorder, width: 1),
            ),
            child: Padding(
              padding: .all(8.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8.h),
                  // Pill handle
                  Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.darkBorder,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Profile Photo',
                    style: TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Choose how to update your photo',
                    style: TextStyle(
                      color: AppColors.darkTextTertiary,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 24.h),
              
                  // Camera option
                  _PickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take Photo',
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: onCamera,
                  ),
                  SizedBox(height: 10.h),
              
                  // Gallery option
                  _PickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Choose from Gallery',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CC9F0), AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: onGallery,
                  ),
                  SizedBox(height: 16.h),
              
                  // Cancel
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      margin: EdgeInsets.symmetric(horizontal: 0),
                      decoration: BoxDecoration(
                        color: AppColors.darkInputFill,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Text(
                        'Cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.darkInputFill,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.darkTextPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.darkTextTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

