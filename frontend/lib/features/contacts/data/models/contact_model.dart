import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';

class ContactModel extends Contact {
  const ContactModel({
    required super.id,
    required super.username,
    super.avatar,
    super.bio,
    super.lastSeen,
    super.status,
    super.isContact,
    super.isBlocked,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {

    final status = json['status']?.toString() ?? 'active';

    return ContactModel(
      id: json['id'],
      username: json['username'] ?? '',
      avatar: json['avatar'],
      bio: json['bio'],
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'].toString())
          : null,
      status: status,
      isContact: json['isContact'] ?? (status == 'active'),
      isBlocked: json['isBlocked'] ?? (status == 'blocked'),
    );
  }
}