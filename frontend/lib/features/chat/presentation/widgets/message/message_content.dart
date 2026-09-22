import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/upload_progress.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/uploading_file_tile.dart';

import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/file_tile.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/inlineAudioPlayer.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/video_content_tile.dart';

class MessageContent extends StatelessWidget {
  final Message message;
  final bool isMe;

  /// Cancels this message's upload (shown as ✕ on the progress bar).
  final VoidCallback? onCancelUpload;

  const MessageContent({
    super.key,
    required this.message,
    required this.isMe,
    this.onCancelUpload,
  });

  bool get _isUploading => message.status == MessageStatus.uploading;
  bool get _isError => message.status == MessageStatus.error;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildStatusIcon(AppColorScheme colors) {
    switch (message.status) {
      case MessageStatus.uploading:
        return Icon(Icons.access_time_rounded, size: 11, color: colors.textSecondary);
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 13, color: colors.textSecondary);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 13, color: colors.textSecondary);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF4FC3F7));
      case MessageStatus.error:
        return const Icon(Icons.error_outline_rounded, size: 11, color: AppColors.error);
    }
  }

  Widget _withPadding(Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 2),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final formattedTime = _formatTime(message.createdAt);

    switch (message.fileType) {
      case MessageType.text:
        return _withPadding(
          Text(
            message.text ?? '',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15.5,
              height: 1.3,
              letterSpacing: 0.1,
            ),
          ),
        );

      case MessageType.image:
        return _buildImageContent(context, formattedTime, colors);

      case MessageType.video:
        return VideoContentTile(
          message: message,
          isUploading: _isUploading,
          formatBytes: _formatBytes,
          formattedTime: formattedTime,
          isMe: isMe,
          statusIcon: isMe ? _buildStatusIcon(colors) : null,
          onCancelUpload: onCancelUpload,
        );

      case MessageType.audio:
        if (_isUploading) {
          return _withPadding(
            UploadingFileTile(
              icon: Icons.mic_rounded,
              label: (message.originalName ?? '').startsWith('recording_')
                  ? 'Voice message'
                  : (message.originalName ?? 'Audio'),
              fileSize: message.fileSize,
              uploadedBytes: message.uploadedBytes,
              onCancel: onCancelUpload,
              color: const Color(0xFF4CC9F0),
            ),
          );
        }
        // A row without a URL (bad data) must not crash the whole list
        if (_isError || message.fileUrl == null) {
          return _withPadding(
            FileTile(
              icon: Icons.audiotrack_rounded,
              label: message.originalName ?? 'Audio',
              fileSize: message.fileSize,
              url: null,
              color: const Color(0xFF4CC9F0),
            ),
          );
        }
        return _withPadding(
          InlineAudioPlayer(
            url: message.fileUrl!,
            color: isMe ? colors.textPrimary : const Color(0xFF4CC9F0),
          ),
        );

      case MessageType.pdf:
        if (_isUploading) {
          return _withPadding(
            UploadingFileTile(
              icon: Icons.picture_as_pdf_outlined,
              label: message.originalName ?? 'Document.pdf',
              fileSize: message.fileSize,
              uploadedBytes: message.uploadedBytes,
              onCancel: onCancelUpload,
              color: AppColors.error,
            ),
          );
        }
        return _withPadding(
          FileTile(
            icon: Icons.picture_as_pdf_outlined,
            label: message.originalName ?? 'Document.pdf',
            fileSize: message.fileSize,
            url: message.fileUrl,
            color: AppColors.error,
          )
        );

      case MessageType.archive:
        if (_isUploading) {
          return _withPadding(
            UploadingFileTile(
              icon: Icons.folder_zip_outlined,
              label: message.originalName ?? 'Archive',
              fileSize: message.fileSize,
              uploadedBytes: message.uploadedBytes,
              onCancel: onCancelUpload,
              color: Colors.orangeAccent,
            ),
          );
        }
        return _withPadding(
          FileTile(
            icon: Icons.folder_zip_outlined,
            label: message.originalName ?? 'Archive',
            fileSize: message.fileSize,
            url: message.fileUrl,
            color: Colors.orangeAccent,
          )
        );

      case MessageType.file:
        if (_isUploading) {
          return _withPadding(
            UploadingFileTile(
              icon: Icons.insert_drive_file_outlined,
              label: message.originalName ?? 'File',
              fileSize: message.fileSize,
              uploadedBytes: message.uploadedBytes,
              onCancel: onCancelUpload,
              color: colors.textSecondary,
            ),
          );
        }
        return _withPadding(
          FileTile(
            icon: Icons.insert_drive_file_outlined,
            label: message.originalName ?? 'File',
            fileSize: message.fileSize,
            url: message.fileUrl,
            color: colors.textSecondary,
          )
        );

      case MessageType.unknown:
        return _withPadding(
          const Text(
            'Unsupported message type',
            style: TextStyle(
              color: AppColors.error,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
    }
  }

  Widget _buildImageContent(BuildContext context, String formattedTime, AppColorScheme colors) {
    Widget imageWidget;

    final hasUrl = message.fileUrl != null && message.fileUrl!.isNotEmpty;

    if ((_isUploading || _isError) && message.localPath != null) {
      imageWidget = Image.file(
        File(message.localPath!),
        width: 260,
        height: 190,
        fit: BoxFit.cover,
      );
    } else if (_isUploading || _isError || !hasUrl) {
      imageWidget = Container(
        width: 260,
        height: 190,
        color: colors.card,
        child: Center(
          child: Icon(Icons.image, color: colors.textTertiary, size: 40),
        ),
      );
    } else {
      imageWidget = Image.network(
        message.fileUrl!,
        width: 260,
        height: 190,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : SizedBox(
                width: 260,
                height: 190,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textPrimary,
                  ),
                ),
              ),
        // A dead link used to render Flutter's red error box in the chat
        errorBuilder: (_, _, _) => Container(
          width: 260,
          height: 190,
          color: colors.card,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: colors.textTertiary,
              size: 36,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: (_isUploading || _isError || !hasUrl)
          ? null
          : () {
              context.push('/image-viewer', extra: {
                'url': message.fileUrl!,
                'title': message.originalName,
                // A photo someone sent you in a chat is yours to keep
                'canDownload': true,
              });
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            imageWidget,
            if (_isUploading)
              MediaUploadOverlay(
                uploadedBytes: message.uploadedBytes,
                totalBytes: message.fileSize,
                onCancel: onCancelUpload,
              ),
            if (!_isUploading) _buildTimeOverlay(formattedTime, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOverlay(String formattedTime, AppColorScheme colors) {
    return Positioned(
      bottom: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedTime,
              style: TextStyle(
                // Always white — the pill is black in both themes
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(colors),
            ],
          ],
        ),
      ),
    );
  }
}
