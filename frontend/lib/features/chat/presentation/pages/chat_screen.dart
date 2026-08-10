import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
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
      datasource.setActiveChat(widget.chatId);
      await datasource.joinChat(widget.chatId);
      await datasource.markChatAsRead(widget.chatId);
    });
    _socketDataSource = ref.read(chatSocketDataSourceProvider);
  }

  @override
  void dispose() {
    _socketDataSource.setActiveChat(null);
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
      return Scaffold(
        backgroundColor: context.appBg,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    final chat = chats.first;
    final bool isGroup = chat.isGroup;

    UserModel? otherUser;
    final users = List<UserModel>.from(chat.participants);
    if (!isGroup && users.isNotEmpty) {
      final filteredUsers = users.where((u) => u.id != userId).toList();
      otherUser = filteredUsers.isNotEmpty ? filteredUsers.first : users.first;
    }

    final typingStatus = ref.watch(
      messageProvider(widget.chatId).select((s) => s.typingStatus),
    );
    final onlineUsers = ref.watch(userStatusProvider).onlineUsers;
    final bool isOnline = otherUser != null
        ? (onlineUsers[otherUser.id] ?? false)
        : false;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: ChatAppBar(
        chatId: widget.chatId,
        username: isGroup ? (chat.name ?? 'Group') : widget.username,
        isOnline: isGroup ? false : isOnline,
        otherUser: otherUser,
        groupAvatar: isGroup ? chat.avatar : null,
        isGroup: isGroup,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.appBgGradient),
        child: Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    )
                  : MessageList(
                      messages: state.messages,
                      userId: userId,
                      isTyping: typingStatus != null,
                      typingUserId: state.typingUserId,
                      isGroup: isGroup,
                      participants: users,
                    ),
            ),
            MessageInput(chatId: widget.chatId),
          ],
        ),
      ),
    );
  }
}
