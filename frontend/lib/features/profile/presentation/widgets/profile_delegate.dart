import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/format_last_seen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';

class ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final UserEntity user;
  final bool isMe;
  final double maxExtentHeight;
  final double minExtentHeight;

  ProfileHeaderDelegate({
    required this.user,
    required this.isMe,
    required this.maxExtentHeight,
    required this.minExtentHeight,
  });

  @override
  double get maxExtent => maxExtentHeight;

  @override
  double get minExtent => minExtentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    final progress =
        (shrinkOffset / (maxExtentHeight - minExtentHeight)).clamp(0.0, 1.0);

    return Consumer(
      builder: (context, ref, child) {
        final isOnline =
            ref.watch(userStatusProvider).onlineUsers[user.id] ?? false;
        final socketLastSeen = ref.watch(userStatusProvider).lastSeen[user.id];

        if (!isMe) {
          final userAsync = ref.watch(userByIdProvider(user.id));
          userAsync.whenData((fetchedUser) {
            if (fetchedUser?.lastSeen != null &&
                !ref.read(userStatusProvider).lastSeen.containsKey(user.id)) {
              Future.microtask(
                () => ref
                    .read(userStatusProvider.notifier)
                    .setLastSeen(user.id, fetchedUser!.lastSeen),
              );
            }
          });
        }

        final effectiveLastSeen = socketLastSeen ?? user.lastSeen;

        final titleLeft = Tween<double>(begin: 20.w, end: isMe ? 20.w : 56.w)
            .transform(progress);
        final titleBottom =
            Tween<double>(begin: 20.h, end: 12.h).transform(progress);

        return ClipRRect(
          child: Container(
            color: context.appBg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: (1.0 - (progress * 1.2)).clamp(0.0, 1.0),
                  child: user.avatar != null && user.avatar!.isNotEmpty
                      ? Image.network(
                          user.avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _FallbackGradient(user: user),
                        )
                      : _FallbackGradient(user: user),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: 0.8 * (1.0 - progress),
                        ),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                if (!isMe)
                  Positioned(
                    top: topPadding + 4.h,
                    left: 8.w,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                if (isMe)
                  Positioned(
                    top: topPadding + 4.h,
                    right: 8.w,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      onPressed: () => context.push('/edit-profile', extra: user),
                    ),
                  ),
                Positioned(
                  left: titleLeft,
                  right: 60.w,
                  bottom: titleBottom,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize:
                              Tween<double>(begin: 24.sp, end: 18.sp).transform(
                            progress,
                          ),
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 6,
                              color: Colors.black.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                      if (progress < 0.85) ...[
                        SizedBox(height: 2.h),
                        Opacity(
                          opacity: (1.0 - (progress * 2)).clamp(0.0, 1.0),
                          child: _StatusLabel(
                            isOnline: isOnline,
                            lastSeen: effectiveLastSeen,
                            lastSeenFuzzy: ref.watch(userStatusProvider).lastSeenFuzzy[user.id] ?? user.lastSeenFuzzy,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool shouldRebuild(covariant ProfileHeaderDelegate oldDelegate) {
    return oldDelegate.user != user ||
        oldDelegate.isMe != isMe ||
        oldDelegate.maxExtentHeight != maxExtentHeight ||
        oldDelegate.minExtentHeight != minExtentHeight;
  }
}

class _FallbackGradient extends StatelessWidget {
  final UserEntity user;
  const _FallbackGradient({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: 72.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;
  final String? lastSeenFuzzy;
  const _StatusLabel({required this.isOnline, this.lastSeen, this.lastSeenFuzzy});

  @override
  Widget build(BuildContext context) {
    final shadow = [
      Shadow(
        offset: const Offset(0, 1),
        blurRadius: 4,
        color: Colors.black.withValues(alpha: 0.7),
      ),
    ];

    if (isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.r,
            height: 8.r,
            decoration: const BoxDecoration(
              color: AppColors.online,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            'Online',
            style: TextStyle(
              color: AppColors.online,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              shadows: shadow,
            ),
          ),
        ],
      );
    }
    if (lastSeen != null || lastSeenFuzzy != null) {
      return Text(
        TimeUtils.formatLastSeen(lastSeen, fuzzy: lastSeenFuzzy),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
          shadows: shadow,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}