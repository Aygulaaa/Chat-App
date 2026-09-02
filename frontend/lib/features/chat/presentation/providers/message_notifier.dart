import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_state.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

part 'message_notifier.g.dart';

@riverpod
class MessageNotifier extends _$MessageNotifier {
  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;
  StreamSubscription? _chatReadSub;
  StreamSubscription? _deliveredSub;
  StreamSubscription? _deletedSub;
  Timer? _typingTimer;
  Timer? _typingDebounce;

  final Set<int> _blockedUserIds = {};
  // Tracks message IDs that arrived delivered before the HTTP response returned.
  final Set<int> _pendingDeliveredIds = {};

  @override
  MessageState build(int chatId) {
    ref.onDispose(() {
      _messageSub?.cancel();
      _typingSub?.cancel();
      _typingTimer?.cancel();
      _typingDebounce?.cancel();
      _readSub?.cancel();
      _chatReadSub?.cancel();
      _deliveredSub?.cancel();
      _deletedSub?.cancel();
    });

    Future.microtask(() => _initBlocked());
    return const MessageState();
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
        _blockedUserIds
          ..clear()
          ..addAll(blocked.map((c) => c.id));
      });
    });

    await _init();
  }

  Future<void> _init() async {
    if (!ref.mounted) return;

    final datasource = ref.read(chatSocketDataSourceProvider);

    _listenToMessages(datasource);
    _listenToTyping(datasource);
    _listenToReadReceipts(datasource);
    _listenToChatRead(datasource);
    _listenToDelivered(datasource);
    _listenToMessageDeleted(datasource);

    await joinChat(chatId);
    if (!ref.mounted) return;
    await loadMessages();
  }

  Future<void> _persistCache(List<Message> messages) async {
    try {
      final toCache = messages
          .take(100)
          .whereType<MessageModel>()
          .map((e) => e.toJson())
          .toList();
      await Hive.box<String>('messages_cache').put('chat_$chatId', jsonEncode(toCache));
    } catch (_) {}
  }

  // ─────────────────────────── SOCKET LISTENERS ────────────────────────────

  void _listenToMessages(ChatSocketDatasource datasource) {
    _messageSub?.cancel();

    _messageSub = datasource.onMessage().listen((data) {
      if (!ref.mounted) return;
      try {
        final newMessage = MessageModel.fromJson(data);
        if (newMessage.chatId != chatId) return;

        final myId = ref.read(authProvider).user?.id;
        final isMyMessage = newMessage.senderId == myId;

        if (!isMyMessage && _blockedUserIds.contains(newMessage.senderId)) {
          return;
        }

        // Acknowledge delivery to server immediately if received from counter-party
        if (!isMyMessage) {
          datasource.emitMessageReceived(newMessage.id);
        }

        List<Message> updatedList = List<Message>.from(state.messages);

        if (isMyMessage) {
          final existsById = updatedList.any((m) => m.id == newMessage.id);
          if (existsById) return;

          // Deduplicate optimistic messages
          final tempIndex = updatedList.indexWhere(
            (m) =>
                m.id.toString().length > 10 &&
                (m.text == newMessage.text ||
                 (m.fileType != MessageType.text &&
                  m.originalName == newMessage.originalName &&
                  m.fileSize == newMessage.fileSize)),
          );

          if (tempIndex != -1) {
            updatedList[tempIndex] = newMessage;
          } else {
            updatedList.insert(0, newMessage);
          }
        } else {
          final exists = updatedList.any((m) => m.id == newMessage.id);
          if (exists) return;
          updatedList.insert(0, newMessage);
        }

        updatedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(messages: updatedList);
        _persistCache(updatedList);
      } catch (_) {}
    });
  }

  void _listenToDelivered(ChatSocketDatasource datasource) {
    _deliveredSub?.cancel();

    _deliveredSub = datasource.onMessagesDelivered().listen((data) {
      if (!ref.mounted) return;

      final incomingChatId = int.tryParse(data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '');
      if (incomingChatId != null && incomingChatId != chatId) return;

      final rawIds = data['messageIds'];
      if (rawIds == null) return;

      final Set<int> messageIds = (rawIds as List)
          .map((id) => int.tryParse(id.toString()))
          .whereType<int>()
          .toSet();

      if (messageIds.isEmpty) return;

      // Store incoming IDs in case HTTP sendMessage hasn't resolved yet
      _pendingDeliveredIds.addAll(messageIds);

      final serverDeliveredAt = data['deliveredAt'] != null
          ? DateTime.tryParse(data['deliveredAt'].toString()) ?? DateTime.now()
          : DateTime.now();

      final updated = state.messages.map((m) {
        if (messageIds.contains(m.id) && m.status != MessageStatus.read) {
          final updatedMsg = m.copyWith(
            status: MessageStatus.delivered,
            deliveredAt: m.deliveredAt ?? serverDeliveredAt,
          );
          if (state.messages.isNotEmpty && state.messages.first.id == m.id) {
            ref.read(chatProvider.notifier).updateChatLastMessage(updatedMsg);
          }
          return updatedMsg;
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updated);
      _persistCache(updated);
    });
  }

  void _listenToChatRead(ChatSocketDatasource datasource) {
    _chatReadSub?.cancel();
    _chatReadSub = datasource.onChatRead().listen((data) {
      if (!ref.mounted) return;
      final incomingChatId = int.tryParse(data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '');
      if (incomingChatId == chatId) {
        ref.read(chatProvider.notifier).resetUnreadCount(chatId);
        
        final List<dynamic> rawIds = data['messageIds'] ?? [];
        final ids = rawIds
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toSet();

        final serverReadAt = data['readAt'] != null
            ? DateTime.tryParse(data['readAt'].toString()) ?? DateTime.now()
            : DateTime.now();

        final updated = state.messages.map((m) {
          if (ids.isEmpty || ids.contains(m.id)) {
            return m.copyWith(
              status: MessageStatus.read,
              deliveredAt: m.deliveredAt ?? serverReadAt,
              readAt: m.readAt ?? serverReadAt,
            );
          }
          return m;
        }).toList();

        state = state.copyWith(messages: updated);
        _persistCache(updated);
      }
    });
  }

  void _listenToReadReceipts(ChatSocketDatasource datasource) {
    _readSub?.cancel();

    _readSub = datasource.onMessagesRead().listen((data) {
      if (!ref.mounted) return;
      final incomingChatId = int.tryParse(data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '');
      if (incomingChatId == null || incomingChatId != chatId) return;

      final List<dynamic> rawIds = data['messageIds'] ?? [];
      final ids = rawIds
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toSet();

      final serverReadAt = data['readAt'] != null
          ? DateTime.tryParse(data['readAt'].toString()) ?? DateTime.now()
          : DateTime.now();

      final updated = state.messages.map((m) {
        if (ids.isEmpty || ids.contains(m.id)) {
          return m.copyWith(
            status: MessageStatus.read,
            deliveredAt: m.deliveredAt ?? serverReadAt,
            readAt: m.readAt ?? serverReadAt,
          );
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updated);
      _persistCache(updated);
    });
  }

  void _listenToMessageDeleted(ChatSocketDatasource datasource) {
    _deletedSub?.cancel();
    _deletedSub = datasource.onMessageDeleted().listen((data) {
      if (!ref.mounted) return;
      try {
        final incomingChatId = int.tryParse(data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '');
        if (incomingChatId == null || incomingChatId != chatId) return;
        final messageId = int.tryParse(data['messageId']?.toString() ?? '');
        if (messageId == null) return;

        final updated = state.messages.where((m) => m.id != messageId).toList();
        state = state.copyWith(messages: updated);
        _persistCache(updated);
      } catch (_) {}
    });
  }

  void _listenToTyping(ChatSocketDatasource datasource) {
    _typingSub?.cancel();

    _typingSub = datasource.onUserTyping().listen((data) {
      if (!ref.mounted) return;
      final incomingChatId = int.tryParse(data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '');
      if (incomingChatId != chatId) return;

      final typingUserId = int.tryParse(data['userId']?.toString() ?? '');
      final bool isTyping = data['isTyping'] == true;
      final myId = ref.read(authProvider).user?.id;

      if (typingUserId == null || typingUserId == myId) return;
      if (_blockedUserIds.contains(typingUserId)) return;

      _typingTimer?.cancel();
      if (isTyping) {
        state = state.copyWith(
          typingStatus: 'typing...',
          typingUserId: typingUserId,
        );

        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (ref.mounted) state = state.copyWith(clearTyping: true);
        });
      } else {
        state = state.copyWith(clearTyping: true);
      }
    });
  }

  void sendTypingEvent(bool isTyping) {
    _typingDebounce?.cancel();

    final user = ref.read(authProvider).user;
    if (user == null) return;

    final datasource = ref.read(chatSocketDataSourceProvider);

    if (isTyping) {
      datasource.sendTypingEvent(chatId, true, user.id);

      _typingDebounce = Timer(const Duration(seconds: 2), () {
        datasource.sendTypingEvent(chatId, false, user.id);
      });
    } else {
      datasource.sendTypingEvent(chatId, false, user.id);
    }
  }

  // ─────────────────────────── LOAD MESSAGES ───────────────────────────────

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: state.messages.isEmpty, error: null);

    try {
      try {
        final box = Hive.box<String>('messages_cache');
        final cachedStr = box.get('chat_$chatId');
        if (cachedStr != null) {
          final List<dynamic> decoded = jsonDecode(cachedStr);
          final cachedMessages = decoded.map((e) => MessageModel.fromJson(e)).toList();
          cachedMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = state.copyWith(messages: cachedMessages, isLoading: cachedMessages.isEmpty);
        }
      } catch (_) {}

      final myId = ref.read(authProvider).user?.id;
      final history = await ref.read(getMessagesProvider).call(chatId: chatId);

      if (!ref.mounted) return;

      final datasource = ref.read(chatSocketDataSourceProvider);

      // 1. Emit delivery receipts for unacknowledged messages loaded via REST
      for (final m in history) {
        if (m.senderId != myId && m.deliveredAt == null) {
          datasource.emitMessageReceived(m.id);
        }
      }

      final filtered = _blockedUserIds.isEmpty
          ? history
          : history
              .where(
                (m) => m.senderId == myId || !_blockedUserIds.contains(m.senderId),
              )
              .toList();

      // 2. Safe merge to prevent wiping socket messages that arrived during HTTP fetch
      final currentList = List<Message>.from(state.messages);
      final seenIds = currentList.map((m) => m.id).toSet();
      
      for (final msg in filtered) {
        if (seenIds.add(msg.id)) {
          currentList.add(msg);
        }
      }

      currentList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(messages: currentList, isLoading: false);
      await _persistCache(currentList);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: state.messages.isEmpty ? e.toString() : null);
    }
  }

  // ─────────────────────────── MUTATIONS ───────────────────────────────────

  Future<void> deleteMessage(int chatId, int messageId) async {
    final updated = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updated);
    _persistCache(updated);

    try {
      await ref.read(chatRepositoryProvider).deleteMessage(chatId: chatId, messageId: messageId);
    } catch (_) {
      if (!ref.mounted) return;
      await loadMessages();
    }
  }

  Future<void> joinChat(int chatId) async {
    await ref.read(chatRepositoryProvider).joinChat(chatId);
  }

  Future<void> sendMessageFunction(Message message) async {
    final tempId = message.id; // Keep local track of tempId
    state = state.copyWith(messages: [message, ...state.messages]);
    ref.read(chatProvider.notifier).updateChatLastMessage(message);

    sendTypingEvent(false);

    try {
      final serverMessage = await ref.read(chatRepositoryProvider).sendMessage(
            chatId: message.chatId,
            text: message.text!,
          );

      if (!ref.mounted) return;

      // Check if a delivered event already arrived for this message (race condition fix)
      final isPendingDelivered = _pendingDeliveredIds.contains(serverMessage.id);
      final finalMessage = isPendingDelivered && serverMessage.status != MessageStatus.read
          ? serverMessage.copyWith(
              status: MessageStatus.delivered,
              deliveredAt: serverMessage.deliveredAt ?? DateTime.now(),
            )
          : serverMessage;
      if (isPendingDelivered) _pendingDeliveredIds.remove(serverMessage.id);

      final updated = state.messages.map((m) {
        if (m.id == tempId || m.id == finalMessage.id) {
          return finalMessage;
        }
        return m;
      }).toList();

      final seenIds = <int>{};
      final unique = updated.where((m) => seenIds.add(m.id)).toList();
      unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(messages: unique);
      _persistCache(unique);
    } catch (e) {
      if (!ref.mounted) return;
      final updated = state.messages.where((m) => m.id != tempId).toList();
      state = state.copyWith(messages: updated, error: e.toString());
      _persistCache(updated);
    }
  }

  MessageType _getMessageTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) return MessageType.image;
    if (mimeType.startsWith('video/')) return MessageType.video;
    if (mimeType.startsWith('audio/')) return MessageType.audio;
    if (mimeType == 'application/pdf') return MessageType.pdf;
    if (mimeType.contains('zip') ||
        mimeType.contains('tar') ||
        mimeType.contains('rar')) {
      return MessageType.archive;
    }
    return MessageType.file;
  }

  Future<void> sendFileMessage(
    Uint8List bytes,
    String filename,
    String mimeType, {
    String? localPath,
  }) async {
    final user = ref.read(authProvider).user;
    final tempId = DateTime.now().microsecondsSinceEpoch;

    final tempMessage = Message(
      id: tempId,
      chatId: chatId,
      senderId: user?.id ?? 0,
      text: filename,
      fileType: _getMessageTypeFromMime(mimeType),
      originalName: filename,
      mimeType: mimeType,
      fileSize: bytes.length,
      localPath: localPath,
      createdAt: DateTime.now(),
      status: MessageStatus.uploading,
      uploadedBytes: 0,
    );

    state = state.copyWith(messages: [tempMessage, ...state.messages]);

    try {
      final message = await ref.read(chatRepositoryProvider).sendFileMessage(
        chatId: chatId,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        onProgress: (sent, total) {
          if (!ref.mounted) return;
          final updated = state.messages.map((m) {
            if (m.id == tempId) return m.copyWith(uploadedBytes: sent);
            return m;
          }).toList();
          state = state.copyWith(messages: updated);
        },
      );

      if (!ref.mounted) return;

      // Check if a delivered event already arrived for this file message (race condition fix)
      final isPendingDelivered = _pendingDeliveredIds.contains(message.id);
      final finalMessage = isPendingDelivered && message.status != MessageStatus.read
          ? message.copyWith(
              status: MessageStatus.delivered,
              deliveredAt: message.deliveredAt ?? DateTime.now(),
            )
          : message;
      if (isPendingDelivered) _pendingDeliveredIds.remove(message.id);

      final updated = state.messages.map((m) {
        if (m.id == tempId || m.id == finalMessage.id) {
          return finalMessage;
        }
        return m;
      }).toList();

      final seenIds = <int>{};
      final unique = updated.where((m) => seenIds.add(m.id)).toList();
      unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(messages: unique);
      ref.read(chatProvider.notifier).updateChatLastMessage(finalMessage);
      _persistCache(unique);
    } catch (e) {
      if (!ref.mounted) return;
      final updated = state.messages.map((m) {
        if (m.id == tempId) return m.copyWith(status: MessageStatus.error);
        return m;
      }).toList();
      state = state.copyWith(messages: updated, error: e.toString());
    }
  }
}