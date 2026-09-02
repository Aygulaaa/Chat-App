import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/avatar_picker_sheet.dart';
import 'package:go_router/go_router.dart';

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
    final currentAvatar =
        ref.read(userProfileProvider).value?.avatar ?? widget.imageUrl;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AvatarPickerSheet(
        hasAvatar: currentAvatar != null,
        onCamera: () async {
          ctx.pop();
          await _pickAndUpload(ImageSource.camera);
        },
        onGallery: () async {
          ctx.pop();
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
      latestUrl =
          ref.watch(userProfileProvider).value?.avatar ?? widget.imageUrl;
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
                colors: [AppColors.primary, AppColors.accent],
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
                          colors: [AppColors.primary, AppColors.accent],
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
                      color: Colors.black.withValues(alpha: 0.5),
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
                    colors: [AppColors.primary, AppColors.accent],
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
                      color: AppColors.primary.withValues(alpha: 0.5),
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


