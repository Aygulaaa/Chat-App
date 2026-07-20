import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message_input.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message_list.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int chatId;
  final String username;

  const ChatScreen({super.key, required this.chatId, required this.username});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatSocketDatasource _socketDataSource;
@override
void initState() {
  super.initState();
  Future.microtask(() async {
    final datasource = ref.read(chatSocketDataSourceProvider);
    await datasource.joinChat(widget.chatId);
    await datasource.markChatAsRead(widget.chatId);
  });
  _socketDataSource = ref.read(chatSocketDataSourceProvider);
}

@override
void dispose() {
  // ✅ Leave the room when screen closes
  _socketDataSource.leaveChat(widget.chatId);
  super.dispose();
}


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageProvider(widget.chatId));

    final chatState = ref.watch(chatProvider);

    final userId = ref.watch(authProvider).user?.id;

    final chats = chatState.chats.where((c) => c.id == widget.chatId).toList();

    if (chats.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF161D2A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final chat = chats.first;

    final bool isGroup = chat.isGroup;

    UserModel? otherUser;
    final users = List<UserModel>.from(chat.participants);

    if (!isGroup && users.isNotEmpty) {
      final filteredUsers = users.where((u) => u.id != userId).toList();

      if (filteredUsers.isNotEmpty) {
        otherUser = filteredUsers.first;
      } else {
        otherUser = users.firstWhere(
          (u) => u.id == userId,
          orElse: () => users.first,
        );
      }
    }

    final typingStatus = ref.watch(
      messageProvider(widget.chatId).select((s) => s.typingStatus),
    );

    final onlineUsers = ref.watch(userStatusProvider).onlineUsers;

    final bool isOnline = otherUser != null
        ? (onlineUsers[otherUser.id] ?? false)
        : false;

    return Scaffold(
      backgroundColor: const Color(0xFF161D2A),

      appBar: ChatAppBar(
        chatId: widget.chatId,
        username: isGroup ? (chat.name ?? 'Group') : widget.username,
        isOnline: isGroup ? false : isOnline,
        otherUser: otherUser,
        groupAvatar: isGroup ? chat.avatar : null,
      ),

      body: Column(
        children: [
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : MessageList(
                    messages: state.messages,
                    userId: userId,
                    isTyping: typingStatus != null,
                  ),
          ),

          MessageInput(chatId: widget.chatId),
        ],
      ),
    );
  }
}
