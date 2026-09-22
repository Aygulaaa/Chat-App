import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:my_chat_app/core/constants/api_config.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatSocketDatasourceImpl implements ChatSocketDatasource {
  IO.Socket? _socket;

  final StreamController<List<int>> _onlineUsersController =
      StreamController<List<int>>.broadcast();

  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _readController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _chatReadController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _deliveredController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<int> _groupDeletedController =
      StreamController<int>.broadcast();

  final StreamController<Map<String, dynamic>> _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageReactionController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<void> _sessionsUpdatedController =
      StreamController<void>.broadcast();

  final StreamController<void> _sessionRevokedController =
      StreamController<void>.broadcast();

  Completer<void>? _connectionCompleter;

  final Set<int> _joinedChats = {};

  bool get _isConnected => _socket?.connected ?? false;

  /// `print` survives into release builds, and several of these lines include
  /// message payloads — so only ever log in debug mode.
  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  int? _activeChatId;

  /// Mirrors the app's lifecycle. Everything that means "the user is looking
  /// at this chat right now" — suppressing pushes, auto read receipts — is
  /// gated on it, because a backgrounded app keeps its socket connected.
  bool _appInForeground = true;

  // ───────────────── CONNECT ─────────────────

  @override
  void connect(String token) {
    if (_isConnected) return;

    _connectionCompleter = Completer<void>();

    // A previous socket may still exist (disconnected, mid-reconnect). Creating
    // a second one on top of it would double every incoming event.
    _socket?.dispose();

    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          // Every login gets its own connection manager — never a cached one
          // that was created for a previous account's token.
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    // ───────────────── CONNECTED ─────────────────

    _socket?.onConnect((_) async {
      _log('✅ Socket connected: ${_socket?.id}');

      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }

      // ✅ Rejoin chats and acknowledge delivery on reconnect
      _resyncState();
    });

    // ───────────────── RECONNECT ─────────────────

    _socket?.onReconnect((_) async {
      _log('♻️ Socket reconnected');
      _resyncState();
    });

    // ───────────────── ERRORS ─────────────────

    _socket?.onConnectError((err) {
      _log('🔴 Connect error: $err');

      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(err);
      }
    });

    _socket?.onError((err) {
      _log('🔴 Socket error: $err');
    });

    _socket?.onDisconnect((reason) {
      _log('❌ Socket disconnected: $reason');
      _connectionCompleter = Completer<void>();
    });

    // ───────────────── SERVER ERRORS ─────────────────

    _socket?.on('error_message', (msg) {
      _log('⚠️ Server error: $msg');
    });

    // ───────────────── ONLINE USERS ─────────────────

    _socket?.on('initial_online_users', (data) {
      try {
        if (data is List) {
          _onlineUsersController.add(List<int>.from(data));
        }
      } catch (e) {
        _log('initial_online_users error: $e');
      }
    });

    // ───────────────── USER STATUS ─────────────────

    _socket?.on('user_status', (data) {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          _statusController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        _log('user_status error: $e');
      }
    });

    // ───────────────── CHAT READ ─────────────────

    _socket?.on('chat_read', (data) {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          _chatReadController.add(mapData);
          _readController.add(
            mapData,
          ); // Send to onMessagesRead() listener in ChatNotifier
          _log('👀 Read receipt received: $mapData');
        }
      } catch (e) {
        _log('chat_read error: $e');
      }
    });

    // ───────────────── INCOMING MESSAGES ─────────────────

    _socket?.on('message', (data) async {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is! Map) return;

        final message = Map<String, dynamic>.from(data);

        _messageController.add(message);

        final messageId = message['id'];
        final chatId = message['chatId'] ?? message['chat_id'];

        if (messageId == null || chatId == null) return;

        // 🚚 1. ALWAYS emit message_received as soon as payload hits the socket client
        _socket?.emit('message_received', {
          'messageId': messageId,
          'chatId': chatId,
        });
        _log('🚚 Emitted message_received for message $messageId');

        // 👀 2. If the user is LOOKING at this chat, trigger a read receipt.
        // Backgrounded apps keep receiving socket messages — marking those as
        // read would tell the sender they were seen when they were not.
        final chatIdInt = int.tryParse(chatId.toString());
        if (_appInForeground &&
            _activeChatId != null &&
            chatIdInt != null &&
            _activeChatId == chatIdInt) {
          _socket?.emit('read_messages', {'chatId': chatIdInt});
          _log('👀 Auto read emitted for chat $chatIdInt');
        }
      } catch (e) {
        _log('message event error: $e');
      }
    });

    _socket?.on('user_typing', (data) {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          _typingController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        _log('typing event error: $e');
      }
    });

    // _socket?.on('messages_read', (data) {
    //   try {
    //     if (data is Map) {
    //       _readController.add(Map<String, dynamic>.from(data));
    //     }
    //   } catch (e) {
    //     _log('messages_read error: $e');
    //   }
    // });

    // 🚚 Server acknowledges to sender that recipient received the message
    _socket?.on('messages_delivered', (data) {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          _deliveredController.add(Map<String, dynamic>.from(data));
          _log('🚚 Delivered update received: $data');
        }
      } catch (e) {
        _log('messages_delivered error: $e');
      }
    });

    _socket?.on('group_deleted', (data) {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          final chatId = data['chatId'];
          if (chatId != null) {
            _groupDeletedController.add(int.parse(chatId.toString()));
            _log('🗑️ Group deleted event: chatId=$chatId');
          }
        }
      } catch (e) {
        _log('group_deleted error: $e');
      }
    });

    _socket?.on('message_deleted', (data) {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          _messageDeletedController.add(Map<String, dynamic>.from(data));
          _log('🗑️ message_deleted event: $data');
        }
      } catch (e) {
        _log('message_deleted error: $e');
      }
    });

    _socket?.on('message_reaction', (data) {
      try {
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          _messageReactionController.add(Map<String, dynamic>.from(data));
          _log('🙂 message_reaction event: $data');
        }
      } catch (e) {
        _log('message_reaction error: $e');
      }
    });

    _socket?.on('sessions_updated', (data) {
      _sessionsUpdatedController.add(null);
      _log('🔄 sessions_updated event received');
    });

    _socket?.on('session_revoked', (data) {
      _sessionRevokedController.add(null);
      _log('🚫 session_revoked event received — forcing logout');
    });

    _socket?.connect();
  }

  // ───────────────── GROUP / MESSAGE DELETED ─────────────────

  Future<void> _waitUntilConnected() async {
    if (_isConnected) return;

    // if (_connectionCompleter == null) {
    //   throw Exception('Socket not initialized. Call connect() first.');
    // }

    // try {
    //   await _connectionCompleter!.future.timeout(const Duration(seconds: 20));
    // } on TimeoutException {
    //   _log('⏳ Socket connection timeout');
    // }
  }

  @override
  void requestOnlineUsers() {
    _socket?.emit('request_online_users');
  }

  /// Re-sends everything the server keeps per connection: the rooms we belong
  /// to, which chat is on screen, and whether the app is in the foreground.
  /// A reconnect gives us a socket that knows none of it.
  void _resyncState() {
    for (final chatId in _joinedChats) {
      _socket?.emit('join_chat', {'chatId': chatId});
      _log('♻️ Rejoined chat_$chatId');
    }
    _socket?.emit('app_state', {'foreground': _appInForeground});
    _socket?.emit('active_chat', {'chatId': _activeChatId});
  }

  @override
  void setActiveChat(int? chatId) {
    _activeChatId = chatId;
    if (!_isConnected) return;
    // `active_chat` is what suppresses this chat's pushes — deliberately
    // separate from `join_chat`, which we re-send for EVERY open chat after a
    // reconnect and which therefore can't mean "this one is on screen".
    _socket?.emit('active_chat', {'chatId': chatId});
    if (chatId != null) _socket?.emit('join_chat', {'chatId': chatId});
  }

  @override
  int? get activeChatId => _activeChatId;

  @override
  bool get appInForeground => _appInForeground;

  @override
  void setAppForeground(bool foreground) {
    if (_appInForeground == foreground) return;
    _appInForeground = foreground;
    _log(foreground ? '🌞 app resumed' : '🌙 app backgrounded');

    if (!_isConnected) return;
    _socket?.emit('app_state', {'foreground': foreground});

    // Coming back with a conversation open: it is on screen again, and
    // whatever arrived while we were away is now actually seen.
    if (foreground && _activeChatId != null) {
      _socket?.emit('active_chat', {'chatId': _activeChatId});
      _socket?.emit('read_messages', {'chatId': _activeChatId});
      _log('👀 Read event sent for chat $_activeChatId on resume');
    }
  }

  @override
  Future<void> joinChat(int chatId) async {
    // 1. Optimistic local state update (Immediate)
    if (_joinedChats.contains(chatId)) return;
    _joinedChats.add(chatId);
    _log('🚪 Optimistically joined chat_$chatId');

    // 2. Perform connection & socket emit in background without blocking
    _waitUntilConnected()
        .then((_) {
          _socket?.emit('join_chat', {'chatId': chatId});
          _log('✅ Confirmed join on socket for chat_$chatId');
        })
        .catchError((error) {
          // 3. Rollback local state if connection fails or times out
          _joinedChats.remove(chatId);
          _log('❌ Failed to join chat_$chatId: $error');
        });
  }

  @override
  Future<void> markChatAsRead(int chatId) async {
    await _waitUntilConnected();
    _socket?.emit('read_messages', {'chatId': chatId});
    _log('👀 Read event sent for chat $chatId');
  }

  @override
  void emitMessageReceived(int messageId) {
    _socket?.emit('message_received', {'messageId': messageId});
    _log('📬 message_received emitted for messageId $messageId');
  }

  @override
  Future<void> leaveChat(int chatId) async {
    _joinedChats.remove(chatId);
    _socket?.emit('leave_chat', {'chatId': chatId});

    if (_activeChatId == chatId) {
      _activeChatId = null;
    }

    _log('🚪 Left chat_$chatId');
  }

  @override
  Future<void> sendMessage(dynamic message) async {
    await _waitUntilConnected();

    _socket?.emit('send_message', {
      'chatId': message.chatId,
      'text': message.text,
      if (message.replyTo != null) 'replyToId': message.replyTo.id,
    });

    _log('📤 Sent message to chat ${message.chatId}');
  }

  @override
  Future<void> sendTypingEvent(int chatId, bool isTyping, int userId) async {
    await _waitUntilConnected();

    final eventName = isTyping ? 'typing' : 'stop_typing';

    _socket?.emit(eventName, {'chatId': chatId, 'userId': userId});

    _log('✍️ Typing event: $eventName for user $userId');
  }

  @override
  Stream<Map<String, dynamic>> onMessage() => _messageController.stream;

  @override
  Stream<Map<String, dynamic>> onChatRead() => _chatReadController.stream;

  @override
  Stream<Map<String, dynamic>> onUserTyping() => _typingController.stream;

  @override
  Stream<Map<String, dynamic>> onUserStatusChanged() =>
      _statusController.stream;

  @override
  Stream<List<int>> onInitialOnlineUsers() => _onlineUsersController.stream;

  @override
  Stream<Map<String, dynamic>> onMessagesRead() => _readController.stream;

  @override
  Stream<Map<String, dynamic>> onMessagesDelivered() =>
      _deliveredController.stream;

  @override
  Stream<int> onGroupDeleted() => _groupDeletedController.stream;

  @override
  Stream<Map<String, dynamic>> onMessageDeleted() =>
      _messageDeletedController.stream;

  @override
  Stream<Map<String, dynamic>> onMessageReaction() =>
      _messageReactionController.stream;

  @override
  Stream<void> onSessionsUpdated() => _sessionsUpdatedController.stream;

  @override
  Stream<void> onSessionRevoked() => _sessionRevokedController.stream;

  // ───────────────── DISCONNECT ─────────────────

  @override
  void disconnect() {
    _log('🔌 Disconnecting socket...');

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionCompleter = null;
    // Don't carry the previous account's rooms into the next login
    _joinedChats.clear();
    _activeChatId = null;

    _log('🔌 Socket disconnected');
  }

  // ───────────────── DISPOSE ─────────────────

  void dispose() {
    disconnect();

    _onlineUsersController.close();
    _statusController.close();
    _messageController.close();
    _typingController.close();
    _readController.close();
    _chatReadController.close();
    _deliveredController.close();
    _groupDeletedController.close();
    _messageDeletedController.close();
    _messageReactionController.close();
    _sessionsUpdatedController.close();
    _sessionRevokedController.close();
  }
}
