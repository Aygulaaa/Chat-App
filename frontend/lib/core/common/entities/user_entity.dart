import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String username;
  final String? avatar;
  final String? bio;
  final DateTime? birthDate;
  final String? status;
  final DateTime? lastSeen;

  const UserEntity({
    required this.id,
    required this.username,
    this.avatar,
    this.bio,
    this.birthDate,
    this.lastSeen,
    this.status,
  });

  UserEntity copyWith({
    int? id,
    String? username,
    String? avatar,
    String? bio,
    DateTime? birthDate,
    String? status,
    DateTime? lastSeen,
  }) {
    return UserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      birthDate: birthDate ?? this.birthDate,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  List<Object?> get props => [
    id,
    username,
    avatar,
    bio,
    birthDate,
    status,
    lastSeen,
  ];
}
