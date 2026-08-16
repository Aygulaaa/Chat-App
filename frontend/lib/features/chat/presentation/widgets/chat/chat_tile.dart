import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/user_avatar.dart';

class ChatTile extends ConsumerWidget {
  final int userId;
  final String name;
  final String? avatarUrl;
  final String message;
  final String time;
  final bool unread;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isMuted;

  const ChatTile({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.message,
    required this.time,
    required this.unread,
    this.unreadCount = 1,
    required this.onTap,
    this.onLongPress,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStatusState = ref.watch(userStatusProvider);
    final bool isOnline = userStatusState.onlineUsers[userId] == true;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          borderRadius: BorderRadius.circular(18.r),
          splashColor: AppColors.primary.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: unread
                    ? AppColors.primary.withValues(
                        alpha: context.isLight ? 0.45 : 0.35,
                      )
                    : context.glassBorder,
                width: unread ? 1.5 : 1,
              ),
              boxShadow: [
                if (unread)
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: context.isLight ? 0.18 : 0.12,
                    ),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                BoxShadow(
                  color: context.isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : const Color(0x10000000),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                UserAvatar(
                  name: name,
                  imageUrl: avatarUrl,
                  isOnline: isOnline,
                ),
                SizedBox(width: 13.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: unread
                              ? context.textSecondary
                              : context.textTertiary,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (isMuted) ...[
                          Icon(
                            Icons.volume_off,
                            size: 14.sp,
                            color: context.textTertiary,
                          ),
                          SizedBox(width: 4.w),
                        ],
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: unread
                                ? (context.isLight
                                    ? AppColors.primary
                                    : AppColors.accent)
                                : context.textTertiary,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    if (unread) _UnreadBadge(count: unreadCount),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}