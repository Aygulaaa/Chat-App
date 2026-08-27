import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

const _kStickers = ['😂', '❤️', '👍', '😮', '😢', '🔥', '🎉', '👏', '😍'];

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

    // Telegram Asymmetric Corner Radii
    final bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(16.r),
      topRight: Radius.circular(16.r),
      bottomLeft: Radius.circular(widget.isMe ? 16.r : 4.r),
      bottomRight: Radius.circular(widget.isMe ? 4.r : 16.r),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
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
                    // 1. Telegram Sticker/Reaction Bar
                    _StickerStrip(
                      isMe: widget.isMe,
                      onTap: (emoji) {
                        Navigator.of(context).pop();
                        widget.onStickerSend(emoji);
                      },
                    ),
                    SizedBox(height: 10.h),

                    // 2. Expandable Info Panel
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.fastOutSlowIn,
                      child: _showInfo
                          ? Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _MessageInfoPanel(
                                isMe: widget.isMe,
                                message: widget.message,
                                formatTime: _formatTime,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // 3. Highlighted Telegram Message Preview
                    GestureDetector(
                      onTap: () {}, // Prevent backdrop dismiss on preview tap
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
                            gradient: widget.isMe ? AppColors.primaryGradient : null,
                            color: widget.isMe ? null : AppColors.darkCard,
                            borderRadius: bubbleRadius,
                            border: widget.isMe
                                ? null
                                : Border.all(
                                    color: AppColors.darkBorder.withValues(alpha: 0.6),
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

                    // 4. Telegram Popup Action Card
                    _ActionMenu(
                      isMe: widget.isMe,
                      hasText: hasText,
                      showingInfo: _showInfo,
                      onCopy: () {
                        Navigator.of(context).pop();
                        widget.onCopy();
                      },
                      onInfo: () => setState(() => _showInfo = !_showInfo),
                      onDelete: () {
                        Navigator.of(context).pop();
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

// ─── Reaction/Sticker Strip ──────────────────────────────────────────────────

class _StickerStrip extends StatelessWidget {
  final bool isMe;
  final void Function(String emoji) onTap;

  const _StickerStrip({required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppColors.darkBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          itemCount: _kStickers.length,
          itemBuilder: (context, index) {
            return _StickerButton(
              emoji: _kStickers[index],
              onTap: () => onTap(_kStickers[index]),
            );
          },
        ),
      ),
    );
  }
}

class _StickerButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _StickerButton({required this.emoji, required this.onTap});

  @override
  State<_StickerButton> createState() => _StickerButtonState();
}

class _StickerButtonState extends State<_StickerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl.forward().then((_) => _ctrl.reverse());
        Future.delayed(const Duration(milliseconds: 80), widget.onTap);
      },
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Center(
            child: Text(
              widget.emoji,
              style: TextStyle(fontSize: 22.sp),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Expanded Telegram Info Panel ────────────────────────────────────────────

class _MessageInfoPanel extends StatelessWidget {
  final bool isMe;
  final Message message;
  final String Function(DateTime?) formatTime;

  const _MessageInfoPanel({
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

// ─── Action Menu Popover ──────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final bool isMe;
  final bool hasText;
  final bool showingInfo;
  final VoidCallback onCopy;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

  const _ActionMenu({
    required this.isMe,
    required this.hasText,
    required this.showingInfo,
    required this.onCopy,
    required this.onInfo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final List<_TileSpec> tiles = [
      if (hasText)
        _TileSpec(
          icon: Icons.content_copy_rounded,
          label: 'Copy',
          onTap: onCopy,
        ),
      _TileSpec(
        icon: showingInfo ? Icons.info_rounded : Icons.info_outline_rounded,
        label: 'Message Info',
        onTap: onInfo,
        iconColor: AppColors.accent,
      ),
      if (isMe)
        _TileSpec(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          onTap: onDelete,
          iconColor: AppColors.error,
          labelColor: AppColors.error,
        ),
    ];

    return Container(
      width: 200.w,
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.darkBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1.h,
                  thickness: 0.6.h,
                  color: AppColors.darkBorder.withValues(alpha: 0.5),
                ),
              _ActionTile(spec: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TileSpec {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color? labelColor;

  const _TileSpec({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AppColors.darkTextSecondary,
    this.labelColor,
  });
}

class _ActionTile extends StatefulWidget {
  final _TileSpec spec;

  const _ActionTile({required this.spec});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.spec.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        color: _pressed
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        child: Row(
          children: [
            Icon(
              widget.spec.icon,
              size: 18.sp,
              color: widget.spec.iconColor,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                widget.spec.label,
                style: TextStyle(
                  color: widget.spec.labelColor ?? AppColors.darkTextPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}