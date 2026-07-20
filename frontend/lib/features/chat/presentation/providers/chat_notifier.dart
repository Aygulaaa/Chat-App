import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';

import 'package:my_chat_app/features/chat/data/datasources/chat_remote_datatsources.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';

import 'package:my_chat_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:my_chat_app/features/chat/data/repositories/chat_socket_datasourceImpl.dart';

import 'package:my_chat_app/features/chat/domain/entities/message.dart';

import 'package:my_chat_app/features/chat/domain/usecases/create_chat.dart';
import 'package:my_chat_app/features/chat/domain/usecases/get_chat.dart';
import 'package:my_chat_app/features/chat/domain/usecases/get_chats.dart';
import 'package:my_chat_app/features/chat/domain/usecases/get_messages.dart';
import 'package:my_chat_app/features/chat/domain/usecases/send_message.dart';

import 'package:my_chat_app/features/chat/presentation/providers/chat_state.dart';

/// ───────────────── REMOTE DATASOURCE ─────────────────

final chatRemoteDataSourceProvider = Provider(
  (ref) => ChatRemoteDatatsources(ref.read(apiClientProvider)),
);

/// ───────────────── SOCKET DATASOURCE ─────────────────

final chatSocketDataSourceProvider =
    StateNotifierProvider<SocketNotifier, ChatSocketDatasource>(
      (ref) => SocketNotifier(),
    );

class SocketNotifier extends StateNotifier<ChatSocketDatasource> {
  SocketNotifier() : super(ChatSocketDatasourceImpl());

  @override
  void dispose() {
    state.disconnect();
    super.dispose();
  }
}

/// ───────────────── REPOSITORY ─────────────────

final chatRepositoryProvider = Provider(
  (ref) => ChatRepositoryImpl(
    remote: ref.read(chatRemoteDataSourceProvider),
    socket: ref.watch(chatSocketDataSourceProvider),
  ),
);

/// ───────────────── USECASES ─────────────────

final getChatsProvider = Provider(
  (ref) => GetChats(ref.read(chatRepositoryProvider)),
);

final getChatProvider = Provider(
  (ref) => GetChat(ref.read(chatRepositoryProvider)),
);

final getMessagesProvider = Provider(
  (ref) => GetMessages(ref.read(chatRepositoryProvider)),
);

final sendMessageProvider = Provider(
  (ref) => SendMessage(ref.read(chatRepositoryProvider)),
);

final createChatProvider = Provider(
  (ref) => CreateChat(ref.read(chatRepositoryProvider)),
);

/// ───────────────── CHAT PROVIDER ─────────────────

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    getChats: ref.read(getChatsProvider),
    datasource: ref.read(chatSocketDataSourceProvider),
  );
});

/// ───────────────── CHAT NOTIFIER ─────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final GetChats getChats;

  final ChatSocketDatasource datasource;

  StreamSubscription? _messageSub;
  StreamSubscription? _readSub;
  StreamSubscription? _deliveredSub;

  ChatNotifier({required this.getChats, required this.datasource})
    : super(const ChatState()) {
    _listenSocketEvents();

    loadChats();
  }

  /// ───────────────── SOCKET EVENTS ─────────────────

  void _listenSocketEvents() {
    /// ✅ NEW MESSAGE
    _messageSub = datasource.onMessage().listen((data) {
      try {
        final message = MessageModel.fromJson(data);

        updateChatLastMessage(message);

        print('📨 ChatNotifier received message ${message.id}');
      } catch (e) {
        print('❌ Message parse error: $e');
      }
    });

    /// ✅ READ EVENTS
    _readSub = datasource.onMessagesRead().listen((data) {
      try {
        final int chatId = int.tryParse(data['chatId'].toString()) ?? 0;

        final List<int> messageIds = List<int>.from(data['messageIds'] ?? []);

        final updatedChats = state.chats.map((chat) {
          if (chat.id != chatId) {
            return chat;
          }

          final last = chat.lastMessage;

          return chat.copyWith(
            unreadCount: 0,

            lastMessage: last != null && messageIds.contains(last.id)
                ? last.copyWith(readAt: DateTime.now())
                : last,
          );
        }).toList();

        state = state.copyWith(chats: updatedChats);

        print('👀 Chat $chatId marked read');
      } catch (e) {
        print('❌ Read event error: $e');
      }
    });

    /// ✅ DELIVERED EVENTS
    _deliveredSub = datasource.onMessagesDelivered().listen((data) {
      try {
        final List<int> messageIds = List<int>.from(data['messageIds'] ?? []);

        final updatedChats = state.chats.map((chat) {
          final last = chat.lastMessage;

          if (last != null && messageIds.contains(last.id)) {
            return chat.copyWith(
              lastMessage: last.copyWith(deliveredAt: DateTime.now()),
            );
          }

          return chat;
        }).toList();

        state = state.copyWith(chats: updatedChats);

        print('📦 Messages delivered updated');
      } catch (e) {
        print('❌ Delivery event error: $e');
      }
    });
  }

  /// ───────────────── LOAD CHATS ─────────────────

  Future<void> loadChats() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final chats = await getChats();

      chats.sort((a, b) {
        final aDate = a.lastMessage?.createdAt ?? DateTime(0);

        final bDate = b.lastMessage?.createdAt ?? DateTime(0);

        return bDate.compareTo(aDate);
      });

      state = state.copyWith(chats: chats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// ───────────────── RESET UNREAD ─────────────────

  void resetUnreadCount(int chatId) {
    final updated = state.chats.map((chat) {
      if (chat.id == chatId) {
        return chat.copyWith(unreadCount: 0);
      }

      return chat;
    }).toList();

    state = state.copyWith(chats: updated);
  }

  void updateChatLastMessage(Message message) {
    final updatedChats = state.chats.map((chat) {
      if (chat.id == message.chatId) {
        return chat.copyWith(
          lastMessage: message,
          // ✅ Don't increment here — only increment for incoming messages
          // sendMessageFunction calls this for own messages so unreadCount stays 0
        );
      }
      return chat;
    }).toList();

    updatedChats.sort((a, b) {
      final aDate = a.lastMessage?.createdAt ?? DateTime(0);
      final bDate = b.lastMessage?.createdAt ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    state = state.copyWith(chats: updatedChats);
  }

  void incrementUnreadCount(int chatId) {
    final updatedChats = state.chats.map((chat) {
      if (chat.id == chatId) {
        return chat.copyWith(unreadCount: chat.unreadCount + 1);
      }
      return chat;
    }).toList();
    state = state.copyWith(chats: updatedChats);
  }

  void removeChatFromList(int chatId) {
    state = state.copyWith(
      chats: state.chats.where((c) => c.id != chatId).toList(),
    );
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _readSub?.cancel();
    _deliveredSub?.cancel();

    super.dispose();
  }
}
