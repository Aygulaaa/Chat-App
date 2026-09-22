import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

/// The little emoji pills that sit on the corner of a bubble, Telegram-style:
/// one pill per emoji with its count, the one I picked tinted and outlined.
/// Tapping a pill adds my reaction to it, or takes mine back off.
class ReactionRow extends StatelessWidget {
  final List<MessageReaction> reactions;

  /// Used to know which pill is mine.
  final int? currentUserId;

  /// True over a photo / video, where the pills float on a dark scrim.
  final bool onMedia;

  final void Function(String emoji)? onTap;

  const ReactionRow({
    super.key,
    required this.reactions,
    this.currentUserId,
    this.onMedia = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Counts per emoji, keeping the order they were first added in.
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final mine = currentUserId == null
        ? null
        : reactions
              .where((r) => r.userId == currentUserId)
              .map((r) => r.emoji)
              .firstOrNull;

    final colors = AppColors.of(context);

    return Wrap(
      spacing: 4.w,
      runSpacing: 3.h,
      children: [
        for (final entry in counts.entries)
          _Pill(
            emoji: entry.key,
            count: entry.value,
            isMine: entry.key == mine,
            onMedia: onMedia,
            colors: colors,
            onTap: onTap == null ? null : () => onTap!(entry.key),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isMine;
  final bool onMedia;
  final AppColorScheme colors;
  final VoidCallback? onTap;

  const _Pill({
    required this.emoji,
    required this.count,
    required this.isMine,
    required this.onMedia,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color textColor;
    if (isMine) {
      background = colors.primary.withValues(alpha: onMedia ? 0.85 : 0.22);
      textColor = onMedia ? Colors.white : colors.textPrimary;
    } else if (onMedia) {
      background = Colors.black.withValues(alpha: 0.55);
      textColor = Colors.white;
    } else {
      background = colors.textPrimary.withValues(alpha: 0.08);
      textColor = colors.textSecondary;
    }

    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isMine
                ? colors.primary.withValues(alpha: 0.7)
                : (onMedia
                      ? Colors.white.withValues(alpha: 0.18)
                      : colors.glassBorder),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 12.5.sp)),
            // A single reaction just shows the emoji, like Telegram
            if (count > 1) ...[
              SizedBox(width: 3.w),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
