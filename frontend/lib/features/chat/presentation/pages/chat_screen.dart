import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
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
      // Set active chat FIRST so incoming messages auto-trigger read
      _socketDataSource.setActiveChat(widget.chatId);
      // Join must complete before read so the socket room is ready
      await _socketDataSource.joinChat(widget.chatId);
      // Now safe to mark as read — socket is connected and room is joined
      await _socketDataSource.markChatAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _socketDataSource.setActiveChat(null);
    _socketDataSource.leaveChat(widget.chatId);
    super.dispose();
  }

  void _showBlockConfirmation(
    BuildContext context,
    int otherUserId,
    String username,
  ) {
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
                  nav.pop(); // Close dialog
                  // Block the user
                  await ref.read(contactsProvider.notifier).blockUser(otherUserId);
                  if (deleteChat) {
                    // Delete the chat and go back
                    await ref.read(chatProvider.notifier).deleteChat(widget.chatId);
                    if (mounted) {
                      nav.pop(); // Go back to home screen
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
    final chatState = ref.watch(chatProvider);
    final userId = ref.watch(authProvider).user?.id;

    final chats = chatState.chats.where((c) => c.id == widget.chatId).toList();
    if (chats.isEmpty) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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

    // Contact and block status
    final contacts = ref.watch(contactsProvider).valueOrNull ?? [];
    final blockedContacts =
        ref.watch(blockedContactsProvider).valueOrNull ?? [];

    final bool isContact =
        otherUser != null && contacts.any((c) => c.id == otherUser!.id);
    final bool isBlocked =
        otherUser != null && blockedContacts.any((c) => c.id == otherUser!.id);

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
                              child: const Text(
                                'Block User',
                                style: TextStyle(color: Colors.redAccent),
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
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
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
              MessageInput(chatId: widget.chatId, isBlocked: isBlocked),
            ],
          ),
        ),
      ),
    );
  }
}
