import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';


class ProfileHeaderImage extends StatelessWidget {
  final String? avatarUrl;
  final String? fallbackName;
  final String chatName;
  final int memberCount;
  final bool isUploading;
  final VoidCallback onCameraTap;
  final VoidCallback onAddMemberTap;
  final VoidCallback onEditNameTap;

  const ProfileHeaderImage({
    super.key,
    required this.avatarUrl,
    required this.fallbackName,
    required this.chatName,
    required this.memberCount,
    required this.isUploading,
    required this.onCameraTap,
    required this.onAddMemberTap,
    required this.onEditNameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background Image or Gradient Fallback
        if (avatarUrl != null)
          Image.network(avatarUrl!, fit: BoxFit.cover)
        else
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Center(
              child: Text(
                fallbackName != null && fallbackName!.isNotEmpty
                    ? fallbackName![0].toUpperCase()
                    : 'G',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 72.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // 2. Scrim Gradient Overlay for Text Legibility
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),

        // 3. Name, Member Count & Action Row Overlaid on the Image
        Positioned(
          left: 16.w,
          right: 16.w,
          bottom: 24.h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group Name with Shadow
              Text(
                chatName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),

              // Member Count with Shadow
              Text(
                '$memberCount members',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // Action Buttons Row (Camera, Add Member, Edit Name)
              Row(
                children: [
                  // Change Photo Button
                  _TelegramActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Change Photo',
                    isLoading: isUploading,
                    onTap: isUploading ? null : onCameraTap,
                  ),
                  SizedBox(width: 8.w),

                  // Add Member Button
                  _TelegramActionButton(
                    icon: Icons.person_add_rounded,
                    label: 'Add Member',
                    onTap: onAddMemberTap,
                  ),
                  SizedBox(width: 8.w),

                  // Edit Name Button
                  _TelegramActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onTap: onEditNameTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Helper Widget: Telegram-style glassmorphic action button overlay
class _TelegramActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _TelegramActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 14.r,
                height: 14.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 14.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
