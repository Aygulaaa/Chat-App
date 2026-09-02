import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/chat_app_bar.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_input.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_list.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

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
    _socketDataSource = ref.read(chatSocketDataSourceProvider);
    Future.microtask(() async {
      _socketDataSource.setActiveChat(widget.chatId);
      await _socketDataSource.joinChat(widget.chatId);
      await _socketDataSource.markChatAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _socketDataSource.setActiveChat(null);
    _socketDataSource.leaveChat(widget.chatId);
    super.dispose();
  }

  void _handleDeleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.modalSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ctx.border),
        ),
        title: Text(
          'Delete message?',
          style: TextStyle(
            color: ctx.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This message will be deleted for everyone.',
          style: TextStyle(
            color: ctx.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: ctx.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              ctx.pop();
              ref
                  .read(messageProvider(widget.chatId).notifier)
                  .deleteMessage(widget.chatId, message.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStickerSend(String emoji) {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch,
      chatId: widget.chatId,
      senderId: user.id,
      text: emoji,
      createdAt: DateTime.now(),
    );
    ref
        .read(messageProvider(widget.chatId).notifier)
        .sendMessageFunction(message);
  }

  void _showBlockConfirmation(
    BuildContext context,
    int otherUserId,
    String username,
  ) {
    bool deleteChat = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: dialogCtx.modalSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: dialogCtx.border),
            ),
            title: Text(
              'Block $username?',
              style: TextStyle(
                color: dialogCtx.textPrimary,
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
                    color: dialogCtx.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
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
                            activeColor: dialogCtx.errorColor,
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
                              color: dialogCtx.textPrimary,
                              fontSize: 14,
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
                onPressed: () => dialogCtx.pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: dialogCtx.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dialogCtx.errorColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  dialogCtx.pop();
                  await ref
                      .read(contactsProvider.notifier)
                      .blockUser(otherUserId);
                  if (deleteChat) {
                    await ref
                        .read(chatProvider.notifier)
                        .deleteChat(widget.chatId);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                },
                child: const Text(
                  'Block',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageProvider(widget.chatId));
    final userId = ref.watch(authProvider).user?.id;

    // Optimized Provider Selectors to prevent extra widget rebuilds
    final chat = ref.watch(
      chatProvider.select(
        (s) => s.chats.cast<dynamic>().firstWhere(
              (c) => c.id == widget.chatId,
              orElse: () => null,
            ),
      ),
    );

    if (chat == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: Center(
          child: CircularProgressIndicator(color: context.primaryColor),
        ),
      );
    }

    final bool isGroup = chat.isGroup;
    final users = List<UserModel>.from(chat.participants);
    
    UserModel? otherUser;
    if (!isGroup && users.isNotEmpty) {
      final filteredUsers = users.where((u) => u.id != userId).toList();
      otherUser = filteredUsers.isNotEmpty ? filteredUsers.first : users.first;
    }

    final isOnline = ref.watch(
      userStatusProvider.select(
        (s) => otherUser != null ? (s.onlineUsers[otherUser.id] ?? false) : false,
      ),
    );

    final isContact = ref.watch(
      contactsProvider.select(
        (asyncVal) =>
            otherUser != null &&
            (asyncVal.value?.any((c) => c.id == otherUser!.id) ?? false),
      ),
    );

    final isBlocked = ref.watch(
      blockedContactsProvider.select(
        (asyncVal) =>
            otherUser != null &&
            (asyncVal.value?.any((c) => c.id == otherUser!.id) ?? false),
      ),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.appBg,
        appBar: ChatAppBar(
          chatId: widget.chatId,
          username: isGroup ? (chat.name ?? 'Group') : widget.username,
          isOnline: isGroup ? false : isOnline,
          otherUser: otherUser,
          groupAvatar: isGroup ? chat.avatar : null,
          isGroup: isGroup,
          isContact: isContact,
          isBlocked: isBlocked,
          onBlock: otherUser != null
              ? () => _showBlockConfirmation(
                    context,
                    otherUser!.id,
                    otherUser.username,
                  )
              : null,
          onUnblock: otherUser != null
              ? () => ref
                    .read(blockedContactsProvider.notifier)
                    .unblock(otherUser!.id)
              : null,
          onAddContact: otherUser != null
              ? () => ref
                    .read(contactsProvider.notifier)
                    .addContact(otherUser!.id)
              : null,
          onRemoveContact: otherUser != null
              ? () => ref
                    .read(contactsProvider.notifier)
                    .removeContact(otherUser!.id)
              : null,
        ),
        body: Container(
          decoration: BoxDecoration(gradient: context.appBgGradient),
          child: Column(
            children: [
              if (!isGroup && otherUser != null && !isContact && !isBlocked)
                Container(
                  width: double.infinity,
                  color: context.cardBg,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'This user is not in your contacts.',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: context.glassBorder),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showBlockConfirmation(
                                context,
                                otherUser!.id,
                                otherUser.username,
                              ),
                              child: Text(
                                'Block User',
                                style: TextStyle(color: context.errorColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: context.glassBorder),
                                ),
                              ),
                              onPressed: () => ref
                                  .read(contactsProvider.notifier)
                                  .addContact(otherUser!.id),
                              child: Text(
                                'Add to Contacts',
                                style: TextStyle(color: context.textPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: state.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.primaryColor,
                        ),
                      )
                    : MessageList(
                        messages: state.messages,
                        userId: userId,
                        isTyping: state.typingStatus != null,
                        typingUserId: state.typingUserId,
                        isGroup: isGroup,
                        participants: users,
                        onDelete: _handleDeleteMessage,
                        onStickerSend: _handleStickerSend,
                      ),
              ),
              MessageInput(chatId: widget.chatId, isBlocked: isBlocked),
            ],
          ),
        ),
      ),
    );
  }
}