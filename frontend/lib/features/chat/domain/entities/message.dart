import 'package:equatable/equatable.dart';

enum MessageStatus { sent, delivered, read, uploading, error }

enum MessageType { text, image, video, audio, pdf, archive, file }

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

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
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
  });

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
  ];
}
