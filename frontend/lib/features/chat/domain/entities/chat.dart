import 'package:equatable/equatable.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
class Chat extends Equatable {
  final int id;
  final String? name;
  final String type;
  final String? avatar;
  final int? createdBy;
  final List<UserEntity> participants;
  final Message? lastMessage;
  final int unreadCount;

  const Chat({
    required this.id,
    this.name,
    required this.type,
    this.avatar,
    this.createdBy,
    required this.participants,
    required this.lastMessage,
    required this.unreadCount,
  });

  bool get isGroup => type == 'group';

  bool get isPrivate => type == 'private';

  Chat copyWith({
    int? id,
    String? name,
    String? type,
    String? avatar,
    int? createdBy,
    List<UserEntity>? participants,
    Message? lastMessage,
    int? unreadCount,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      avatar: avatar ?? this.avatar,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        avatar,
        createdBy,
        participants,
        lastMessage,
        unreadCount,
      ];
}