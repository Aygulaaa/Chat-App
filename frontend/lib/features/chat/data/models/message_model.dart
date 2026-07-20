import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    super.text,
    super.fileUrl,
    super.fileType,
    super.originalName,
    super.mimeType,
    super.fileSize,
    required super.createdAt,
    super.deliveredAt,
    super.readAt,
    super.status,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final readAt = json['readAt'] != null
        ? DateTime.tryParse(json['readAt'].toString())
        : null;
    final deliveredAt = json['deliveredAt'] != null
        ? DateTime.tryParse(json['deliveredAt'].toString())
        : null;

    final status = readAt != null
        ? MessageStatus.read
        : deliveredAt != null
        ? MessageStatus.delivered
        : MessageStatus.sent;

    print('🔍 derived status: $status');

    int _parseIntSafe(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    int? _parseNullableIntSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    return MessageModel(
      id: _parseIntSafe(json['id']),
      chatId: _parseIntSafe(json['chatId']),
      senderId: _parseIntSafe(json['senderId']),
      text: json['text'] ?? '',
      fileUrl: json['fileUrl'],
      fileType: _parseType(json['type'] ?? json['fileType']),
      originalName: json['originalName'],
      mimeType: json['mimeType'],
      fileSize: _parseNullableIntSafe(json['fileSize']),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']).toLocal() 
          : DateTime.now(),
      deliveredAt: deliveredAt?.toLocal(),
      readAt: readAt?.toLocal(),
      status: status,
    );
  }

  static MessageType _parseType(dynamic raw) {
    switch (raw?.toString()) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'pdf':
        return MessageType.pdf;
      case 'archive':
        return MessageType.archive;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }
}