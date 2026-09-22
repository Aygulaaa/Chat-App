import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

/// The quoted message: an accent bar, who wrote it, and a one-line preview.
///
/// Used in two places — at the top of a reply bubble, and (with [onClose]) as
/// the "Replying to…" bar above the message input.
class ReplyQuote extends StatelessWidget {
  final ReplyPreview reply;

  /// "You" when the quoted message is the viewer's own.
  final String authorLabel;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  /// Inside a bubble the quote sits on a tinted panel; in the input bar the
  /// bar itself is the panel.
  final bool filled;

  const ReplyQuote({
    super.key,
    required this.reply,
    required this.authorLabel,
    this.onTap,
    this.onClose,
    this.filled = true,
  });

  IconData? get _leadingIcon {
    switch (reply.fileType) {
      case MessageType.image:
        return Icons.image_rounded;
      case MessageType.video:
        return Icons.videocam_rounded;
      case MessageType.audio:
        return Icons.mic_rounded;
      case MessageType.pdf:
      case MessageType.archive:
      case MessageType.file:
        return Icons.insert_drive_file_rounded;
      case MessageType.text:
      case MessageType.unknown:
        return null;
    }
  }

  /// [ReplyPreview.summary] without the emoji prefix — we draw a real icon.
  String get _previewText {
    switch (reply.fileType) {
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Voice message';
      case MessageType.pdf:
      case MessageType.archive:
      case MessageType.file:
        return reply.originalName ?? 'File';
      case MessageType.text:
      case MessageType.unknown:
        return reply.summary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _leadingIcon;

    final content = IntrinsicHeight(
      child: Row(
        mainAxisSize: filled ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(
            fit: filled ? FlexFit.loose : FlexFit.tight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 1.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 13.sp, color: context.textSecondary),
                      SizedBox(width: 4.w),
                    ],
                    Flexible(
                      child: Text(
                        _previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13.sp,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, size: 18.sp),
              color: context.textTertiary,
              tooltip: 'Cancel reply',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );

    final panel = filled
        ? Container(
            padding: EdgeInsets.fromLTRB(6.w, 5.h, 10.w, 5.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: context.isLight ? 0.10 : 0.12,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: content,
          )
        : content;

    if (onTap == null) return panel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: panel,
    );
  }
}
