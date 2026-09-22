import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_state.dart';
import 'package:my_chat_app/features/chat/presentation/providers/send_queue.dart';
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
  StreamSubscription? _reactionSub;
  StreamSubscription? _outcomeSub;
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
      _reactionSub?.cancel();
      _outcomeSub?.cancel();
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
    _listenToReactions(datasource);

    // Outgoing messages live in the app-wide queue, not in this screen
    final queue = ref.read(sendQueueProvider.notifier);
    _outcomeSub = queue.outcomes.listen(_onSendOutcome);
    ref.listen<Map<int, List<Message>>>(sendQueueProvider, (previous, next) {
      final pending = next[chatId];
      // Other chats' uploads tick through here too — ignore those
      if (!ref.mounted || pending == null) return;
      if (identical(previous?[chatId], pending)) return;
      _syncPending(pending);
    });
    _syncPending(queue.pendingFor(chatId));

    await joinChat(chatId);
    if (!ref.mounted) return;
    await loadMessages();
  }

  Future<void> _persistCache(List<Message> messages) async {
    try {
      // Messages that went through copyWith() are plain `Message`s, so the old
      // `whereType<MessageModel>()` silently dropped every message whose
      // ticks had ever updated. Unsent/failed uploads are never cached.
      final toCache = messages
          .where((m) => !m.isPending)
          .take(100)
          .map((e) => MessageModel.fromEntity(e).toJson())
          .toList();
      await Hive.box<String>(
        'messages_cache',
      ).put('chat_$chatId', jsonEncode(toCache));
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
                m.isPending &&
                (m.text == newMessage.text ||
                    (m.fileType != MessageType.text &&
                        m.originalName == newMessage.originalName &&
                        m.fileSize == newMessage.fileSize)),
          );

          if (tempIndex != -1) {
            // Keep the optimistic bubble's identity → no flicker on confirm
            updatedList[tempIndex] = newMessage.copyWith(
              localId: updatedList[tempIndex].viewKey,
            );
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

      final incomingChatId = int.tryParse(
        data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '',
      );
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

  /// `chat_read` means two different things depending on who read:
  ///  • readBy == me  → another of MY devices opened the chat: clear my badge.
  ///  • readBy == them → the listed messages (and ONLY those) are now read.
  /// The old handler reset my badge on every event and treated an empty id
  /// list as "everything is read", so ticks turned blue for unread messages.
  void _listenToChatRead(ChatSocketDatasource datasource) {
    _chatReadSub?.cancel();
    _chatReadSub = datasource.onChatRead().listen((data) {
      if (!ref.mounted) return;
      final incomingChatId = int.tryParse(
        data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '',
      );
      if (incomingChatId != chatId) return;

      final myId = ref.read(authProvider).user?.id;
      final readBy = int.tryParse(data['readBy']?.toString() ?? '');
      if (readBy != null && readBy == myId) {
        ref.read(chatProvider.notifier).resetUnreadCount(chatId);
        return;
      }

      final ids = ((data['messageIds'] as List?) ?? const [])
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toSet();
      if (ids.isEmpty) return;

      final serverReadAt =
          DateTime.tryParse(data['readAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now();

      final updated = state.messages.map((m) {
        if (!ids.contains(m.id) || m.senderId != myId) return m;
        return m.copyWith(
          status: MessageStatus.read,
          deliveredAt: m.deliveredAt ?? serverReadAt,
          readAt: m.readAt ?? serverReadAt,
        );
      }).toList();

      state = state.copyWith(messages: updated);
      _persistCache(updated);
    });
  }

  // `onMessagesRead` is the same socket event as `onChatRead`; handling both
  // applied every receipt twice.
  void _listenToReadReceipts(ChatSocketDatasource datasource) {
    _readSub?.cancel();
  }

  void _listenToMessageDeleted(ChatSocketDatasource datasource) {
    _deletedSub?.cancel();
    _deletedSub = datasource.onMessageDeleted().listen((data) {
      if (!ref.mounted) return;
      try {
        final incomingChatId = int.tryParse(
          data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '',
        );
        if (incomingChatId == null || incomingChatId != chatId) return;
        final messageId = int.tryParse(data['messageId']?.toString() ?? '');
        if (messageId == null) return;

        final updated = _withoutMessage(messageId);
        state = state.copyWith(
          messages: updated,
          clearReply: state.replyingTo?.id == messageId,
        );
        _persistCache(updated);
      } catch (_) {}
    });
  }

  /// Someone reacted (or took their reaction back) somewhere in this chat.
  /// The server sends the message's whole list, already filtered for me, so
  /// it simply replaces whatever we had.
  void _listenToReactions(ChatSocketDatasource datasource) {
    _reactionSub?.cancel();
    _reactionSub = datasource.onMessageReaction().listen((data) {
      if (!ref.mounted) return;
      try {
        final incomingChatId = int.tryParse(
          data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '',
        );
        if (incomingChatId != chatId) return;
        final messageId = int.tryParse(data['messageId']?.toString() ?? '');
        if (messageId == null) return;

        _applyReactions(
          messageId,
          MessageModel.parseReactions(data['reactions']),
        );
      } catch (_) {}
    });
  }

  void _applyReactions(int messageId, List<MessageReaction> reactions) {
    var changed = false;
    final updated = state.messages.map((m) {
      if (m.id != messageId || m.reactions == reactions) return m;
      changed = true;
      return m.copyWith(reactions: reactions);
    }).toList();
    if (!changed) return;
    state = state.copyWith(messages: updated);
    _persistCache(updated);
  }

  /// Adds my reaction, swaps it for another, or takes it off — the way
  /// Telegram does it: one emoji per person, tapping it again removes it.
  /// The pill appears at once and is reconciled with the server's answer.
  Future<void> toggleReaction(Message message, String emoji) async {
    // Nothing to react to until the server has given the message an id
    if (message.isPending) return;
    final myId = ref.read(authProvider).user?.id;
    if (myId == null) return;

    final before = message.reactions;
    final mine = message.reactionOf(myId);
    final optimistic = [
      for (final r in before)
        if (r.userId != myId) r,
      if (mine != emoji) MessageReaction(userId: myId, emoji: emoji),
    ];
    _applyReactions(message.id, optimistic);

    try {
      final confirmed = await ref
          .read(chatRepositoryProvider)
          .setReaction(chatId: chatId, messageId: message.id, emoji: emoji);
      if (!ref.mounted) return;
      _applyReactions(message.id, confirmed);
    } catch (_) {
      // Put back exactly what was there before the tap
      if (ref.mounted) _applyReactions(message.id, before);
    }
  }

  /// Removes a message and clears the quote on any reply that pointed at it
  /// (mirrors the database's ON DELETE SET NULL).
  List<Message> _withoutMessage(int messageId) {
    return state.messages
        .where((m) => m.id != messageId)
        .map((m) => m.replyTo?.id == messageId ? m.copyWith(clearReplyTo: true) : m)
        .toList();
  }

  // ─────────────────────────── REPLY ───────────────────────────────────────

  void startReply(Message message) {
    // Can't quote something the server doesn't know about yet
    if (message.isPending) return;
    state = state.copyWith(replyingTo: message);
  }

  void cancelReply() {
    if (state.replyingTo != null) state = state.copyWith(clearReply: true);
  }

  void _listenToTyping(ChatSocketDatasource datasource) {
    _typingSub?.cancel();

    _typingSub = datasource.onUserTyping().listen((data) {
      if (!ref.mounted) return;
      final incomingChatId = int.tryParse(
        data['chatId']?.toString() ?? data['chat_id']?.toString() ?? '',
      );
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
          final cachedMessages = decoded
              .map((e) => MessageModel.fromJson(e))
              .toList();
          cachedMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = state.copyWith(
            messages: cachedMessages,
            isLoading: cachedMessages.isEmpty,
          );
        }
      } catch (_) {}

      final myId = ref.read(authProvider).user?.id;
      // Anything that shows up in state while we await was pushed by the
      // socket and may be newer than the server's snapshot.
      final idsBeforeFetch = state.messages.map((m) => m.id).toSet();
      final history = await ref
          .read(getMessagesProvider)
          .call(chatId: chatId, limit: _pageSize);

      if (!ref.mounted) return;

      final datasource = ref.read(chatSocketDataSourceProvider);

      // 1. Emit delivery receipts for unacknowledged messages loaded via REST
      for (final m in history) {
        if (m.senderId != myId && m.deliveredAt == null) {
          datasource.emitMessageReceived(m.id);
        }
      }

      final filtered = _visible(history, myId);

      // 2. Merge. For the id range the server just returned, the server is the
      //    truth: its copy wins (fresh ticks) and anything we hold in that
      //    range that it did NOT return was deleted while we were away.
      //    (The old merge only ever added, so deleted messages lived in the
      //    cache forever and cached ticks never updated.)
      final serverIds = filtered.map((m) => m.id).toSet();
      final oldestServerId = filtered.isEmpty
          ? null
          : filtered.map((m) => m.id).reduce((a, b) => a < b ? a : b);
      final localKeys = {for (final m in state.messages) m.id: m.viewKey};

      bool keepLocal(Message m) {
        if (serverIds.contains(m.id)) return false; // server copy is used
        if (m.isPending) return true; // still sending / failed
        if (!idsBeforeFetch.contains(m.id)) return true; // arrived mid-fetch
        // An older page loaded earlier via loadMore()
        return oldestServerId != null && m.id < oldestServerId;
      }

      final merged = <Message>[
        for (final m in filtered)
          localKeys[m.id] != null && localKeys[m.id] != m.id
              ? m.copyWith(localId: localKeys[m.id])
              : m,
        ...state.messages.where(keepLocal),
      ];

      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        messages: merged,
        isLoading: false,
        hasMore: history.length >= _pageSize,
      );
      await _persistCache(merged);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: state.messages.isEmpty
            ? ErrorHandler.getReadableErrorMessage(e)
            : null,
      );
    }
  }

  static const int _pageSize = 50;

  List<Message> _visible(List<Message> messages, int? myId) {
    if (_blockedUserIds.isEmpty) return messages;
    return messages
        .where((m) => m.senderId == myId || !_blockedUserIds.contains(m.senderId))
        .toList();
  }

  /// Loads the next (older) page. Called when the user scrolls near the top.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    final confirmed = state.messages.where((m) => !m.isPending);
    if (confirmed.isEmpty) return;
    final oldestId = confirmed.map((m) => m.id).reduce((a, b) => a < b ? a : b);

    state = state.copyWith(isLoadingMore: true);
    try {
      final older = await ref
          .read(getMessagesProvider)
          .call(chatId: chatId, limit: _pageSize, beforeId: oldestId);
      if (!ref.mounted) return;

      final myId = ref.read(authProvider).user?.id;
      final seen = state.messages.map((m) => m.id).toSet();
      final merged = [
        ...state.messages,
        ..._visible(older, myId).where((m) => seen.add(m.id)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        messages: merged,
        isLoadingMore: false,
        hasMore: older.length >= _pageSize,
      );
    } catch (_) {
      if (!ref.mounted) return;
      // Leave hasMore untouched so scrolling up again simply retries
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ─────────────────────────── MUTATIONS ───────────────────────────────────

  Future<void> deleteMessage(int chatId, int messageId) async {
    final updated = _withoutMessage(messageId);
    state = state.copyWith(
      messages: updated,
      clearReply: state.replyingTo?.id == messageId,
    );
    _persistCache(updated);

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteMessage(chatId: chatId, messageId: messageId);
    } catch (_) {
      if (!ref.mounted) return;
      await loadMessages();
    }
  }

  Future<void> joinChat(int chatId) async {
    await ref.read(chatRepositoryProvider).joinChat(chatId);
  }

  /// Turns the message being replied to into the quote for an outgoing message
  /// and closes the reply bar.
  ReplyPreview? _consumeReply() {
    final target = state.replyingTo;
    if (target == null) return null;
    state = state.copyWith(clearReply: true);
    return ReplyPreview.fromMessage(target, senderName: _senderNameOf(target.senderId));
  }

  String? _senderNameOf(int userId) {
    for (final chat in ref.read(chatProvider).chats) {
      if (chat.id != chatId) continue;
      for (final p in chat.participants) {
        if (p.id == userId) return p.username;
      }
    }
    return null;
  }

  /// Shows the bubble immediately and hands the actual sending to the app-wide
  /// [SendQueue] (text lane — never waits behind an upload). The result comes
  /// back through [_onSendOutcome].
  Future<void> sendMessageFunction(Message draft) async {
    final message = draft.copyWith(replyTo: _consumeReply());
    state = state.copyWith(
      messages: [message, ...state.messages],
      clearError: true,
    );
    ref.read(chatProvider.notifier).updateChatLastMessage(message);
    sendTypingEvent(false);

    ref.read(sendQueueProvider.notifier).enqueueText(message);
  }

  /// Queues a file. Several can be queued at once; they upload one at a time in
  /// the order they were added, each showing its own progress.
  Future<void> sendFileMessage(
    Uint8List bytes,
    String filename,
    String mimeType, {
    String? localPath,
  }) async {
    final user = ref.read(authProvider).user;
    final tempMessage = Message(
      // +state size keeps ids unique when many files are queued in one tick
      id: DateTime.now().microsecondsSinceEpoch + _tempIdSalt++,
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
      replyTo: _consumeReply(),
    );

    state = state.copyWith(
      messages: [tempMessage, ...state.messages],
      clearError: true,
    );
    ref
        .read(sendQueueProvider.notifier)
        .enqueueFile(tempMessage, bytes, filename, mimeType);
  }

  int _tempIdSalt = 0;

  /// Re-sends a failed text or upload (the queue kept the bytes).
  Future<void> retryMessage(Message failed) async {
    if (failed.status != MessageStatus.error) return;
    ref.read(sendQueueProvider.notifier).retry(failed.id);
  }

  /// Cancels a waiting / in-flight upload, or discards a failed message.
  void cancelSend(int tempId) {
    ref.read(sendQueueProvider.notifier).cancel(tempId);
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != tempId).toList(),
    );
  }

  void dismissFailed(int messageId) => cancelSend(messageId);

  // ─────────────────────────── SEND QUEUE ──────────────────────────────────

  /// Mirrors the queue's view of this chat's pending messages into [state]:
  /// live upload progress, failures, and — after leaving and re-opening the
  /// chat — the bubbles of uploads that are still running.
  void _syncPending(List<Message> pending) {
    if (pending.isEmpty) return;
    final byId = {for (final m in pending) m.id: m};
    final seen = <int>{};
    final merged = [
      for (final m in state.messages)
        if (byId.containsKey(m.id) && seen.add(m.id)) byId[m.id]! else m,
      for (final m in pending)
        if (!seen.contains(m.id) && !state.messages.any((x) => x.id == m.id)) m,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(messages: merged);
  }

  void _onSendOutcome(SendOutcome outcome) {
    if (!ref.mounted || outcome.chatId != chatId) return;

    if (outcome.cancelled) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != outcome.tempId).toList(),
      );
      return;
    }

    final sent = outcome.sent;
    if (sent == null) {
      // Failed: the bubble stays (marked failed by _syncPending) so nothing
      // the user wrote or picked is lost; they can retry or discard it.
      state = state.copyWith(error: outcome.error);
      return;
    }

    final temp = state.messages
        .where((m) => m.id == outcome.tempId)
        .firstOrNull;

    // A delivered event can beat the HTTP response (race condition fix)
    final wasDelivered = _pendingDeliveredIds.remove(sent.id);
    final confirmed = wasDelivered && sent.status != MessageStatus.read
        ? sent.copyWith(
            status: MessageStatus.delivered,
            deliveredAt: sent.deliveredAt ?? DateTime.now(),
          )
        : sent;
    final finalMessage = confirmed.copyWith(
      // Same widget key as the optimistic bubble → it updates in place
      localId: temp?.viewKey ?? outcome.tempId,
      replyTo: confirmed.replyTo ?? temp?.replyTo,
    );

    final seenIds = <int>{};
    final unique =
        state.messages
            .map(
              (m) => m.id == outcome.tempId || m.id == finalMessage.id
                  ? finalMessage
                  : m,
            )
            .where((m) => seenIds.add(m.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    state = state.copyWith(messages: unique);
    ref.read(chatProvider.notifier).updateChatLastMessage(finalMessage);
    _persistCache(unique);
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

}
