import 'package:my_chat_app/core/common/entities/user_entity.dart';


class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.username,
    super.avatar,
    super.bio,
    super.birthDate,
    super.status,
    super.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      avatar: json['avatar'],
      bio: json['bio'],
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      status: json['status'],
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }
}