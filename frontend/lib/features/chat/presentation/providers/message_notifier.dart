import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:my_chat_app/features/chat/domain/usecases/get_messages.dart';
import 'package:my_chat_app/features/chat/domain/usecases/send_message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_state.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

final messageProvider =
    StateNotifierProvider.family<MessageNotifier, MessageState, int>((
      ref,
      chatId,
    ) {
      return MessageNotifier(
        getMessages: ref.watch(getMessagesProvider),
        sendMessage: ref.watch(sendMessageProvider),
        repository: ref.watch(chatRepositoryProvider),
        datasource: ref.watch(chatSocketDataSourceProvider),
        ref: ref,
        chatId: chatId,
      );
    });

class MessageNotifier extends StateNotifier<MessageState> {
  final GetMessages getMessages;
  final SendMessage sendMessage;
  final ChatRepository repository;
  final ChatSocketDatasource _datasource;
  final Ref ref;
  final int chatId;
  bool _initialized = false;

  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;
  StreamSubscription? _chatReadSub;
  StreamSubscription? _deliveredSub;
  StreamSubscription? _deletedSub;
  Timer? _typingTimer;
  Timer? _typingDebounce;

  /// Eagerly cached blocked user IDs to avoid race condition with async provider.
  final Set<int> _blockedUserIds = {};

  MessageNotifier({
    required this.getMessages,
    required this.sendMessage,
    required this.repository,
    required ChatSocketDatasource datasource,
    required this.ref,
    required this.chatId,
  }) : _datasource = datasource,
       super(const MessageState()) {
    _initBlocked();
  }

  /// Fetch blocked IDs first, THEN set up listeners and load messages.
  Future<void> _initBlocked() async {
    try {
      final blocked = await ref.read(blockedContactsProvider.future);
      _blockedUserIds.addAll(blocked.map((c) => c.id));
    } catch (_) {}

    ref.listen<AsyncValue<List<dynamic>>>(blockedContactsProvider, (_, next) {
      next.whenData((blocked) {
        _blockedUserIds
          ..clear()
          ..addAll(blocked.map((c) => c.id));
      });
    });

    _init();
  }
  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    _listenToMessages();
    _listenToTyping();
    _listenToReadReceipts();
    _listenToChatRead();
    _listenToDelivered();
    _listenToMessageDeleted();

    await joinChat(chatId);

    await loadMessages();
  }

  void _listenToMessages() {
    _messageSub?.cancel();

    _messageSub = _datasource.onMessage().listen((data) {
      try {
        final newMessage = MessageModel.fromJson(data);
        if (newMessage.chatId != chatId) return;
        print('📥 RAW SOCKET MESSAGE RECEIVED: $data');
        final myId = ref.read(authProvider).user?.id;
        final isMyMessage = newMessage.senderId == myId;

        // ── Block filter (uses pre-loaded cached set — no race condition) ──
        if (!isMyMessage && _blockedUserIds.contains(newMessage.senderId)) {
          print('🚫 MessageNotifier: dropped msg from blocked ${newMessage.senderId}');
          return;
        }
        // ──────────────────────────────────────────────────────────

        if (isMyMessage) {
          // Check if it's already in state (by real server ID)
          final existsById = state.messages.any((m) => m.id == newMessage.id);
          if (existsById) return; // Already confirmed, ignore duplicate

          // Try to swap a matching optimistic/temp message (long tempId or same text)
          final tempIndex = state.messages.indexWhere(
            (m) =>
                m.id.toString().length > 10 && // temp ID
                (m.text == newMessage.text ||
                 (m.fileType != MessageType.text && m.originalName == newMessage.originalName && m.fileSize == newMessage.fileSize)),
          );

          if (tempIndex != -1) {
            final updated = List<Message>.from(state.messages);
            updated[tempIndex] = newMessage;
            state = state.copyWith(messages: updated);
          } else {
            // No temp found — insert server message to avoid missing it
            state = state.copyWith(messages: [newMessage, ...state.messages]);
          }
          return;
        }

        // Message from someone else: handle normal insertion
        final exists = state.messages.any((m) => m.id == newMessage.id);
        if (!exists) {
          state = state.copyWith(messages: [newMessage, ...state.messages]);
        }
      } catch (e) {
        print('❌ Socket parse error: $e');
      }
    });
  }

  void _listenToDelivered() {
    _deliveredSub?.cancel();

    _deliveredSub = _datasource.onMessagesDelivered().listen((data) {
      print('📦 messages_delivered: $data');

      final rawIds = data['messageIds'];
      if (rawIds == null) return;
      final Set<int> messageIds = (rawIds as List)
          .map((id) => int.tryParse(id.toString()))
          .whereType<int>()
          .toSet();

      if (messageIds.isEmpty) return;

      final updated = state.messages.map((m) {
        if (messageIds.contains(m.id) && m.status != MessageStatus.read) {
          return m.copyWith(
            status: MessageStatus.delivered,
            deliveredAt: DateTime.now(),
          );
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updated);
    });
  }

  void _listenToChatRead() {
    _chatReadSub?.cancel();
    _chatReadSub = _datasource.onChatRead().listen((data) {
      print('📖 chat_read received: $data');
      final incomingChatId = int.tryParse(data['chatId'].toString());
      print('📖 chatId: $incomingChatId vs this.chatId: $chatId');
      if (incomingChatId == chatId) {
        ref.read(chatProvider.notifier).resetUnreadCount(chatId);
        print('📖 reset unread count for chat $chatId');
      }
    });
  }

  void _listenToReadReceipts() {
    _readSub?.cancel();

    _readSub = _datasource.onMessagesRead().listen((data) {
      print('📩 messages_read received: $data');

      final incomingChatId = int.tryParse(data['chatId']?.toString() ?? '');

      if (incomingChatId == null || incomingChatId != chatId) return;

      final List<dynamic> rawIds = data['messageIds'] ?? [];

      final ids = rawIds
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toSet();

      if (ids.isEmpty) return;

      final updated = state.messages.map((m) {
        if (ids.contains(m.id)) {
          return m.copyWith(
            status: MessageStatus.read,
            deliveredAt: m.deliveredAt ?? DateTime.now(),
            readAt: DateTime.now(),
          );
        }

        return m;
      }).toList();

      state = state.copyWith(messages: updated);

      print('✅ Updated ${ids.length} messages to READ');
    });
  }

  void _listenToMessageDeleted() {
    _deletedSub?.cancel();
    _deletedSub = _datasource.onMessageDeleted().listen((data) {
      try {
        final incomingChatId = int.tryParse(data['chatId']?.toString() ?? '');
        if (incomingChatId == null || incomingChatId != chatId) return;
        final messageId = int.tryParse(data['messageId']?.toString() ?? '');
        if (messageId == null) return;
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != messageId).toList(),
        );
        print('🗑️ Removed message $messageId from state');
      } catch (e) {
        print('❌ message_deleted parse error: $e');
      }
    });
  }

  void _listenToTyping() {
    _typingSub?.cancel();
    _typingSub = null;

    _typingSub = _datasource.onUserTyping().listen((data) {
      print('🔔 RAW typing data: $data');
      final incomingChatId = int.tryParse(data['chatId'].toString());
      if (incomingChatId != chatId) return;

      final typingUserId = int.tryParse(data['userId'].toString());
      final bool isTyping = data['isTyping'] == true;
      final myId = ref.read(authProvider).user?.id;

      print('🔍 typingUserId=$typingUserId myId=$myId isTyping=$isTyping');

      if (typingUserId == null || typingUserId == myId) return;
      
      // ── Block filter ──────────────────────────────────────────
      if (_blockedUserIds.contains(typingUserId)) {
        return;
      }
      // ──────────────────────────────────────────────────────────

      _typingTimer?.cancel();
      if (isTyping) {
        state = state.copyWith(
          typingStatus: 'typing...',
          typingUserId: typingUserId,
        );

        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) state = state.copyWith(clearTyping: true);
        });
      } else {
        state = state.copyWith(clearTyping: true);
        print('typing status null');
      }
    });
  }

  void sendTypingEvent(bool isTyping) {
    _typingDebounce?.cancel();

    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (isTyping) {
      _datasource.sendTypingEvent(chatId, true, user.id);

      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _datasource.sendTypingEvent(chatId, false, user.id);
      });
    } else {
      _datasource.sendTypingEvent(chatId, false, user.id);
    }
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('📡 Loading messages for chatId: $chatId');
      final myId = ref.read(authProvider).user?.id;
      final history = await getMessages(chatId: chatId);
      print('📦 Got ${history.length} messages from API');
      if (history.isNotEmpty) {
        print(
          '📝 First message: ${history.first.text} | type: ${history.first.fileType}',
        );
      }

      // Filter out any messages from blocked senders (double safety
      // in case the backend query missed them).
      final filtered = _blockedUserIds.isEmpty
          ? history
          : history.where((m) =>
              m.senderId == myId || !_blockedUserIds.contains(m.senderId),
            ).toList();

      final allMessages = [...state.messages, ...filtered];
      final seenIds = <int>{};
      final unique = allMessages.where((m) => seenIds.add(m.id)).toList();
      unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ State updated with ${unique.length} messages');
      state = state.copyWith(messages: unique, isLoading: false);
    } catch (e) {
      print('❌ loadMessages error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    // Optimistically remove from local state immediately
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
    try {
      await repository.deleteMessage(chatId, messageId);
    } catch (e) {
      print('❌ deleteMessage error: $e');
      // Re-load messages on failure to restore state
      await loadMessages();
    }
  }

  Future<void> joinChat(int chatId) async {
    await repository.joinChat(chatId);
  }

  Future<void> sendMessageFunction(Message message) async {
    state = state.copyWith(messages: [message, ...state.messages]);
    ref.read(chatProvider.notifier).updateChatLastMessage(message);

    sendTypingEvent(false);

    try {
      final serverMessage = await repository.sendMessage(message);

      // Replace the optimistic temp message with the confirmed server message
      final updated = state.messages.map((m) {
        return m.id == message.id ? serverMessage : m;
      }).toList();

      state = state.copyWith(messages: updated);

      // Emit message_received for the HTTP-sent message so the server
      // marks it as delivered for the recipient when they are online.
      // This covers the case where the message is sent via REST (not socket).
      _datasource.emitMessageReceived(serverMessage.id);
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != message.id).toList(),
        error: e.toString(),
      );
    }
  }

  MessageType _getMessageTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) return MessageType.image;
    if (mimeType.startsWith('video/')) return MessageType.video;
    if (mimeType.startsWith('audio/')) return MessageType.audio;
    if (mimeType == 'application/pdf') return MessageType.pdf;
    if (mimeType.contains('zip') || mimeType.contains('tar') || mimeType.contains('rar')) {
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
    print(
      '📤 sendFileMessage called: $filename | $mimeType | ${bytes.length} bytes',
    );

    final user = ref.read(authProvider).user;
    final tempId = DateTime.now().microsecondsSinceEpoch;

    // Create an optimistic placeholder message
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

    // Insert optimistic message at the top
    state = state.copyWith(messages: [tempMessage, ...state.messages]);

    try {
      final message = await repository.sendFileMessage(
        chatId,
        bytes,
        filename,
        mimeType,
        onProgress: (sent, total) {
          if (!mounted) return;
          final updated = state.messages.map((m) {
            if (m.id == tempId) {
              return m.copyWith(uploadedBytes: sent);
            }
            return m;
          }).toList();
          state = state.copyWith(messages: updated);
        },
      );

      print('✅ File sent: ${message.fileUrl}');

      // Replace temp message with server response
      final updated = state.messages.map((m) {
        return m.id == tempId ? message : m;
      }).toList();
      state = state.copyWith(messages: updated);

      ref.read(chatProvider.notifier).updateChatLastMessage(message);
    } catch (e) {
      print('❌ sendFileMessage error: $e');
      // Mark the temp message as error
      final updated = state.messages.map((m) {
        if (m.id == tempId) {
          return m.copyWith(status: MessageStatus.error);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated, error: e.toString());
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    _readSub?.cancel();
    _chatReadSub?.cancel();
    _deliveredSub?.cancel();
    _deletedSub?.cancel();
    super.dispose();
  }
}
