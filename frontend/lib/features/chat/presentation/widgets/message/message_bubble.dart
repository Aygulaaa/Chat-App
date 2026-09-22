import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_content.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_context_menu.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_info.panel.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_status_tick.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/reaction_row.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/reply_quote.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/swipe_to_reply.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? time;
  final bool isGroup;
  final String? senderAvatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onDelete;

  /// Put / swap / remove my emoji reaction on this message.
  final void Function(String emoji)? onReact;
  final bool? showAvatar;

  /// Start replying to this message (swipe, or "Reply" in the long-press menu).
  final VoidCallback? onReply;

  /// The quote at the top of a reply was tapped → jump to the original.
  final void Function(int messageId)? onQuoteTap;

  /// Re-send a message (text or upload) that failed.
  final VoidCallback? onRetry;

  /// Cancel a queued / in-flight upload, or discard a failed message.
  final VoidCallback? onCancelSend;
  final int? currentUserId;

  /// Group + my message: loads who received / read it for Message Info.
  final ReceiptsLoader? loadReceipts;

  /// Briefly true after jumping to this message from a quote.
  final bool highlighted;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.time,
    this.isGroup = false,
    this.senderAvatar,
    this.onAvatarTap,
    this.onDelete,
    this.onReact,
    this.showAvatar,
    this.onReply,
    this.onQuoteTap,
    this.onRetry,
    this.onCancelSend,
    this.currentUserId,
    this.loadReceipts,
    this.highlighted = false,
  });

  bool get _isFailed => message.status == MessageStatus.error;

  void _openContextMenu(BuildContext context) {
    HapticFeedback.selectionClick();
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
      myReaction: message.reactionOf(currentUserId),
      onReact: message.isPending ? null : onReact,
      onReply: message.isPending ? null : onReply,
      loadReceipts: isMe && isGroup && !message.isPending ? loadReceipts : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservesAvatarSlot = isGroup && !isMe;
    final rendersAvatarImage = reservesAvatarSlot && (showAvatar ?? true);

    return SwipeToReply(
      swipeLeft: isMe,
      onReply: message.isPending ? null : onReply,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.primary.withValues(alpha: 0),
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
                    // A plain long-press (instead of hijacking text selection)
                    // opens the menu on EVERY message type — photos, voice
                    // notes and files included — and never fires twice.
                    GestureDetector(
                      onLongPress: () => _openContextMenu(context),
                      onTap: _isFailed ? onRetry : null,
                      child: _BubbleBody(
                        message: message,
                        isMe: isMe,
                        time: time,
                        currentUserId: currentUserId,
                        onQuoteTap: onQuoteTap,
                        onCancelUpload: onCancelSend,
                        onReact: onReact,
                      ),
                    ),
                    if (_isFailed)
                      Padding(
                        padding: EdgeInsets.only(top: 3.h, right: 2.w),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 12.sp,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'Not sent · Tap to retry',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? time;
  final int? currentUserId;
  final void Function(int messageId)? onQuoteTap;
  final VoidCallback? onCancelUpload;
  final void Function(String emoji)? onReact;

  const _BubbleBody({
    required this.message,
    required this.isMe,
    required this.time,
    this.currentUserId,
    this.onQuoteTap,
    this.onCancelUpload,
    this.onReact,
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

    final reply = message.replyTo;
    final quote = reply == null
        ? null
        : Padding(
            padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, isMedia ? 6.h : 0),
            child: ReplyQuote(
              reply: reply,
              authorLabel: reply.senderId == currentUserId
                  ? 'You'
                  : (reply.senderName ?? 'Message'),
              onTap: onQuoteTap == null ? null : () => onQuoteTap!(reply.id),
            ),
          );

    final body = ClipRRect(
      borderRadius: borderRadius,
      child: _buildContent(context, colors, isMedia, isImage, showTime),
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        border: Border.all(color: colors.glassBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // IntrinsicWidth lets the quote stretch to exactly the bubble's width
      // while the bubble itself still shrink-wraps its content.
      child: quote == null
          ? body
          : IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [quote, body],
              ),
            ),
    );
  }

  /// The reaction pills. On a photo they float over its bottom-left corner;
  /// in a text bubble they sit under the text, left of the clock — the corner
  /// Telegram puts them in, either way.
  Widget _reactions({required bool onMedia}) {
    return ReactionRow(
      reactions: message.reactions,
      currentUserId: currentUserId,
      onMedia: onMedia,
      onTap: onReact,
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColorScheme colors,
    bool isMedia,
    bool isImage,
    bool showTime,
  ) {
    final hasReactions = message.reactions.isNotEmpty;

    return isMedia
        ? Stack(
            children: [
              MessageContent(
                message: message,
                isMe: isMe,
                onCancelUpload: onCancelUpload,
              ),
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
              if (hasReactions)
                Positioned(
                  bottom: 6.h,
                  left: 8.w,
                  // Keep clear of the clock pill on the other corner
                  right: 56.w,
                  child: _reactions(onMedia: true),
                ),
            ],
          )
        : Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      4.w,
                      3.h,
                      showTime ? (isMe ? 64.w : 52.w) : 14.w,
                      hasReactions ? 2.h : 10.h,
                    ),
                    child: MessageContent(
                      message: message,
                      isMe: isMe,
                      onCancelUpload: onCancelUpload,
                    ),
                  ),
                  if (hasReactions)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        8.w,
                        0,
                        showTime ? (isMe ? 64.w : 52.w) : 8.w,
                        8.h,
                      ),
                      child: _reactions(onMedia: false),
                    ),
                ],
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
              // Always white: the pill behind it is black in BOTH themes
              color: Colors.white.withValues(alpha: 0.92),
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
