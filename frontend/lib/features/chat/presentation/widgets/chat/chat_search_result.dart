import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_chat_app/core/theme/app_colors.dart'; // Make sure to import your AppColors file
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';

import 'package:my_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/chat_tile.dart';

class ChatSearchResults extends ConsumerWidget {
  final String query;

  const ChatSearchResults({
    super.key,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);

    final currentUserId = ref.watch(authProvider).user?.id;

    final filteredChats = state.chats.where((chat) {
      final q = query.toLowerCase();

      final users = chat.participants.whereType<UserModel>().toList();

      String title = '';

      if (chat.isGroup) {
        title = (chat.name ?? '').toLowerCase();
      } else {
        final otherUser = users.isNotEmpty
            ? users.firstWhere(
                (u) => u.id != currentUserId,
                orElse: () => users[0],
              )
            : null;

        title = (otherUser?.username ?? '').toLowerCase();
      }

      final lastMessage = (chat.lastMessage?.text ?? '').toLowerCase();

      return title.contains(q) || lastMessage.contains(q);
    }).toList();

    if (query.trim().isEmpty) {
      return const Center(
        child: Text(
          'Search your conversations',
          style: TextStyle(
            color: AppColors.darkTextTertiary, // Updated to AppColors
          ),
        ),
      );
    }

    if (filteredChats.isEmpty) {
      return const Center(
        child: Text(
          'No chats found',
          style: TextStyle(
            color: AppColors.darkTextTertiary, // Updated to AppColors
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      itemCount: filteredChats.length,
      itemBuilder: (_, index) {
        final chat = filteredChats[index];

        final users = chat.participants.whereType<UserModel>().toList();

        UserModel? otherUser;

        if (!chat.isGroup && users.isNotEmpty) {
          otherUser = users.firstWhere(
            (u) => u.id != currentUserId,
            orElse: () => users[0],
          );
        }

        final title = chat.isGroup
            ? (chat.name ?? 'Group')
            : (otherUser?.username ?? 'Unknown');

        final avatar = chat.isGroup ? chat.avatar : otherUser?.avatar;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatTile(
            userId: otherUser?.id ?? 0,
            name: title,
            avatarUrl: avatar,
            message: chat.lastMessage?.text ?? 'No messages yet',
            time: '',
            unread: chat.unreadCount > 0,
            unreadCount: chat.unreadCount,
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
            onLongPress: () {},
          ),
        );
      },
    );
  }
}