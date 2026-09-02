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
      'lastMessage': (lastMessage is MessageModel) 
          ? (lastMessage as MessageModel).toJson() 
          : null,
      'participants': participants.map((p) {
        if (p is UserModel) return p.toJson();
        return {'id': p.id, 'username': p.username, 'avatar': p.avatar};
      }).toList(),
      'isMuted': isMuted,
    };
  }
}