import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/chat_tile.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

class ChatList extends ConsumerWidget {
  const ChatList({super.key});


  void _showChatOptions(BuildContext context, Chat chat, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            const SizedBox(height: 12),

            ListTile(
              leading: Icon(
                chat.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                color: Colors.white70,
              ),
              title: Text(
                chat.isMuted ? 'Unmute' : 'Mute',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                ref.read(chatProvider.notifier).toggleMute(chat.id);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                ref.read(chatProvider.notifier).deleteChat(chat.id);
                Navigator.pop(context);
              },
            ),

            if (!chat.isGroup) ...[
              Builder(builder: (ctx) {
                final users = chat.participants.whereType<UserModel>().toList();
                final currentUserId = ref.read(authProvider).user?.id;
                UserModel? otherUser;
                if (users.isNotEmpty) {
                  otherUser = users.firstWhere(
                    (u) => u.id != currentUserId,
                    orElse: () => users.first,
                  );
                }
                
                if (otherUser != null) {
                  return ListTile(
                    leading: const Icon(
                      Icons.block,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Block user',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close bottom sheet
                      _showBlockConfirmation(context, otherUser!.id, otherUser.username, chat.id, ref);
                    },
                  );
                }
                return const SizedBox.shrink();
              }),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context, int otherUserId, String username, int chatId, WidgetRef ref) {
    bool deleteChat = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: context.cardBg,
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
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: context.textSecondary)),
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
                  final nav = Navigator.of(context);
                  nav.pop();
                  await ref.read(contactsProvider.notifier).blockUser(otherUserId);
                  if (deleteChat) {
                    await ref.read(chatProvider.notifier).deleteChat(chatId);
                  }
                },
                child: const Text('Block', style: TextStyle(color: Colors.white)),
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

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (state.error != null) {
      return Center(
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
    }

    if (state.chats.isEmpty) {
      return Center(
        child: Text(
          'No conversations yet',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 15.sp,
          ),
        ),
      );
    }

    return RefreshIndicator(
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

          final users = chat.participants
              .whereType<UserModel>()
              .toList();

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

          final avatar = isGroup
              ? chat.avatar
              : otherUser?.avatar;

          final lastMsg = chat.lastMessage;
          String subtitle = 'No messages yet';
          if (lastMsg != null) {
            if (lastMsg.fileType == MessageType.audio) {
              subtitle = 'audio message';
            } else if (lastMsg.fileType != MessageType.text) {
              subtitle = lastMsg.originalName ?? 'file';
            } else {
              subtitle = lastMsg.text ?? '';
            }
          }

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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: chat.id,
                      username: title,
                    ),
                  ),
                );
              },

              onLongPress: () =>
                  _showChatOptions(context, chat, ref),
            ),
          );
        },
      ),
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