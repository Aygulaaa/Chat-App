import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/format_last_seen.dart';
import 'package:my_chat_app/features/auth/presentation/pages/auth_page.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:my_chat_app/features/profile/presentation/pages/edit_profile_screen.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  final UserEntity? user;
  const ProfileScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user != null) return _OtherProfile(user: user!);

    final profileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (authState.user == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: Center(child: Text('Please log in', style: TextStyle(color: context.textSecondary))),
      );
    }
    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.appBg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.appBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48.sp),
              SizedBox(height: 16.h),
              Text('$e', style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () => ref.read(userProfileProvider.notifier).fetchProfile(),
                child: const Text('Retry', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ),
      data: (me) {
        if (me == null) {
          return Scaffold(
            backgroundColor: context.appBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return _MyProfile(user: me);
      },
    );
  }
}

// ─── My Profile ───────────────────────────────────────────────────────────────
class _MyProfile extends StatelessWidget {
  final UserEntity user;
  const _MyProfile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          _ProfileAppBar(user: user, isMe: true),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 24.h),
                _InfoCard(user: user),
                SizedBox(height: 12.h),
                _ActionCard(user: user),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Other Profile ────────────────────────────────────────────────────────────
class _OtherProfile extends ConsumerWidget {
  final UserEntity user;
  const _OtherProfile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullUserAsync = ref.watch(userByIdProvider(user.id));
    final effectiveUser = fullUserAsync.maybeWhen(
      data: (fetchedUser) => fetchedUser ?? user,
      orElse: () => user,
    );

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          _ProfileAppBar(user: effectiveUser, isMe: false),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 24.h),
                _InfoCard(user: effectiveUser),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _ProfileAppBar extends ConsumerWidget {
  final UserEntity user;
  final bool isMe;
  const _ProfileAppBar({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(userStatusProvider).onlineUsers[user.id] ?? false;
    final socketLastSeen = ref.watch(userStatusProvider).lastSeen[user.id];

    if (!isMe) {
      final userAsync = ref.watch(userByIdProvider(user.id));
      userAsync.whenData((fetchedUser) {
        if (fetchedUser?.lastSeen != null &&
            !ref.read(userStatusProvider).lastSeen.containsKey(user.id)) {
          Future.microtask(() => ref
              .read(userStatusProvider.notifier)
              .setLastSeen(user.id, fetchedUser!.lastSeen));
        }
      });
    }

    final effectiveLastSeen = socketLastSeen ?? user.lastSeen;
    final isDark = !context.isLight;

    return SliverAppBar(
      expandedHeight: 280.h,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
      iconTheme: IconThemeData(color: context.textPrimary),
      actions: [
        if (isMe)
          IconButton(
            icon: Icon(Icons.edit_outlined, color: context.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF0B1120), Color(0xFF1E293B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
              ),
            ),
            // Glass shimmer band
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80.h,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        context.appBg.withOpacity(0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 60.h),
                ProfileAvatar(
                  username: user.username,
                  imageUrl: user.avatar,
                  isMe: isMe,
                ),
                SizedBox(height: 14.h),
                Text(
                  user.username,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4.h),
                _StatusLabel(isOnline: isOnline, lastSeen: effectiveLastSeen),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;
  const _StatusLabel({required this.isOnline, this.lastSeen});

  @override
  Widget build(BuildContext context) {
    if (isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.r,
            height: 7.r,
            decoration: const BoxDecoration(
              color: AppColors.online,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5.w),
          const Text('Online', style: TextStyle(color: AppColors.online, fontSize: 13)),
        ],
      );
    }
    if (lastSeen != null) {
      return Text(
        TimeUtils.formatLastSeen(lastSeen!),
        style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 13),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final UserEntity user;
  const _InfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: context.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.info_outline_rounded,
            label: 'Bio',
            value: user.bio?.isNotEmpty == true ? user.bio! : 'No bio set',
          ),
          Divider(color: context.glassBorder, height: 1, indent: 52.w),
          _InfoRow(
            icon: Icons.alternate_email_rounded,
            label: 'Username',
            value: '@${user.username}',
          ),
          if (user.birthDate != null) ...[
            Divider(color: context.glassBorder, height: 1, indent: 52.w),
            _InfoRow(
              icon: Icons.cake_outlined,
              label: 'Birthday',
              value: '${user.birthDate!.day}/${user.birthDate!.month}/${user.birthDate!.year}',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: const Icon(icon, color: AppColors.accent, size: 17),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: context.textTertiary, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Card ─────────────────────────────────────────────────────────────
class _ActionCard extends ConsumerWidget {
  final UserEntity user;
  const _ActionCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: context.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.settings_outlined,
            iconColor: AppColors.primary,
            label: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          Divider(color: context.glassBorder, height: 1, indent: 52.w),
          _ActionRow(
            icon: Icons.edit_outlined,
            iconColor: Colors.blueAccent,
            label: 'Edit Profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
            ),
          ),
          Divider(color: context.glassBorder, height: 1, indent: 52.w),
          _ActionRow(
            icon: Icons.logout_rounded,
            iconColor: AppColors.error,
            label: 'Log Out',
            labelColor: AppColors.error,
            onTap: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor == Colors.white ? context.textPrimary : labelColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}