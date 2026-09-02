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
    super.lastSeenFuzzy,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      avatar: json['avatar'],
      bio: json['bio'],
      birthDate: json['birthDate'] != null || json['birth_date'] != null
          ? DateTime.tryParse((json['birthDate'] ?? json['birth_date']).toString())
          : null,
      status: json['status'],
      lastSeen: json['lastSeen'] != null || json['last_seen'] != null
          ? DateTime.tryParse((json['lastSeen'] ?? json['last_seen']).toString())
          : null,
      lastSeenFuzzy: json['lastSeenFuzzy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar': avatar,
      'bio': bio,
      'birthDate': birthDate?.toIso8601String(),
      'status': status,
      'lastSeen': lastSeen?.toIso8601String(),
      'lastSeenFuzzy': lastSeenFuzzy,
    };
  }
}