import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class MessageInfoPanel extends StatelessWidget {
  final bool isMe;
  final Message message;
  final String Function(DateTime?) formatTime;

  const MessageInfoPanel({
    super.key,
    required this.isMe,
    required this.message,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final status = message.status;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.darkBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16.r,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(
            icon: Icons.check_rounded,
            iconColor: AppColors.darkTextTertiary,
            label: 'Sent',
            time: formatTime(message.createdAt),
          ),
          if (status == MessageStatus.delivered ||
              status == MessageStatus.read) ...[
            SizedBox(height: 6.h),
            _InfoRow(
              icon: Icons.done_all_rounded,
              iconColor: AppColors.darkTextTertiary,
              label: 'Delivered',
              time: formatTime(message.deliveredAt),
            ),
          ],
          if (status == MessageStatus.read) ...[
            SizedBox(height: 6.h),
            _InfoRow(
              icon: Icons.done_all_rounded,
              iconColor: AppColors.accent,
              label: 'Read',
              time: formatTime(message.readAt),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String time;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: iconColor),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(width: 12.w),
        if (time.isNotEmpty)
          Text(
            time,
            style: TextStyle(
              color: AppColors.darkTextPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}