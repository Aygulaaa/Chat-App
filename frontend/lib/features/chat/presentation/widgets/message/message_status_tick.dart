import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class MessageStatusTick extends StatelessWidget {
  final MessageStatus status;

  const MessageStatusTick({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.uploading:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.darkTextTertiary,
          ),
        );
      case MessageStatus.error:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: AppColors.error,
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.check_rounded,
          size: 14,
          color: AppColors.darkTextTertiary,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: AppColors.darkTextTertiary,
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Color(0xFF60A5FA),
        );
    }
  }
}