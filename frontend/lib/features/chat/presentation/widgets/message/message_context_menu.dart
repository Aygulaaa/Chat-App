import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/action_menu.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_info.panel.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/sticker_strip.dart';

/// Call this from a long-press gesture to show the context menu overlay.
Future<void> showMessageContextMenu({
  required BuildContext context,
  required Message message,
  required bool isMe,
  required VoidCallback onCopy,
  required VoidCallback onDelete,
  required void Function(String emoji) onStickerSend,
}) {
  return Navigator.of(context).push(
    _ContextMenuRoute(
      message: message,
      isMe: isMe,
      onCopy: onCopy,
      onDelete: onDelete,
      onStickerSend: onStickerSend,
    ),
  );
}

// ─── Custom Overlay Route ───────────────────────────────────────────────────

class _ContextMenuRoute extends RawDialogRoute<void> {
  _ContextMenuRoute({
    required Message message,
    required bool isMe,
    required VoidCallback onCopy,
    required VoidCallback onDelete,
    required void Function(String emoji) onStickerSend,
  }) : super(
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black.withValues(alpha: 0.55),
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _ContextMenuPage(
              message: message,
              isMe: isMe,
              onCopy: onCopy,
              onDelete: onDelete,
              onStickerSend: onStickerSend,
              animation: animation,
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

// ─── Context Menu Overlay Page ───────────────────────────────────────────────

class _ContextMenuPage extends StatefulWidget {
  final Message message;
  final bool isMe;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final void Function(String emoji) onStickerSend;
  final Animation<double> animation;

  const _ContextMenuPage({
    required this.message,
    required this.isMe,
    required this.onCopy,
    required this.onDelete,
    required this.onStickerSend,
    required this.animation,
  });

  @override
  State<_ContextMenuPage> createState() => _ContextMenuPageState();
}

class _ContextMenuPageState extends State<_ContextMenuPage> {
  bool _showInfo = false;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.message.fileType == MessageType.image;
    final hasText =
        widget.message.text != null && widget.message.text!.isNotEmpty;

    final bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(16.r),
      topRight: Radius.circular(16.r),
      bottomLeft: Radius.circular(widget.isMe ? 16.r : 4.r),
      bottomRight: Radius.circular(widget.isMe ? 4.r : 16.r),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pop(),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: widget.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    StickerStrip(
                      isMe: widget.isMe,
                      onTap: (emoji) {
                        context.pop();
                        widget.onStickerSend(emoji);
                      },
                    ),
                    SizedBox(height: 10.h),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.fastOutSlowIn,
                      child: _showInfo
                          ? Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: MessageInfoPanel(
                                isMe: widget.isMe,
                                message: widget.message,
                                formatTime: _formatTime,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.76,
                        ),
                        child: Container(
                          padding: isImage
                              ? EdgeInsets.zero
                              : EdgeInsets.symmetric(
                                  vertical: 10.h, horizontal: 14.w),
                          decoration: BoxDecoration(
                            gradient:
                                widget.isMe ? AppColors.primaryGradient : null,
                            color: widget.isMe ? null : AppColors.darkCard,
                            borderRadius: bubbleRadius,
                            border: widget.isMe
                                ? null
                                : Border.all(
                                    color: AppColors.darkBorder
                                        .withValues(alpha: 0.6),
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 24.r,
                                offset: Offset(0, 8.h),
                              ),
                            ],
                          ),
                          child: isImage
                              ? ClipRRect(
                                  borderRadius: bubbleRadius,
                                  child: Image.network(
                                    widget.message.fileUrl ?? '',
                                    width: 220.w,
                                    height: 200.h,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(
                                  widget.message.text ?? '',
                                  style: TextStyle(
                                    color: AppColors.darkTextPrimary,
                                    fontSize: 15.sp,
                                    height: 1.35,
                                    letterSpacing: -0.15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    ActionMenu(
                      isMe: widget.isMe,
                      hasText: hasText,
                      showingInfo: _showInfo,
                      onCopy: () {
                        context.pop();
                        widget.onCopy();
                      },
                      onInfo: () => setState(() => _showInfo = !_showInfo),
                      onDelete: () {
                        context.pop();
                        widget.onDelete();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}