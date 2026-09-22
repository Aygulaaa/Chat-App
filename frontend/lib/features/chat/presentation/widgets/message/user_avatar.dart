import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isOnline;
  final double size;

  /// What the online dot's ring is cut out of. Defaults to the page
  /// background; pass the real surface colour when the avatar sits on one.
  final Color? ringColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    required this.isOnline,
    this.size = 48,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: hasImage ? null : AppColors.primaryGradient,
            ),
            child: hasImage
                ? null
                : Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: size * 0.4,
                      ),
                    ),
                  ),
          ),

          // A plain dot punched out of the background. No glow: the ring is
          // what separates it from the photo, so the colour can stay calm.
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.24,
                height: size * 0.24,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor ?? context.appBg,
                    width: size * 0.045,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
