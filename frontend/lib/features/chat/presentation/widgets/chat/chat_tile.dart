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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress != null
            ? () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              }
            : null,
        splashColor: (context.isLight ? Colors.black : Colors.white)
            .withValues(alpha: 0.05),
        highlightColor: (context.isLight ? Colors.black : Colors.white)
            .withValues(alpha: 0.03),
        child: Container(
          padding: EdgeInsets.only(left: 16.w),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 9.h, bottom: 9.h),
                child: UserAvatar(
                  name: name,
                  imageUrl: avatarUrl,
                  isOnline: isOnline,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(right: 16.w, top: 9.h, bottom: 20.h),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: (context.isLight
                                ? Colors.black
                                : Colors.white)
                            .withValues(alpha: 0.08),
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isMuted) ...[
                                Icon(
                                  Icons.notifications_off_rounded,
                                  size: 13.sp,
                                  color: context.textTertiary,
                                ),
                                SizedBox(width: 4.w),
                              ],
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: unread
                                      ? (isMuted
                                          ? context.textTertiary
                                          : AppColors.primary)
                                      : context.textTertiary,
                                  fontWeight: unread && !isMuted
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: context.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unread) ...[
                            SizedBox(width: 8.w),
                            _UnreadBadge(
                              count: unreadCount,
                              isMuted: isMuted,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  final bool isMuted;

  const _UnreadBadge({
    required this.count,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = isMuted
        ? (context.isLight ? const Color(0xFFC4C9CC) : const Color(0xFF5A636D))
        : AppColors.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      constraints: BoxConstraints(minWidth: 20.w, minHeight: 20.h),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}