import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class UploadingFileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? fileSize;
  final int? uploadedBytes;
  final Color color;

  const UploadingFileTile({
    super.key,
    required this.icon,
    required this.label,
    this.fileSize,
    this.uploadedBytes,
    required this.color,
  });

  String _formatBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = uploadedBytes ?? 0;
    final total = fileSize ?? 1;
    final progress = (uploaded / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkBorder,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
                Icon(icon, color: color, size: 14),
              ],
            ),
          ),
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
                Text(
                  '${_formatBytes(uploaded)} / ${_formatBytes(fileSize)}',
                  style: const TextStyle(
                    color: AppColors.darkTextTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}