import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/file_tile.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/inlineAudioPlayer.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/uploading_file_tile.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/video_content_tile.dart';

class MessageContent extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageContent({
    super.key,
    required this.message,
    required this.isMe,
  });

  bool get _isUploading => message.status == MessageStatus.uploading;
  bool get _isError => message.status == MessageStatus.error;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    switch (message.fileType) {
      case MessageType.text:
        return Text(
          message.text ?? '',
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 15,
            height: 1.45,
          ),
        );

      case MessageType.image:
        return _buildImageContent(context);

      case MessageType.video:
        return VideoContentTile(
          message: message,
          isUploading: _isUploading,
          formatBytes: _formatBytes,
        );

      case MessageType.audio:
        if (_isUploading) {
          return UploadingFileTile(
            icon: Icons.audiotrack_rounded,
            label: message.originalName ?? 'Audio',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: const Color(0xFF4CC9F0),
          );
        }
        if (_isError) {
          return FileTile(
            icon: Icons.audiotrack_rounded,
            label: message.originalName ?? 'Audio',
            fileSize: message.fileSize,
            url: null,
            color: const Color(0xFF4CC9F0),
          );
        }
        return InlineAudioPlayer(
          url: message.fileUrl!,
          color: isMe ? AppColors.darkTextPrimary : const Color(0xFF4CC9F0),
        );

      case MessageType.pdf:
        if (_isUploading) {
          return UploadingFileTile(
            icon: Icons.picture_as_pdf_outlined,
            label: message.originalName ?? 'Document.pdf',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: AppColors.error,
          );
        }
        return FileTile(
          icon: Icons.picture_as_pdf_outlined,
          label: message.originalName ?? 'Document.pdf',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: AppColors.error,
        );

      case MessageType.archive:
        if (_isUploading) {
          return UploadingFileTile(
            icon: Icons.folder_zip_outlined,
            label: message.originalName ?? 'Archive',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: Colors.orangeAccent,
          );
        }
        return FileTile(
          icon: Icons.folder_zip_outlined,
          label: message.originalName ?? 'Archive',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: Colors.orangeAccent,
        );

      case MessageType.file:
        if (_isUploading) {
          return UploadingFileTile(
            icon: Icons.insert_drive_file_outlined,
            label: message.originalName ?? 'File',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: AppColors.accent,
          );
        }
        return FileTile(
          icon: Icons.insert_drive_file_outlined,
          label: message.originalName ?? 'File',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: AppColors.accent,
        );

      case MessageType.unknown:
        return const Text(
          'Unsupported message type',
          style: TextStyle(
            color: AppColors.error,
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }

  Widget _buildImageContent(BuildContext context) {
    Widget imageWidget;

    if ((_isUploading || _isError) && message.localPath != null) {
      imageWidget = Image.file(
        File(message.localPath!),
        width: 200,
        fit: BoxFit.cover,
      );
    } else if (_isUploading || _isError) {
      imageWidget = Container(
        width: 200,
        height: 150,
        color: AppColors.darkCard,
        child: const Center(
          child: Icon(Icons.image, color: AppColors.darkTextTertiary, size: 40),
        ),
      );
    } else {
      imageWidget = Image.network(
        message.fileUrl!,
        width: 200,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
      );
    }

    return GestureDetector(
      onTap: (_isUploading || _isError)
          ? null
          : () {
              context.push('/image-viewer', extra: {
                'url': message.fileUrl!,
                'title': message.originalName,
              });
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            imageWidget,
            if (_isUploading) _buildUploadOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    final uploaded = message.uploadedBytes ?? 0;
    final total = message.fileSize ?? 1;
    final progress = (uploaded / total).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatBytes(uploaded)} / ${_formatBytes(total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}