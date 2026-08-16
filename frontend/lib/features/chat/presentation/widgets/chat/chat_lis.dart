import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/chat_tile.dart';

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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
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

            const SizedBox(height: 8),
          ],
        ),
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
      return const Center(
        child: Text(
          'No conversations yet',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 15,
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

        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
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
            padding: const EdgeInsets.only(bottom: 8),

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