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
    super.localPath,
    super.uploadedBytes,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawReadAt = json['readAt'] ?? json['read_at'];
    final rawDeliveredAt = json['deliveredAt'] ?? json['delivered_at'];

    final readAt = rawReadAt != null
        ? DateTime.tryParse(rawReadAt.toString())
        : null;
    final deliveredAt = rawDeliveredAt != null
        ? DateTime.tryParse(rawDeliveredAt.toString())
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
      localPath: json['localPath'],
      uploadedBytes: _parseNullableIntSafe(json['uploadedBytes']),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'fileUrl': fileUrl,
      'type': fileType.toString().split('.').last,
      'originalName': originalName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'localPath': localPath,
      'uploadedBytes': uploadedBytes,
    };
  }
}