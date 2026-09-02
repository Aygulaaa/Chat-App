import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/typing_status.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/user_avatar.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int chatId;
  final String username;
  final bool isOnline;
  final UserModel? otherUser;
  final String? groupAvatar;
  final bool isGroup;
  final bool isContact;
  final bool isBlocked;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;
  final VoidCallback? onAddContact;
  final VoidCallback? onRemoveContact;

  const ChatAppBar({
    super.key,
    required this.chatId,
    required this.username,
    required this.isOnline,
    this.otherUser,
    this.groupAvatar,
    this.isGroup = false,
    this.isContact = false,
    this.isBlocked = false,
    this.onBlock,
    this.onUnblock,
    this.onAddContact,
    this.onRemoveContact,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.appBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: context.textPrimary),
      titleSpacing: 0,
      title: InkWell(
        onTap: () {
          if (isGroup) {
            context.push('/group-profile/$chatId');
          } else {
            context.push('/user-profile', extra: otherUser);
          }
        },
        highlightColor: Colors.transparent,
        splashColor: context.textPrimary.withValues(alpha: 0.05),
        child: Row(
          children: [
            UserAvatar(
              name: username,
              isOnline: isOnline,
              imageUrl: otherUser?.avatar ?? groupAvatar,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  if (otherUser != null)
                    TypingStatusText(
                      chatId: chatId,
                      otherUserId: otherUser!.id,
                      isOnline: isOnline,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!isGroup && otherUser != null)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.textPrimary),
            color: context.appBg,
            onSelected: (value) {
              switch (value) {
                case 'add_contact':
                  onAddContact?.call();
                  break;
                case 'remove_contact':
                  onRemoveContact?.call();
                  break;
                case 'block':
                  onBlock?.call();
                  break;
                case 'unblock':
                  onUnblock?.call();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (!isBlocked) ...[
                if (!isContact)
                  PopupMenuItem<String>(
                    value: 'add_contact',
                    child: Text('Add to contacts', style: TextStyle(color: context.textPrimary)),
                  )
                else
                  PopupMenuItem<String>(
                    value: 'remove_contact',
                    child: Text('Remove from contacts', style: TextStyle(color: context.textPrimary)),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'block',
                  child: Text('Block user', style: TextStyle(color: Colors.redAccent)),
                ),
              ] else
                const PopupMenuItem<String>(
                  value: 'unblock',
                  child: Text('Unblock user', style: TextStyle(color: Colors.green)),
                ),
            ],
          ),
      ],
    );
  }
}