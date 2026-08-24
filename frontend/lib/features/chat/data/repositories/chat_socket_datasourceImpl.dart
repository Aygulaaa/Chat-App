import 'dart:async';

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

  Completer<void>? _connectionCompleter;

  final Set<int> _joinedChats = {};

  bool get _isConnected => _socket?.connected ?? false;

  int? _activeChatId;

  // ───────────────── CONNECT ─────────────────

  @override
  void connect(String token) {
    if (_isConnected) return;

    _connectionCompleter = Completer<void>();

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    // ───────────────── CONNECTED ─────────────────

    _socket?.onConnect((_) async {
      print('✅ Socket connected: ${_socket?.id}');

      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }

      // ✅ rejoin chats after reconnect
      for (final chatId in _joinedChats) {
        _socket?.emit('join_chat', {'chatId': chatId});

        print('♻️ Rejoined chat_$chatId');
      }
    });

    // ───────────────── RECONNECT ─────────────────

    _socket?.onReconnect((_) async {
      print('♻️ Socket reconnected');

      for (final chatId in _joinedChats) {
        _socket?.emit('join_chat', {'chatId': chatId});

        print('♻️ Rejoined chat_$chatId');
      }
    });

    // ───────────────── ERRORS ─────────────────

    _socket?.onConnectError((err) {
      print('🔴 Connect error: $err');

      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(err);
      }
    });

    _socket?.onError((err) {
      print('🔴 Socket error: $err');
    });

    _socket?.onDisconnect((reason) {
      print('❌ Socket disconnected: $reason');

      _connectionCompleter = Completer<void>();
    });

    // ───────────────── SERVER ERRORS ─────────────────

    _socket?.on('error_message', (msg) {
      print('⚠️ Server error: $msg');
    });

    // ───────────────── ONLINE USERS ─────────────────

    _socket?.on('initial_online_users', (data) {
      try {
        if (data is List) {
          _onlineUsersController.add(List<int>.from(data));
        }
      } catch (e) {
        print('initial_online_users error: $e');
      }
    });

    // ───────────────── USER STATUS ─────────────────

    _socket?.on('user_status', (data) {
      try {
        if (data is Map) {
          _statusController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('user_status error: $e');
      }
    });

    // ───────────────── CHAT READ ─────────────────

    _socket?.on('chat_read', (data) {
      try {
        if (data is Map) {
          _chatReadController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('chat_read error: $e');
      }
    });

    _socket?.on('message', (data) async {
      try {
        if (data is! Map) return;

        final message = Map<String, dynamic>.from(data);

        _messageController.add(message);

        final messageId = message['id'];
        final chatId = message['chatId'] ?? message['chat_id'];

        if (messageId == null || chatId == null) return;

        _socket?.emit('message_received', {'messageId': messageId});

        if (_activeChatId == chatId) {
          _socket?.emit('read_messages', {'chatId': chatId});

          print('👀 Auto read for chat $chatId');
        }
      } catch (e) {
        print('message event error: $e');
      }
    });

 
    _socket?.on('user_typing', (data) {
      try {
        if (data is Map) {
          _typingController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('typing event error: $e');
      }
    });

 
    _socket?.on('messages_read', (data) {
      try {
        if (data is Map) {
          _readController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('messages_read error: $e');
      }
    });

 
    _socket?.on('messages_delivered', (data) {
      try {
        if (data is Map) {
          _deliveredController.add(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        print('messages_delivered error: $e');
      }
    });

    _socket?.connect();

    // ───────────────── GROUP DELETED ─────────────────

    _socket?.on('group_deleted', (data) {
      try {
        if (data is Map) {
          final chatId = data['chatId'];
          if (chatId != null) {
            _groupDeletedController.add(int.parse(chatId.toString()));
            print('🗑️ Group deleted event: chatId=$chatId');
          }
        }
      } catch (e) {
        print('group_deleted error: $e');
      }
    });
  }


  Future<void> _waitUntilConnected() async {
    if (_isConnected) return;

    if (_connectionCompleter == null) {
      throw Exception('Socket not initialized. Call connect() first.');
    }

    try {
      await _connectionCompleter!.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      print('⏳ Socket connection timeout');
    }
  }


  @override
  void requestOnlineUsers() {
    _socket?.emit('request_online_users');
  }

  @override
  void setActiveChat(int? chatId) {
    _activeChatId = chatId;
  }

  @override
  int? get activeChatId => _activeChatId;

  @override
  Future<void> joinChat(int chatId) async {
    await _waitUntilConnected();
    if (_joinedChats.contains(chatId)) return;
    _joinedChats.add(chatId);
    _socket?.emit('join_chat', {'chatId': chatId});
    print('🚪 Joined chat_$chatId');
  }

  @override
  Future<void> markChatAsRead(int chatId) async {
    await _waitUntilConnected();
    _socket?.emit('read_messages', {'chatId': chatId});
    print('👀 Read event sent for chat $chatId');
  }

  @override
  void emitMessageReceived(int messageId) {
    _socket?.emit('message_received', {'messageId': messageId});
    print('📬 message_received emitted for messageId $messageId');
  }


  @override
  Future<void> leaveChat(int chatId) async {
    _joinedChats.remove(chatId);

    _socket?.emit('leave_chat', {'chatId': chatId});
    if (_activeChatId == chatId) {
      _activeChatId = null;
    }

    print('🚪 Left chat_$chatId');
  }

 
  @override
  Future<void> sendMessage(dynamic message) async {
    await _waitUntilConnected();

    _socket?.emit('send_message', {
      'chatId': message.chatId,
      'text': message.text,
    });

    print('📤 Sent message to chat ${message.chatId}');
  }


  @override
  Future<void> sendTypingEvent(int chatId, bool isTyping, int userId) async {
    await _waitUntilConnected();

    final eventName = isTyping ? 'typing' : 'stop_typing';

    _socket?.emit(eventName, {'chatId': chatId, 'userId': userId});

    print('✍️ Typing event: $eventName for user $userId');
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

  // ───────────────── DISCONNECT ─────────────────

  @override
  void disconnect() {
    print('🔌 Disconnecting socket...');

    _socket?.dispose();

    _socket?.disconnect();

    _socket = null;

    _connectionCompleter = null;

    print('🔌 Socket disconnected');
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
  }
}
