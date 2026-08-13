import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/user_avatar.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/user_action_sheet.dart';

class ContactTile extends ConsumerWidget {
  final Contact contact;

  const ContactTile({super.key, required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineUsers = ref.watch(userStatusProvider).onlineUsers;
    final isOnline = onlineUsers[contact.id] ?? false;

    return InkWell(
      onTap: () => showUserActionSheet(context, contact),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  name: contact.username,
                  isOnline: isOnline,
                  imageUrl: contact.avatar,
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.username,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.isBlocked
                        ? 'Blocked'
                        : isOnline
                            ? 'Online'
                            : contact.bio ?? 'No bio',
                    style: TextStyle(
                      color: contact.isBlocked
                          ? AppColors.error.withValues(alpha: 0.7)
                          : isOnline
                              ? AppColors.online
                              : context.textTertiary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.glassBorder,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}