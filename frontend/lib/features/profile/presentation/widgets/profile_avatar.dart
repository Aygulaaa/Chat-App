import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';

class ProfileAvatar extends ConsumerStatefulWidget {
  final String username;
  final String? imageUrl;
  final bool isMe;

  const ProfileAvatar({
    super.key,
    required this.username,
    this.imageUrl,
    required this.isMe,
  });

  @override
  ConsumerState<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  bool _isUploading = false;

  Future<void> _showPickerSheet() async {
    final currentAvatar = ref.read(userProfileProvider).valueOrNull?.avatar ?? widget.imageUrl;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AvatarPickerSheet(
        hasAvatar: currentAvatar != null,
        onCamera: () async {
          Navigator.pop(ctx);
          await _pickAndUpload(ImageSource.camera);
        },
        onGallery: () async {
          Navigator.pop(ctx);
          await _pickAndUpload(ImageSource.gallery);
        },
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final XFile? image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      await ref
          .read(userProfileProvider.notifier)
          .updateAvatarFromBytes(bytes, image.name);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? latestUrl;
    if (widget.isMe) {
      latestUrl = ref.watch(userProfileProvider).valueOrNull?.avatar ?? widget.imageUrl;
    } else {
      latestUrl = widget.imageUrl;
    }

    return GestureDetector(
      onTap: widget.isMe && !_isUploading ? _showPickerSheet : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar ring glow
          Container(
            width: 100.r,
            height: 100.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(2.5.r),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: latestUrl != null
                      ? DecorationImage(
                          image: NetworkImage(latestUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  gradient: latestUrl == null
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: latestUrl == null
                    ? Center(
                        child: Text(
                          widget.username[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),

          // Upload spinner overlay
          if (_isUploading)
            Positioned.fill(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5.r,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Camera badge
          if (widget.isMe && !_isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 30.r,
                height: 30.r,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Glassmorphic Picker Sheet ────────────────────────────────────────────────

class _AvatarPickerSheet extends StatelessWidget {
  final bool hasAvatar;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _AvatarPickerSheet({
    required this.hasAvatar,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h + MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8.h),
                // Pill handle
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Choose how to update your photo',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 24.h),

                // Camera option
                _PickerOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
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
                    colors: [Color(0xFF4CC9F0), Color(0xFF818CF8)],
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
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
              ],
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
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                    color: const Color(0xFF6366F1).withOpacity(0.4),
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
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}