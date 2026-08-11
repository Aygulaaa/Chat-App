import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/typing_status.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/user_avatar.dart';
import 'package:my_chat_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:my_chat_app/features/chat/presentation/pages/group_profile_screen.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int chatId;
  final String username;
  final bool isOnline;
  final UserModel? otherUser;
  final String? groupAvatar;
  final bool isGroup;

  const ChatAppBar({
    super.key,
    required this.chatId,
    required this.username,
    required this.isOnline,
    this.otherUser,
    this.groupAvatar,
    this.isGroup = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.darkAppBar,
      titleSpacing: 0,
      title: InkWell(
        onTap: () {
          if (isGroup) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => GroupProfileScreen(chatId: chatId)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: otherUser)));
          }
        },
        child: Row(
          children: [
            UserAvatar(name: username, isOnline: isOnline, imageUrl: otherUser?.avatar ?? groupAvatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  if (otherUser != null)
                    TypingStatusText(chatId: chatId, otherUserId: otherUser!.id, isOnline: isOnline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
