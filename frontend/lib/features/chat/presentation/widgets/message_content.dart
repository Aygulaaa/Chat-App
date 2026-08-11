import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/inlineAudioPlayer.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageContent extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageContent({super.key, required this.message, required this.isMe});

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
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.fileUrl!,
            width: 200,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
          ),
        );

      case MessageType.video:
        return _FileTile(
          icon: Icons.videocam_outlined,
          label: message.originalName ?? 'Video',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: Colors.purpleAccent,
        );

      case MessageType.audio:
        return InlineAudioPlayer(
          url: message.fileUrl!,
          color: isMe ? AppColors.darkTextPrimary : const Color(0xFF4CC9F0),
        );

      case MessageType.pdf:
        return _FileTile(
          icon: Icons.picture_as_pdf_outlined,
          label: message.originalName ?? 'Document.pdf',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: AppColors.error,
        );

      case MessageType.archive:
        return _FileTile(
          icon: Icons.folder_zip_outlined,
          label: message.originalName ?? 'Archive',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: Colors.orangeAccent,
        );

      case MessageType.file:
        return _FileTile(
          icon: Icons.insert_drive_file_outlined,
          label: message.originalName ?? 'File',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: AppColors.accent,
        );
    }
  }
}

class _FileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? fileSize;
  final String? url;
  final Color color;

  const _FileTile({
    required this.icon,
    required this.label,
    required this.fileSize,
    required this.url,
    required this.color,
  });

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (url == null) return;
        final uri = Uri.parse(url!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.darkBorder,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fileSize != null)
                    Text(
                      _formatSize(fileSize),
                      style: const TextStyle(
                        color: AppColors.darkTextTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.download_outlined,
              color: AppColors.darkTextTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}