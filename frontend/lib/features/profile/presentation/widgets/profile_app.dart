import 'package:flutter/material.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/utils/format_last_seen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/profile/presentation/pages/edit_profile_screen.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final UserEntity user;
  final bool isMe;

  const ProfileAppBar({super.key, required this.user, required this.isMe});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineUsers = ref.watch(userStatusProvider).onlineUsers;
    final bool isOnline = onlineUsers[user.id] ?? false;
    final userLastSeen = ref.watch(userStatusProvider).lastSeen[user.id];

    return SliverAppBar(
      actions: [
        if (isMe)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.darkTextPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
            ),
          ),
      ],
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.darkCard,
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),

            ProfileAvatar(username: user.username, imageUrl: user.avatar, isMe: isMe),

            const SizedBox(height: 16),

            Text(
              user.username,
              style: const TextStyle(
                color: AppColors.darkTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : (userLastSeen != null ? ' ${TimeUtils.formatLastSeen(userLastSeen)}' : 'Offline'),
                  style: TextStyle(
                    color: isOnline ? AppColors.online : AppColors.darkTextTertiary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}