import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/network/fcm_service.dart';
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
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';


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
  StreamSubscription? _groupDeletedSub;

  /// Cached set of user IDs blocked by the current user.
  /// Populated eagerly before socket listeners start.
  final Set<int> _blockedUserIds = {};

  ChatNotifier({
    required this.getChats,
    required this.datasource,
    required this.ref,
  }) : super(const ChatState()) {
    _initBlocked();
  }

  /// Load blocked IDs FIRST, then start socket + load chats.
  Future<void> _initBlocked() async {
    try {
      final blocked = await ref.read(blockedContactsProvider.future);
      _blockedUserIds.addAll(blocked.map((c) => c.id));
      print('🚫 Loaded ${_blockedUserIds.length} blocked user IDs');
    } catch (_) {
      // If it fails, proceed with an empty set — backend is the safety net.
    }

    // Auto-refresh the cached set whenever the provider is invalidated
    // (e.g. after block/unblock actions).
    ref.listen<AsyncValue<List<dynamic>>>(blockedContactsProvider, (_, next) {
      next.whenData((blocked) {
        _blockedUserIds
          ..clear()
          ..addAll(blocked.map((c) => c.id));
        print('🔄 Auto-refreshed blocked IDs: $_blockedUserIds');
      });
    });

    _listenSocketEvents();
    loadChats();
  }

  /// Public method — can also be called manually if needed.
  void refreshBlockedIds() {
    ref
        .read(blockedContactsProvider.future)
        .then((blocked) {
          _blockedUserIds
            ..clear()
            ..addAll(blocked.map((c) => c.id));
          print('🔄 Refreshed blocked IDs: $_blockedUserIds');
        })
        .catchError((_) {});
  }

  /// ───────────────── SOCKET EVENTS ─────────────────

  void _listenSocketEvents() {
    _messageSub?.cancel();

    /// ✅ NEW MESSAGE
    _messageSub = datasource.onMessage().listen((data) {
      try {
        final message = MessageModel.fromJson(data);
        final myId = ref.read(authProvider).user?.id;

        // ── Block filter ──────────────────────────────────────────
        // Reject messages from anyone in the blocked set (bidirectional
        // — backend also enforces this, frontend is an extra guard).
        if (message.senderId != myId &&
            _blockedUserIds.contains(message.senderId)) {
          print(
            '🚫 ChatNotifier: dropped msg from blocked ${message.senderId}',
          );
          return;
        }
        // ──────────────────────────────────────────────────────────

        updateChatLastMessage(message);

        if (message.senderId != myId) {
          incrementUnreadCount(message.chatId);

          if (datasource.activeChatId != message.chatId) {
            bool isMuted = false;
            String title = 'New Message';

            for (var c in state.chats) {
              if (c.id == message.chatId) {
                isMuted = c.isMuted;
                title = c.isGroup
                    ? (c.name ?? 'Group Message')
                    : (c.name ?? 'New Message');
                break;
              }
            }

            if (!isMuted) {
              final msgText = message.text?.isNotEmpty == true
                  ? message.text!
                  : '📎 Attachment';

              // ── In-app glassmorphic popup (only visible while app is open) ──
              showOverlay(
                (context, progress) => Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      onTap: () => OverlaySupportEntry.of(context)?.dismiss(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: AnimatedOpacity(
                            opacity: progress,
                            duration: const Duration(milliseconds: 250),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xCC1C1733),
                                    Color(0xBB171326),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: AppColors.accent.withOpacity(0.25),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.28),
                                    blurRadius: 24,
                                    spreadRadius: -4,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Glowing avatar circle
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.accent,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withOpacity(0.5),
                                          blurRadius: 12,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.message_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Sender name + message body
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            letterSpacing: 0.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          msgText,
                                          style: TextStyle(
                                            color: AppColors.darkTextSecondary
                                                .withOpacity(0.9),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Dismiss chevron
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      color: AppColors.accent.withOpacity(0.6),
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                duration: const Duration(seconds: 4),
              );
            }
          }
        }

        print('📨 ChatNotifier received message ${message.id}');
      } catch (e) {
        print('❌ Message parse error: $e');
      }
    });

    /// ✅ READ EVENTS
    _readSub = datasource.onMessagesRead().listen((data) {
      try {
        final int chatId = int.tryParse(data['chatId']?.toString() ?? '') ?? 0;
        if (chatId == 0) return;

        final List<int> messageIds = (data['messageIds'] as List? ?? [])
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();

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
        final List<int> messageIds = (data['messageIds'] as List? ?? [])
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();

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

    /// ✅ GROUP DELETED (for non-creator members)
    _groupDeletedSub?.cancel();
    _groupDeletedSub = datasource.onGroupDeleted().listen((deletedChatId) {
      print('🗑️ ChatNotifier: group_deleted for chatId=$deletedChatId');
      removeChatFromList(deletedChatId);
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
        return chat.copyWith(lastMessage: message);
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

  Future<void> updateGroupInfo(
    int chatId, {
    String? name,
    Uint8List? avatarBytes,
    String? filename,
    String? mimeType,
  }) async {
    try {
      final updatedData = await ref
          .read(chatRepositoryProvider)
          .updateGroupInfo(
            chatId,
            name: name,
            avatarBytes: avatarBytes,
            filename: filename,
            mimeType: mimeType,
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

  Future<void> deleteGroup(int chatId) async {
    try {
      await ref.read(chatRepositoryProvider).deleteGroup(chatId);
      // Remove locally for the creator immediately;
      // other members are removed via the group_deleted socket event
      removeChatFromList(chatId);
    } catch (e) {
      print('❌ deleteGroup error: $e');
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
    _groupDeletedSub?.cancel();

    super.dispose();
  }
}
