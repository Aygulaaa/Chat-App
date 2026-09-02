import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/chat_tile.dart';

class SearchChats extends ConsumerWidget {
  final String query;

  const SearchChats({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    final currentUserId = ref.watch(authProvider).user?.id;

    final chats = state.chats;

    final filtered = chats.where((chat) {
      final q = query.toLowerCase();

      final isGroup = chat.isGroup;

      final users = chat.participants.whereType<UserModel>().toList();

      String title = '';
      String lastMsg = chat.lastMessage?.text ?? '';

      if (isGroup) {
        title = (chat.name ?? '').toLowerCase();
      } else {
        final other = users.firstWhere(
          (u) => u.id != currentUserId,
          orElse: () => users.first,
        );
        title = other.username.toLowerCase();
      }

      return title.contains(q) || lastMsg.toLowerCase().contains(q);
    }).toList();

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No chats found',
          style: TextStyle(color: context.textTertiary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final chat = filtered[index];

        final isGroup = chat.isGroup;
        final users = chat.participants.whereType<UserModel>().toList();

        UserModel? other;

        if (!isGroup) {
          other = users.firstWhere(
            (u) => u.id != currentUserId,
            orElse: () => users.first,
          );
        }

        final title = isGroup ? (chat.name ?? 'Group') : other?.username ?? '';
        final avatar = isGroup ? chat.avatar : other?.avatar;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatTile(
            userId: other?.id ?? 0,
            name: title,
            avatarUrl: avatar,
            message: chat.lastMessage?.text ?? 'No messages yet',
            time: '',
            unread: chat.unreadCount > 0,
            unreadCount: chat.unreadCount,
            onTap: () {
              context.push('/chat/conversation/${chat.id}', extra: title);
            },
            onLongPress: () {},
          ),
        );
      },
    );
  }
}