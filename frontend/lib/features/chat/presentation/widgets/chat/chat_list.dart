import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/dialog_utils.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/core/utils/snackbar_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/chat_tile.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

class ChatList extends ConsumerWidget {
  const ChatList({super.key});

  void _showChatOptions(BuildContext context, Chat chat, WidgetRef ref) {
    HapticFeedback.selectionClick();

    final currentUserId = ref.read(authProvider).user?.id;
    UserModel? otherUser;
    if (!chat.isGroup) {
      final users = chat.participants.whereType<UserModel>().toList();
      if (users.isNotEmpty) {
        otherUser = users.firstWhere(
          (u) => u.id != currentUserId,
          orElse: () => users.first,
        );
      }
    }
    final title = chat.isGroup
        ? (chat.name ?? 'Group')
        : (otherUser?.username ?? 'Chat');
    final iOwnGroup = chat.isGroup && chat.createdBy == currentUserId;

    showModalBottomSheet(
      context: context,
      // Root navigator → the sheet is above the shell (and its nav bar)…
      useRootNavigator: true,
      // …and an OPAQUE surface. The old background was a 12%-white "glass"
      // color, so the nav bar underneath simply showed through the sheet.
      backgroundColor: context.modalBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1, color: context.border),
            ListTile(
              leading: Icon(
                chat.isMuted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: context.textSecondary,
              ),
              title: Text(
                chat.isMuted ? 'Unmute' : 'Mute',
                style: TextStyle(color: context.textPrimary),
              ),
              onTap: () {
                ref.read(chatProvider.notifier).toggleMute(chat.id);
                Navigator.of(sheetContext).pop();
              },
            ),
            if (otherUser != null)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: const Text(
                  'Block user',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showBlockConfirmation(
                    context,
                    otherUser!.id,
                    otherUser.username,
                    chat.id,
                    ref,
                  );
                },
              ),
            ListTile(
              leading: Icon(
                chat.isGroup && !iOwnGroup
                    ? Icons.logout_rounded
                    : Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: Text(
                !chat.isGroup
                    ? 'Delete chat'
                    : (iOwnGroup ? 'Delete group' : 'Leave group'),
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref, chat, title, iOwnGroup);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Deleting is permanent and affects other people, so say exactly what will
  /// happen — the wording differs for a private chat, your own group, and a
  /// group you are only a member of.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Chat chat,
    String title,
    bool iOwnGroup,
  ) async {
    final String heading;
    final String body;
    final String action;
    if (!chat.isGroup) {
      heading = 'Delete chat with $title?';
      body =
          'The whole conversation will be permanently deleted for both of '
          "you. This can't be undone.";
      action = 'Delete';
    } else if (iOwnGroup) {
      heading = 'Delete "$title"?';
      body =
          'The group and all of its messages will be permanently deleted for '
          "every member. This can't be undone.";
      action = 'Delete group';
    } else {
      heading = 'Leave "$title"?';
      body =
          "You'll stop receiving messages from this group. Someone in the "
          'group can add you back later.';
      action = 'Leave';
    }

    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: heading,
      message: body,
      confirmLabel: action,
      confirmColor: Colors.redAccent,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(chatProvider.notifier).deleteChat(chat.id);
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showSnack(
          context,
          ErrorHandler.getReadableErrorMessage(e),
          isError: true,
        );
      }
    }
  }

  void _showBlockConfirmation(
    BuildContext context,
    int otherUserId,
    String username,
    int chatId,
    WidgetRef ref,
  ) {
    bool deleteChat = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: context.modalBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.glassBorder),
            ),
            title: Text(
              'Block $username?',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to block this user? They will not be able to message you.',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      deleteChat = !deleteChat;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: deleteChat,
                            activeColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setDialogState(() {
                                deleteChat = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Delete chat history',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => dialogContext.pop(),
                child: Text('Cancel',
                    style: TextStyle(color: context.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  dialogContext.pop();
                  await ref
                      .read(contactsProvider.notifier)
                      .blockUser(otherUserId);
                  if (deleteChat) {
                    await ref.read(chatProvider.notifier).deleteChat(chatId);
                  }
                },
                child:
                    const Text('Block', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    final currentUserId = ref.watch(authProvider).user?.id;

    Widget body;

    if (state.isLoading && state.chats.isEmpty) {
      body = Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    } else if (state.error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (state.chats.isEmpty) {
      body = Center(
        child: Text(
          'No conversations yet',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 15.sp,
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          await ref.read(chatProvider.notifier).loadChats();
        },
        color: AppColors.primary,
        backgroundColor: AppColors.darkCard,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 8.h,
          ),
          itemCount: state.chats.length,
          itemBuilder: (context, index) {
            final chat = state.chats[index];
            final isGroup = chat.isGroup;
            final users = chat.participants.whereType<UserModel>().toList();

            UserModel? otherUser;
            if (!isGroup && users.isNotEmpty) {
              otherUser = users.firstWhere(
                (u) => u.id != currentUserId,
                orElse: () => users.first,
              );
            }

            final title = isGroup
                ? (chat.name ?? 'Group')
                : (otherUser?.username ?? 'Unknown');

            final avatar = isGroup ? chat.avatar : otherUser?.avatar;

            final lastMsg = chat.lastMessage;
            final subtitle = lastMsg?.preview ?? 'No messages yet';

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: ChatTile(
                userId: otherUser?.id ?? 0,
                name: title,
                avatarUrl: avatar,
                message: subtitle,
                time: _formatTime(
                  chat.lastMessage?.createdAt,
                ),
                unread: chat.unreadCount > 0,
                unreadCount: chat.unreadCount,
                isMuted: chat.isMuted,
                onTap: () {
                  context.push('/chat/conversation/${chat.id}', extra: title);
                },
                onLongPress: () => _showChatOptions(context, chat, ref),
              ),
            );
          },
        ),
      );
    }

    return SafeArea(
      child: body,
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'now';

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }

    if (diff.inDays == 1) {
      return 'Yesterday';
    }

    if (diff.inDays < 7) {
      const days = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];

      return days[dt.weekday - 1];
    }

    return '${dt.day}/${dt.month}';
  }
}