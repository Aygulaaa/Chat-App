import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class MessageStatusTick extends StatelessWidget {
  final Message message;
  final double size;

  const MessageStatusTick({
    super.key,
    required this.message,
    this.size = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Read / Seen (Double Blue Checks)
    if (message.status == MessageStatus.read || message.readAt != null) {
      return Icon(
        Icons.done_all_rounded,
        size: size,
        color: const Color(0xFF60A5FA),
      );
    }

    // 2. Delivered (Double Gray Checks)
    if (message.status == MessageStatus.delivered || message.deliveredAt != null) {
      return Icon(
        Icons.done_all_rounded,
        size: size,
        color: AppColors.darkTextTertiary,
      );
    }

    // 3. Sent to Server (Single Gray Check)
    if (message.status == MessageStatus.sent) {
      return Icon(
        Icons.check_rounded,
        size: size,
        color: AppColors.darkTextTertiary,
      );
    }

    // 4. File Uploading / Pending
    if (message.status == MessageStatus.uploading) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.darkTextTertiary,
        ),
      );
    }

    // 5. Delivery Failed / Error
    if (message.status == MessageStatus.error) {
      return Icon(
        Icons.error_outline_rounded,
        size: size,
        color: AppColors.error,
      );
    }

    // Fallback for pending text messages
    return Icon(
      Icons.access_time_rounded,
      size: size,
      color: AppColors.darkTextTertiary,
    );
  }
}