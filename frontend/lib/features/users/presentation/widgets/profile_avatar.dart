import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_chat_app/features/users/presentation/providers/user_provider.dart';

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

  Future<void> _pickAndUpload() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
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
      onTap: widget.isMe && !_isUploading ? _pickAndUpload : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                width: 2.5,
              ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),

          // Upload spinner overlay
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0B0F14), width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}