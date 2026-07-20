import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/utils/format_last_seen.dart';
import 'package:my_chat_app/features/auth/presentation/pages/auth_page.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:my_chat_app/features/users/presentation/pages/edit_profile_screen.dart';
import 'package:my_chat_app/features/users/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/users/presentation/widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  final UserEntity? user;

  const ProfileScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print("profile screen use data ${user}");
    if (user != null) {
      return _OtherProfile(user: user!);
    }

    final profileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (authState.user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F14),
        body: Center(
          child: Text('Please log in', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0B0F14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '$e',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.read(userProfileProvider.notifier).fetchProfile(),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFF6366F1)),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (me) {
        if (me == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F14),
            body: Center(child: CircularProgressIndicator()),
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
      backgroundColor: const Color(0xFF0B0F14),
      body: CustomScrollView(
        slivers: [
          _ProfileAppBar(user: user, isMe: true),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _InfoCard(user: user),
                const SizedBox(height: 12),
                _ActionCard(user: user),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Other Profile ────────────────────────────────────────────────────────────

// ─── Other Profile ────────────────────────────────────────────────────────────

class _OtherProfile extends ConsumerWidget {
  final UserEntity user;
  const _OtherProfile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the provider that fetches the complete profile from your database/backend
    final fullUserAsync = ref.watch(userByIdProvider(user.id));
    
    final effectiveUser = fullUserAsync.maybeWhen(
      data: (fetchedUser) => fetchedUser ?? user,
      orElse: () => user,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: CustomScrollView(
        slivers: [
          // 3. Pass the dynamic, updated user entity down to the sub-widgets
          _ProfileAppBar(user: effectiveUser, isMe: false),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _InfoCard(
                  user: effectiveUser,
                ), // 🌟 The bio row now receives the full data!
                const SizedBox(height: 100),
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

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (isMe)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              ProfileAvatar(
                username: user.username,
                imageUrl: user.avatar,
                isMe: isMe,
              ),
              const SizedBox(height: 14),
              Text(
                user.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              _StatusLabel(isOnline: isOnline, lastSeen: effectiveLastSeen),
            ],
          ),
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
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Online',
            style: TextStyle(color: Colors.greenAccent, fontSize: 13),
          ),
        ],
      );
    }

    if (lastSeen != null) {
      return Text(
        TimeUtils.formatLastSeen(lastSeen!),
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    // ✅ null lastSeen = user has hideLastSeen on — show nothing
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.info_outline_rounded,
            label: 'Bio',
            value: user.bio?.isNotEmpty == true ? user.bio! : 'No bio set',
          ),
          const Divider(color: Colors.white10, height: 1, indent: 52),
          _InfoRow(
            icon: Icons.alternate_email_rounded,
            label: 'Username',
            value: '@${user.username}',
          ),
          if (user.birthDate != null) ...[
            const Divider(color: Colors.white10, height: 1, indent: 52),
            _InfoRow(
              icon: Icons.cake_outlined,
              label: 'Birthday',
              value:
                  '${user.birthDate!.day}/${user.birthDate!.month}/${user.birthDate!.year}',
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF818CF8), size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Card (my profile only) ───────────────────────────────────────────

class _ActionCard extends ConsumerWidget {
  final UserEntity user;
  const _ActionCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.settings_outlined,
            iconColor: const Color(0xFF6366F1),
            label: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 52),
          _ActionRow(
            icon: Icons.edit_outlined,
            iconColor: Colors.blueAccent,
            label: 'Edit Profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 52),
          _ActionRow(
  icon: Icons.logout_rounded,
  iconColor: Colors.redAccent,
  label: 'Log Out',
  labelColor: Colors.redAccent,
  onTap: () {
    // 1. Trigger the logout logic
    ref.read(authProvider.notifier).logout();
    
    // 2. Perform the navigation
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
