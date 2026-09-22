import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/dialog_utils.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

/// Settings hub: who you are at the top, then one row per area, each opening
/// its own page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Log Out',
      message: 'You will need your password to sign back in on this device.',
      confirmLabel: 'Log Out',
      confirmColor: Colors.redAccent,
    );
    if (confirmed) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(userProfileProvider).value ?? ref.watch(authProvider).user;
    final settings = ref.watch(settingsProvider).value;
    final appLockOn = ref.watch(
      localAuthProvider.select((s) => s.isPasswordSet),
    );

    return SettingsScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          if (user != null) _ProfileHeader(user: user),

          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.notifications_rounded,
                iconColor: SettingsColors.red,
                title: 'Notifications',
                value: (settings?.notificationsEnabled ?? true) ? 'On' : 'Off',
                onTap: () => context.push('/settings/notifications'),
              ),
              SettingsTile(
                icon: Icons.lock_rounded,
                iconColor: SettingsColors.grey,
                title: 'Privacy and Security',
                value: appLockOn ? 'Passcode on' : null,
                onTap: () => context.push('/settings/privacy'),
              ),
              SettingsTile(
                icon: Icons.devices_rounded,
                iconColor: SettingsColors.orange,
                title: 'Devices',
                onTap: () => context.push('/sessions'),
              ),
              SettingsTile(
                icon: Icons.palette_rounded,
                iconColor: SettingsColors.cyan,
                title: 'Appearance',
                value: context.colors.label,
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),

          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                iconColor: SettingsColors.red,
                title: 'Log Out',
                destructive: true,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),

          Center(
            child: Text(
              'Navihat Chat · v1.0.0',
              style: TextStyle(color: context.textTertiary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserEntity user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final bio = user.bio?.trim() ?? '';

    return SettingsSection(
      children: [
        InkWell(
          onTap: () => context.push('/edit-profile', extra: user),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                _Avatar(url: user.avatar, name: user.username),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bio.isEmpty ? 'Add a bio, photo and more' : bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: context.textTertiary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;

  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final placeholder = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return SizedBox(
      width: 62,
      height: 62,
      child: url == null || url!.isEmpty
          ? placeholder
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}
