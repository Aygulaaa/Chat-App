import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_content.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_status_tick.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/reaction_row.dart';

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
      padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 12.w),
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
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  _BubbleBody(message: message, isMe: isMe, time: time),
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
    final isImage = message.fileType == MessageType.image;

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(13.r),
      topRight: Radius.circular(13.r),
      bottomLeft: Radius.circular(isMe ? 13.r : 10.r),
      bottomRight: Radius.circular(isMe ? 10.r : 13.r),
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      // 2. Conditionally set zero padding for image messages
      padding: isImage
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(vertical: 10.h, horizontal: 15.w),
      decoration: BoxDecoration(
        gradient: isMe ? AppColors.primaryGradient : null,
        color: isMe ? null : AppColors.darkCard,
        borderRadius: borderRadius,
        border: isMe ? null : Border.all(color: AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? AppColors.primary.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: isMe ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // 3. Clip the image child to respect the bubble's rounded corners
      child: ClipRRect(
        child: isImage
            ? Stack(
                children: [
                  MessageContent(message: message, isMe: isMe),
                  if (time != null)
                    Positioned(
                      bottom: 6.h,
                      right: 8.w,
                      child: _ImageTimeOverlay(
                        time: time!,
                        isMe: isMe,
                        status: message.status,
                      ),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  MessageContent(message: message, isMe: isMe),
                  if (time != null) ...[
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(vertical:0, horizontal: 0),
                          child: Text(
                            time!,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.darkTextTertiary,
                            ),
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
      ),
    );
  }
}

/// Floating semi-transparent pill for timestamps over images (Telegram style)
class _ImageTimeOverlay extends StatelessWidget {
  final String time;
  final bool isMe;
  final dynamic status;

  const _ImageTimeOverlay({
    required this.time,
    required this.isMe,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 3.w),
            MessageStatusTick(status: status),
          ],
        ],
      ),
    );
  }
}