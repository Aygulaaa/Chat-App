import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_content.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_context_menu.dart';
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
  final VoidCallback? onDelete;
  final void Function(String emoji)? onStickerSend;
  final bool? showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.time,
    this.reactions = const [],
    this.isGroup = false,
    this.senderAvatar,
    this.onAvatarTap,
    this.onDelete,
    this.onStickerSend,
    this.showAvatar,
  });

  void _openContextMenu(BuildContext context) {
    showMessageContextMenu(
      context: context,
      message: message,
      isMe: isMe,
      onCopy: () {
        if (message.text != null && message.text!.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: message.text!));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      onDelete: onDelete ?? () {},
      onStickerSend: onStickerSend ?? (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservesAvatarSlot = isGroup && !isMe;
    final rendersAvatarImage = reservesAvatarSlot && (showAvatar ?? true);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.5.h, horizontal: 12.w),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (reservesAvatarSlot)
              Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: rendersAvatarImage
                    ? GestureDetector(
                        onTap: onAvatarTap,
                        child: CircleAvatar(
                          radius: 13.r,
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
                      )
                    : SizedBox(width: 26.r),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  SelectionArea(
                    contextMenuBuilder: (context, selectableRegionState) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        selectableRegionState.hideToolbar();
                        _openContextMenu(context);
                      });
                      return const SizedBox.shrink();
                    },
                    child: _BubbleBody(
                      message: message,
                      isMe: isMe,
                      time: time,
                    ),
                  ),
                  if (reactions.isNotEmpty) ...[
                    SizedBox(height: 3.h),
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
    final colors = AppColors.of(context);
    final isMedia =
        message.fileType == MessageType.image ||
        message.fileType == MessageType.video;
    final isImage = message.fileType == MessageType.image;
    final isVideo = message.fileType == MessageType.video;
    final showTime = time != null && !isVideo && !isImage;

    const radiusBig = 16.0;
    const radiusTail = 4.0;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(radiusBig.r),
      topRight: Radius.circular(radiusBig.r),
      bottomLeft: Radius.circular((isMe ? radiusBig : radiusTail).r),
      bottomRight: Radius.circular((isMe ? radiusTail : radiusBig).r),
    );

    // Sent messages use a darker translucent white layer over the dark background,
    // creating a sleek Apple glass aesthetic instead of a flat solid fill.
    final bubbleColor = isMe
        ? colors.textPrimary.withValues(alpha: 0.08)
        : colors.card;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.glassBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: isMedia
            ? Stack(
                children: [
                  MessageContent(message: message, isMe: isMe),
                  if (isImage && showTime)
                    Positioned(
                      bottom: 6.h,
                      right: 8.w,
                      child: _ImageTimeOverlay(
                        time: time!,
                        isMe: isMe,
                        message: message,
                        colors: colors,
                      ),
                    ),
                ],
              )
            : Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      4.w,
                      3.h,
                      showTime ? (isMe ? 64.w : 52.w) : 14.w,
                      10.h,
                    ),
                    child: MessageContent(message: message, isMe: isMe),
                  ),
                  if (showTime)
                    Positioned(
                      bottom: 6.h,
                      right: 10.w,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time!,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              color: isMe
                                  ? colors.textPrimary.withValues(alpha: 0.7)
                                  : colors.textTertiary,
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 3.w),
                            MessageStatusTick(message: message),
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

class _ImageTimeOverlay extends StatelessWidget {
  final String time;
  final bool isMe;
  final dynamic message;
  final AppColorScheme colors;

  const _ImageTimeOverlay({
    required this.time,
    required this.isMe,
    required this.message,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 10.sp,
              color: colors.textPrimary.withValues(alpha: 0.9),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 3.w),
            MessageStatusTick(message: message),
          ],
        ],
      ),
    );
  }
}