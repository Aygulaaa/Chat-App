import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/upload_progress.dart';

/// A file / voice message that is waiting for, or in the middle of, its upload.
class UploadingFileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? fileSize;
  final int? uploadedBytes;
  final Color color;
  final VoidCallback? onCancel;

  const UploadingFileTile({
    super.key,
    required this.icon,
    required this.label,
    this.fileSize,
    this.uploadedBytes,
    required this.color,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                UploadProgress(
                  uploadedBytes: uploadedBytes,
                  totalBytes: fileSize,
                  color: color,
                  textColor: context.textSecondary,
                  onCancel: onCancel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
