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
    super.replyTo,
    super.reactions,
    super.localId,
  });

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

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

    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null;

    return MessageModel(
      id: _parseInt(json['id']),
      chatId: _parseInt(json['chatId'] ?? json['chat_id']),
      senderId: _parseInt(json['senderId'] ?? json['sender_id']),
      text: json['text']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString(),
      fileType: _parseType(json['type'] ?? json['fileType']),
      originalName: json['originalName']?.toString(),
      mimeType: json['mimeType']?.toString(),
      fileSize: _parseNullableInt(json['fileSize']),
      createdAt: (createdAt ?? DateTime.now()).toLocal(),
      deliveredAt: deliveredAt?.toLocal(),
      readAt: readAt?.toLocal(),
      status: status,
      localPath: json['localPath']?.toString(),
      uploadedBytes: _parseNullableInt(json['uploadedBytes']),
      replyTo: _parseReply(json['replyTo']),
      reactions: parseReactions(json['reactions']),
    );
  }

  /// `[{userId, emoji}, …]` → entities. Rows without a user or an emoji are
  /// dropped rather than rendered as empty pills.
  static List<MessageReaction> parseReactions(dynamic raw) {
    if (raw is! List) return const [];
    final result = <MessageReaction>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final userId = _parseNullableInt(item['userId'] ?? item['user_id']);
      final emoji = item['emoji']?.toString() ?? '';
      if (userId == null || emoji.isEmpty) continue;
      result.add(MessageReaction(userId: userId, emoji: emoji));
    }
    return result;
  }

  /// Any [Message] (not just models) → model. `copyWith` on the entity returns
  /// a plain [Message]; without this those rows could never be cached again.
  factory MessageModel.fromEntity(Message m) {
    if (m is MessageModel) return m;
    return MessageModel(
      id: m.id,
      chatId: m.chatId,
      senderId: m.senderId,
      text: m.text,
      fileUrl: m.fileUrl,
      fileType: m.fileType,
      originalName: m.originalName,
      mimeType: m.mimeType,
      fileSize: m.fileSize,
      createdAt: m.createdAt,
      deliveredAt: m.deliveredAt,
      readAt: m.readAt,
      status: m.status,
      localPath: m.localPath,
      uploadedBytes: m.uploadedBytes,
      replyTo: m.replyTo,
      reactions: m.reactions,
      localId: m.localId,
    );
  }

  static ReplyPreview? _parseReply(dynamic raw) {
    if (raw is! Map) return null;
    final id = _parseNullableInt(raw['id']);
    if (id == null) return null;
    return ReplyPreview(
      id: id,
      senderId: _parseInt(raw['senderId']),
      senderName: raw['senderName']?.toString(),
      text: raw['text']?.toString(),
      fileType: _parseType(raw['type'] ?? raw['fileType']),
      originalName: raw['originalName']?.toString(),
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
    final reply = replyTo;
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'fileUrl': fileUrl,
      'type': fileType.name,
      'originalName': originalName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'localPath': localPath,
      'uploadedBytes': uploadedBytes,
      'reactions': [
        for (final r in reactions) {'userId': r.userId, 'emoji': r.emoji},
      ],
      if (reply != null)
        'replyTo': {
          'id': reply.id,
          'senderId': reply.senderId,
          'senderName': reply.senderName,
          'text': reply.text,
          'type': reply.fileType.name,
          'originalName': reply.originalName,
        },
    };
  }
}
