import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';

class ChatModel extends Chat {
  const ChatModel({
    required super.id,
    required super.type,
    super.name,
    super.avatar,
    super.createdBy,
    required super.unreadCount,
    required super.participants,
    required super.lastMessage,
    super.isMuted,
  });

  /// `Chat.copyWith` returns a plain [Chat]; this turns it back into something
  /// that can be written to the cache.
  factory ChatModel.fromEntity(Chat c) {
    if (c is ChatModel) return c;
    return ChatModel(
      id: c.id,
      type: c.type,
      name: c.name,
      avatar: c.avatar,
      createdBy: c.createdBy,
      unreadCount: c.unreadCount,
      participants: c.participants,
      lastMessage: c.lastMessage,
      isMuted: c.isMuted,
    );
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] ?? 0,

      type: json['type'] ?? 'private',

      name: json['name'],
      avatar: json['avatar'],
      createdBy: json['createdBy'],

      unreadCount: json['unreadCount'] ?? 0,

      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'])
          : null,

      participants: (json['participants'] as List? ?? [])
          .map((p) => UserModel.fromJson(p))
          .toList(),

      // Only ever present in the local cache — mute is a per-device setting
      isMuted: json['isMuted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'avatar': avatar,
      'createdBy': createdBy,
      'unreadCount': unreadCount,
      'lastMessage': lastMessage != null
          ? MessageModel.fromEntity(lastMessage!).toJson()
          : null,
      'participants': participants.map((p) {
        if (p is UserModel) return p.toJson();
        return {'id': p.id, 'username': p.username, 'avatar': p.avatar};
      }).toList(),
      'isMuted': isMuted,
    };
  }
}