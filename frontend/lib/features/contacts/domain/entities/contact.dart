import 'package:equatable/equatable.dart';

class Contact extends Equatable {
  final int id;
  final String username;
  final String? avatar;
  final String? bio;
  final DateTime? lastSeen;
  final String? lastSeenFuzzy;
  final String status; 
  final bool isContact;
  final bool isBlocked;

  const Contact({
    required this.id,
    required this.username,
    this.avatar,
    this.bio,
    this.lastSeen,
    this.lastSeenFuzzy,
    this.status = 'active',
    this.isContact = false,
    this.isBlocked = false,
  });

  Contact copyWith({
    int? id,
    String? username,
    String? avatar,
    String? bio,
    DateTime? lastSeen,
    String? lastSeenFuzzy,
    String? status,
    bool? isContact,
    bool? isBlocked,
  }) {
    return Contact(
      id: id ?? this.id,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSeenFuzzy: lastSeenFuzzy ?? this.lastSeenFuzzy,
      status: status ?? this.status,
      isContact: isContact ?? this.isContact,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  @override
  List<Object?> get props =>
      [id, username, avatar, bio, lastSeen, lastSeenFuzzy, status, isContact, isBlocked];
}