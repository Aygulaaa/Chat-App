import 'package:flutter/material.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/typing_status.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/user_avatar.dart';
import 'package:my_chat_app/features/users/presentation/pages/profile_screen.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int chatId;
  final String username;
  final bool isOnline;
  final UserModel? otherUser;
  final String? groupAvatar;

  const ChatAppBar({
    super.key,
    required this.chatId,
    required this.username,
    required this.isOnline, 
    this.otherUser,
    this.groupAvatar
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF161D2A),
      titleSpacing: 0,
      title: InkWell(
        onTap: (){
          Navigator.push(context, MaterialPageRoute(builder: (_)=> ProfileScreen(user:otherUser)));
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
                  if(otherUser != null)
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