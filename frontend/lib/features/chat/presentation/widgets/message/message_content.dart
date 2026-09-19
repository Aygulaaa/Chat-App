import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/uploading_file_tile.dart';

import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/file_tile.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/inlineAudioPlayer.dart';
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
        );

      case MessageType.audio:
        if (_isUploading) {
          return _withPadding(
            UploadingFileTile(
              icon: Icons.audiotrack_rounded,
              label: message.originalName ?? 'Audio',
              fileSize: message.fileSize,
              uploadedBytes: message.uploadedBytes,
              color: const Color(0xFF4CC9F0),
            ),
          );
        }
        if (_isError) {
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

    if ((_isUploading || _isError) && message.localPath != null) {
      imageWidget = Image.file(
        File(message.localPath!),
        width: 260,
        height: 190,
        fit: BoxFit.cover,
      );
    } else if (_isUploading || _isError) {
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
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            imageWidget,
            if (_isUploading) _buildUploadOverlay(colors),
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
                color: colors.textPrimary.withValues(alpha: 0.9),
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

  Widget _buildUploadOverlay(AppColorScheme colors) {
    final uploaded = message.uploadedBytes ?? 0;
    final total = message.fileSize ?? 1;
    final progress = (uploaded / total).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  color: colors.textPrimary,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatBytes(uploaded)} / ${_formatBytes(total)}',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}