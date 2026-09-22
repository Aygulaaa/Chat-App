// domain/entities/message.dart
import 'package:equatable/equatable.dart';

enum MessageStatus { sent, delivered, read, uploading, error }

enum MessageType {
  text,
  image,
  video,
  audio,
  pdf,
  archive,
  file,
  unknown;

  static MessageType fromString(String? type) {
    if (type == null) return MessageType.text;
    return MessageType.values.firstWhere(
      (e) => e.name.toLowerCase() == type.toLowerCase(),
      orElse: () => MessageType.unknown,
    );
  }
}

/// The quoted message shown at the top of a reply bubble.
///
/// It is a snapshot (id + who + a short preview), not the full [Message], so a
/// reply can always render its quote even when the original is far outside
/// the loaded page of history.
class ReplyPreview extends Equatable {
  final int id;
  final int senderId;
  final String? senderName;
  final String? text;
  final MessageType fileType;
  final String? originalName;

  const ReplyPreview({
    required this.id,
    required this.senderId,
    this.senderName,
    this.text,
    this.fileType = MessageType.text,
    this.originalName,
  });

  /// Builds the quote for a message the user is about to reply to.
  factory ReplyPreview.fromMessage(Message message, {String? senderName}) {
    return ReplyPreview(
      id: message.id,
      senderId: message.senderId,
      senderName: senderName,
      text: message.text,
      fileType: message.fileType,
      originalName: message.originalName,
    );
  }

  /// One line describing the quoted content ("Photo", a file name, the text…).
  String get summary {
    switch (fileType) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎬 Video';
      case MessageType.audio:
        return '🎤 Voice message';
      case MessageType.pdf:
      case MessageType.archive:
      case MessageType.file:
        return '📎 ${originalName ?? 'File'}';
      case MessageType.text:
      case MessageType.unknown:
        final value = text?.trim() ?? '';
        return value.isEmpty ? 'Message' : value;
    }
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    text,
    fileType,
    originalName,
  ];
}

/// One person's emoji reaction on a message. Everyone gets at most one, so
/// tapping a different emoji replaces it and tapping the same one clears it.
class MessageReaction extends Equatable {
  final int userId;
  final String emoji;

  const MessageReaction({required this.userId, required this.emoji});

  @override
  List<Object?> get props => [userId, emoji];
}

class Message extends Equatable {
  final int id;
  final int chatId;
  final int senderId;
  final String? text;
  final String? fileUrl;
  final MessageType fileType;
  final String? originalName;
  final String? mimeType;
  final int? fileSize;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final MessageStatus status;
  final String? localPath;
  final int? uploadedBytes;

  /// Set when this message is a reply to another one.
  final ReplyPreview? replyTo;

  /// Emoji reactions, oldest first.
  final List<MessageReaction> reactions;

  /// The temporary id this message had while it was still being sent.
  ///
  /// Kept after the server assigns the real [id] so the list can keep using
  /// the same widget key — otherwise the bubble is torn down and rebuilt the
  /// moment the send completes (visible flicker, images reload).
  final int? localId;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    this.fileType = MessageType.text,
    this.fileUrl,
    this.originalName,
    this.mimeType,
    this.fileSize,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.status = MessageStatus.sent,
    this.localPath,
    this.uploadedBytes,
    this.replyTo,
    this.reactions = const [],
    this.localId,
  });

  /// Stable identity for widget keys. See [localId].
  int get viewKey => localId ?? id;

  /// The emoji `userId` put on this message, if any.
  String? reactionOf(int? userId) {
    if (userId == null) return null;
    for (final r in reactions) {
      if (r.userId == userId) return r.emoji;
    }
    return null;
  }

  /// Temporary ids are `microsecondsSinceEpoch` (16 digits); real ids are
  /// database sequence values.
  bool get isPending => id > 1000000000000;

  /// One line for the chat list, Telegram-style: media is named ("Photo",
  /// "Video", "Voice message", the file's name) and a caption follows it.
  String get preview {
    final caption = text?.trim() ?? '';
    final String label;
    switch (fileType) {
      case MessageType.image:
        label = 'Photo';
      case MessageType.video:
        label = 'Video';
      case MessageType.audio:
        label = 'Voice message';
      case MessageType.pdf:
      case MessageType.archive:
      case MessageType.file:
        label = originalName ?? 'File';
      case MessageType.text:
      case MessageType.unknown:
        return caption;
    }
    return caption.isEmpty ? label : '$label, $caption';
  }

  Message copyWith({
    int? id,
    int? chatId,
    int? senderId,
    String? text,
    MessageType? fileType,
    String? fileUrl,
    String? originalName,
    String? mimeType,
    int? fileSize,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    MessageStatus? status,
    String? localPath,
    int? uploadedBytes,
    ReplyPreview? replyTo,
    bool clearReplyTo = false,
    List<MessageReaction>? reactions,
    int? localId,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      replyTo: clearReplyTo ? null : replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      localId: localId ?? this.localId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    chatId,
    senderId,
    text,
    fileUrl,
    fileType,
    originalName,
    mimeType,
    fileSize,
    createdAt,
    deliveredAt,
    readAt,
    status,
    localPath,
    uploadedBytes,
    replyTo,
    reactions,
    localId,
  ];
}
