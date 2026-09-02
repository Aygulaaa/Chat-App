import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/models/chat_model.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_state.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

part 'chat_notifier.g.dart';

// -----------------------------------------------------------------------------
// Presentation Layer — Chat Notifier
// -----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class ChatNotifier extends _$ChatNotifier {
  StreamSubscription? _messageSub;
  StreamSubscription? _readSub;
  StreamSubscription? _deliveredSub;
  StreamSubscription? _groupDeletedSub;

  final Set<int> _blockedUserIds = {};

  @override
  ChatState build() {
    ref.onDispose(() {
      _cancelSubscriptions();
    });

    Future.microtask(() => _initBlocked());

    // Load cached chats synchronously so UI never starts empty
    if (Hive.isBoxOpen('chats_cache')) {
      try {
        final box = Hive.box<String>('chats_cache');
        final cachedStr = box.get('all_chats');
        if (cachedStr != null) {
          final List<dynamic> decoded = jsonDecode(cachedStr);
          final cachedChats = decoded
              .map((e) => ChatModel.fromJson(e))
              .toList();
          cachedChats.sort((a, b) {
            final aDate = a.lastMessage?.createdAt ?? DateTime(0);
            final bDate = b.lastMessage?.createdAt ?? DateTime(0);
            return bDate.compareTo(aDate);
          });
          if (cachedChats.isNotEmpty) {
            return ChatState(chats: cachedChats);
          }
        }
      } catch (_) {}
    }

    return const ChatState();
  }

  void _cancelSubscriptions() {
    _messageSub?.cancel();
    _readSub?.cancel();
    _deliveredSub?.cancel();
    _groupDeletedSub?.cancel();
  }

  /// Centralized cache helper to ensure Hive stays perfectly synced with `state`
  Future<void> _persistCache() async {
    try {
      if (!Hive.isBoxOpen('chats_cache')) return;
      final box = Hive.box<String>('chats_cache');
      final toCache = state.chats
          .whereType<ChatModel>()
          .map((e) => e.toJson())
          .toList();
      await box.put('all_chats', jsonEncode(toCache));
    } catch (_) {}
  }

Future<void> _initBlocked() async {
    try {
      final blocked = await ref.read(blockedContactsProvider.future);
      if (!ref.mounted) return;
      _blockedUserIds.addAll(blocked.map((c) => c.id));
    } catch (_) {}

    if (!ref.mounted) return;

    ref.listen<AsyncValue<List<dynamic>>>(blockedContactsProvider, (_, next) {
      if (!ref.mounted) return;
      next.whenData((blocked) {
        final newBlockedIds = blocked.map((c) => c.id as int).toSet();
        
        // Check if any user was unblocked (was in old set, absent in new set)
        final bool someoneWasUnblocked = _blockedUserIds.any((id) => !newBlockedIds.contains(id));

        _blockedUserIds
          ..clear()
          ..addAll(newBlockedIds);

        // Force a chat reload to fetch history/messages missed during the block
        if (someoneWasUnblocked) {
          loadChats();
        }
      });
    });

    _listenSocketEvents();
    loadChats();
  }

  void refreshBlockedIds() {
    ref
        .read(blockedContactsProvider.future)
        .then((blocked) {
          if (!ref.mounted) return;
          _blockedUserIds
            ..clear()
            ..addAll(blocked.map((c) => c.id));
        })
        .catchError((_) {});
  }

  // ─────────────────────────── SOCKET EVENTS ───────────────────────────────

  void _listenSocketEvents() {
    final datasource = ref.read(chatSocketDataSourceProvider);

    _cancelSubscriptions();

    _messageSub = datasource.onMessage().listen((data) {
      if (!ref.mounted) return;
      try {
        final message = MessageModel.fromJson(data);
        final myId = ref.read(authProvider).user?.id;

        if (message.senderId != myId &&
            _blockedUserIds.contains(message.senderId)) {
          return;
        }
        print("message sender id  $message");
        print("my id: $myId");

        if (message.senderId != myId) {
          datasource.emitMessageReceived(message.id);
        }

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
                                          color: AppColors.primary.withOpacity(
                                            0.5,
                                          ),
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
      } catch (_) {}
    });

    /// ✅ READ EVENTS
    _readSub = datasource.onMessagesRead().listen((data) {
      if (!ref.mounted) return;
      try {
        final rawChatId = data['chatId'] ?? data['chat_id'];
        final int chatId = int.tryParse(rawChatId?.toString() ?? '') ?? 0;
        if (chatId == 0) return;

        final List<int> messageIds = (data['messageIds'] as List? ?? [])
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();

        final updatedChats = state.chats.map((chat) {
          if (chat.id != chatId) return chat;

          final last = chat.lastMessage;
          final bool isLastMessageRead =
              last != null &&
              (messageIds.isEmpty || messageIds.contains(last.id));

          return chat.copyWith(
            unreadCount: 0,
            lastMessage: isLastMessageRead
                ? last.copyWith(readAt: last.readAt ?? DateTime.now())
                : last,
          );
        }).toList();

        state = state.copyWith(chats: updatedChats);
        _persistCache();
      } catch (_) {}
    });

    /// ✅ DELIVERED EVENTS
    _deliveredSub = datasource.onMessagesDelivered().listen((data) {
      if (!ref.mounted) return;
      try {
        final List<int> messageIds = (data['messageIds'] as List? ?? [])
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();

        if (messageIds.isEmpty) return;

        final updatedChats = state.chats.map((chat) {
          final last = chat.lastMessage;
          if (last != null && messageIds.contains(last.id)) {
            return chat.copyWith(
              lastMessage: last.copyWith(
                deliveredAt: last.deliveredAt ?? DateTime.now(),
              ),
            );
          }
          return chat;
        }).toList();

        state = state.copyWith(chats: updatedChats);
        _persistCache();
      } catch (_) {}
    });

    /// ✅ GROUP DELETED
    _groupDeletedSub = datasource.onGroupDeleted().listen((deletedChatId) {
      if (!ref.mounted) return;
      removeChatFromList(deletedChatId);
    });
  }

  // ─────────────────────────── LOAD CHATS ──────────────────────────────────

  Future<void> loadChats() async {
    bool hasCache = false;
    if (Hive.isBoxOpen('chats_cache')) {
      final box = Hive.box<String>('chats_cache');
      final cachedStr = box.get('all_chats');
      if (cachedStr != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedStr);
          final cachedChats = decoded
              .map((e) => ChatModel.fromJson(e))
              .toList();
          cachedChats.sort((a, b) {
            final aDate = a.lastMessage?.createdAt ?? DateTime(0);
            final bDate = b.lastMessage?.createdAt ?? DateTime(0);
            return bDate.compareTo(aDate);
          });
          if (cachedChats.isNotEmpty) {
            hasCache = true;
            if (ref.mounted) {
              state = state.copyWith(
                chats: cachedChats,
                isLoading: false,
                error: null,
              );
            }
          }
        } catch (_) {}
      }
    }

    if (!hasCache && state.chats.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final chats = await ref.read(getChatsProvider).call();
      if (!ref.mounted) return;

      // Merge server chats with existing local state by ID
      // Server chats take priority, but any locally-present chats
      // not returned by the server are preserved to avoid disappearing
      final serverChatMap = {for (final c in chats) c.id: c};
      final existingChatMap = {for (final c in state.chats) c.id: c};

      // Start with all server chats, then add any local-only chats
      final mergedMap = {...existingChatMap, ...serverChatMap};
      final mergedChats = mergedMap.values.toList();

      mergedChats.sort((a, b) {
        final aDate = a.lastMessage?.createdAt ?? DateTime(0);
        final bDate = b.lastMessage?.createdAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      state = state.copyWith(chats: mergedChats, isLoading: false, error: null);
      _persistCache();
    } catch (e) {
      if (!ref.mounted) return;
      if (state.chats.isEmpty) {
        state = state.copyWith(isLoading: false, error: e.toString());
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  // ─────────────────────────── STATE MUTATIONS ─────────────────────────────

  void resetUnreadCount(int chatId) {
    final updated = state.chats.map((chat) {
      if (chat.id == chatId) return chat.copyWith(unreadCount: 0);
      return chat;
    }).toList();

    state = state.copyWith(chats: updated);
    _persistCache();
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
      loadChats();
      return;
    }

    updatedChats.sort((a, b) {
      final aDate = a.lastMessage?.createdAt ?? DateTime(0);
      final bDate = b.lastMessage?.createdAt ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    state = state.copyWith(chats: updatedChats);
    _persistCache();
  }

  void incrementUnreadCount(int chatId) {
    final updatedChats = state.chats.map((chat) {
      if (chat.id == chatId) {
        return chat.copyWith(unreadCount: chat.unreadCount + 1);
      }
      return chat;
    }).toList();
    state = state.copyWith(chats: updatedChats);
    _persistCache();
  }

  void removeChatFromList(int chatId) {
    state = state.copyWith(
      chats: state.chats.where((c) => c.id != chatId).toList(),
    );
    _persistCache();
  }

  // ─────────────────────────── MUTATIONS ───────────────────────────────────

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
            chatId: chatId,
            name: name,
            avatarBytes: avatarBytes,
            filename: filename,
            mimeType: mimeType,
          );

      if (!ref.mounted) return;

      final updatedChats = state.chats.map((chat) {
        if (chat.id == chatId) {
          return chat.copyWith(
            name: updatedData.name,
            avatar: updatedData.avatar,
          );
        }
        return chat;
      }).toList();
      state = state.copyWith(chats: updatedChats);
      _persistCache();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addMember(int chatId, int userId) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .addMember(chatId: chatId, userId: userId);
      if (ref.mounted) await loadChats();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeMember(int chatId, int userId) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .removeMember(chatId: chatId, userId: userId);
      if (ref.mounted) await loadChats();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteChat(int chatId) async {
    try {
      await ref.read(chatRepositoryProvider).deleteChat(chatId);
      if (ref.mounted) removeChatFromList(chatId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGroup(int chatId) async {
    try {
      await ref.read(chatRepositoryProvider).deleteGroup(chatId);
      if (ref.mounted) removeChatFromList(chatId);
    } catch (e) {
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
    _persistCache();
  }
}
