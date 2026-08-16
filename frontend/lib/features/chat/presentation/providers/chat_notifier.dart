import 'dart:async';
import 'dart:typed_data';

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
import 'package:my_chat_app/features/chat/presentation/providers/message_notifier.dart';

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
    ref: ref,
  );
});

/// ───────────────── CHAT NOTIFIER ─────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final GetChats getChats;
  final ChatSocketDatasource datasource;
  final Ref ref;

  StreamSubscription? _messageSub;
  StreamSubscription? _readSub;
  StreamSubscription? _deliveredSub;

  ChatNotifier({
    required this.getChats,
    required this.datasource,
    required this.ref,
  }) : super(const ChatState()) {
    _listenSocketEvents();
    loadChats();
  }

  /// ───────────────── SOCKET EVENTS ─────────────────

  void _listenSocketEvents() {
    _messageSub?.cancel();
    /// ✅ NEW MESSAGE
    _messageSub = datasource.onMessage().listen((data) {
      try {
        final message = MessageModel.fromJson(data);
        final myId = ref.read(authProvider).user?.id;

        updateChatLastMessage(message);
        
        if (message.senderId != myId) {
          incrementUnreadCount(message.chatId);
        }

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

      // 🔥 CRITICAL FIX: Initialize messageProvider for each chat
      // This ensures socket listeners are active even when not viewing a chat
      for (final chat in chats) {
        print('🚀 Pre-initializing messageProvider for chatId: ${chat.id}');
        ref.read(messageProvider(chat.id));
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// ───────────────── RESET UNREAD ─────────────────

  void resetUnreadCount(int chatId) {
    print('🧹 resetUnreadCount called for chat $chatId');
    final updated = state.chats.map((chat) {
      if (chat.id == chatId) {
        return chat.copyWith(unreadCount: 0);
      }

      return chat;
    }).toList();

    state = state.copyWith(chats: updated);
  }

  void updateChatLastMessage(Message message) {
    bool chatFound = false;
    
   final updatedChats = state.chats.map((chat) {
      if (chat.id == message.chatId) {
        chatFound = true;
        return chat.copyWith(
          lastMessage: message,
        );
      }
      return chat;
    }).toList();
    if (!chatFound) {
      // 🚨 The chat wasn't in the list yet! Force a reload so it appears with the new message.
      loadChats();
      return;
    }

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
        print("chatId: ${chat.id}, unreadCount: ${chat.unreadCount}");
        return chat.copyWith(unreadCount: chat.unreadCount +1);
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

  Future<void> updateGroupInfo(int chatId, {String? name, Uint8List? avatarBytes, String? filename, String? mimeType}) async {
    try {
      final updatedData = await ref.read(chatRepositoryProvider).updateGroupInfo(
        chatId, 
        name: name, 
        avatarBytes: avatarBytes, 
        filename: filename, 
        mimeType: mimeType
      );
      
      final updatedChats = state.chats.map((chat) {
        if (chat.id == chatId) {
          return chat.copyWith(
            name: updatedData['name'],
            avatar: updatedData['avatar'],
          );
        }
        return chat;
      }).toList();
      state = state.copyWith(chats: updatedChats);
    } catch (e) {
      print('❌ updateGroupInfo error: $e');
      rethrow;
    }
  }

  Future<void> addMember(int chatId, int userId) async {
    try {
      await ref.read(chatRepositoryProvider).addMember(chatId, userId);
      await loadChats(); 
    } catch (e) {
      print('❌ addMember error: $e');
      rethrow;
    }
  }

  Future<void> removeMember(int chatId, int userId) async {
    try {
      await ref.read(chatRepositoryProvider).removeMember(chatId, userId);
      await loadChats();
    } catch (e) {
      print('❌ removeMember error: $e');
      rethrow;
    }
  }

  Future<void> deleteChat(int chatId) async {
    try {
      await ref.read(chatRepositoryProvider).deleteChat(chatId);
      removeChatFromList(chatId);
    } catch (e) {
      print('❌ deleteChat error: $e');
      rethrow;
    }
  }

  void toggleMute(int chatId) {
    final updatedChats = state.chats.map((chat) {
      if (chat.id == chatId) {
        return chat.copyWith(isMuted: !chat.isMuted);
      }
      return chat;
    }).toList();
    state = state.copyWith(chats: updatedChats);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _readSub?.cancel();
    _deliveredSub?.cancel();

    super.dispose();
  }
}