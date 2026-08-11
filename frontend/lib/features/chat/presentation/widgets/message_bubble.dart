import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message_content.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message_status_tick.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/reaction_row.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? time;
  final List<String> reactions;
  final bool isGroup;
  final String? senderAvatar;
  final VoidCallback? onAvatarTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.time,
    this.reactions = const [],
    this.isGroup = false,
    this.senderAvatar,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final showAvatar = isGroup && !isMe;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 12.w),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showAvatar)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 12.r,
                    backgroundColor: AppColors.darkCard,
                    backgroundImage: senderAvatar != null
                        ? CachedNetworkImageProvider(senderAvatar!)
                        : null,
                    child: senderAvatar == null
                        ? Icon(
                            Icons.person,
                            size: 16.r,
                            color: AppColors.darkTextTertiary,
                          )
                        : null,
                  ),
                ),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _BubbleBody(
                    message: message,
                    isMe: isMe,
                    time: time,
                  ),
                  if (reactions.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    ReactionRow(reactions: reactions),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? time;

  const _BubbleBody({
    required this.message,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 14.w),
      decoration: BoxDecoration(
        gradient: isMe ? AppColors.primaryGradient : null,
        color: isMe ? null : AppColors.darkCard,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18.r),
          topRight: Radius.circular(18.r),
          bottomLeft: Radius.circular(isMe ? 18.r : 4.r),
          bottomRight: Radius.circular(isMe ? 4.r : 18.r),
        ),
        border: isMe
            ? null
            : Border.all(color: AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? AppColors.primary.withOpacity(0.30)
                : Colors.black.withOpacity(0.15),
            blurRadius: isMe ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MessageContent(message: message, isMe: isMe),
          if (time != null) ...[
            SizedBox(height: 4.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time!,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: 3.w),
                  MessageStatusTick(status: message.status),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}