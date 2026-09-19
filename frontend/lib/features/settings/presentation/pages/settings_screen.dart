import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/change_password_modal.dart'
    as my_chat_app_password_modal;
import 'package:my_chat_app/features/settings/presentation/widgets/local_app_lock_modal.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: context.isLight ? const Color(0xFFF1F1F4) : const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '$e',
            style: TextStyle(color: AppColors.error, fontSize: 13.sp),
          ),
        ),
        data: (settings) => ListView(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          children: [
            // ── Notifications ──────────────────────────────────────
            SettingsSection(
              title: 'Notifications',
              children: [
                SettingsTile(
                  icon: Icons.notifications_rounded,
                  iconColor: context.textPrimary,
                  title: 'Push Notifications',
                  subtitle: 'Receive message notifications',
                  trailing: Switch(
                    value: settings?.notificationsEnabled ?? true,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'notificationsEnabled': val}),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // ── Privacy ─────────────────────────────────────────────
            SettingsSection(
              title: 'Privacy and Security',
              children: [
                SettingsTile(
                  icon: Icons.access_time_rounded,
                  iconColor: context.textPrimary,
                  title: 'Hide Last Seen',
                  subtitle: "Others won't see when you were last online",
                  trailing: Switch(
                    value: settings?.hideLastSeen ?? false,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'hideLastSeen': val}),
                  ),
                ),
                SettingsTile(
                  icon: Icons.done_all_rounded,
                  iconColor: context.textPrimary,
                  title: 'Hide Read Receipts',
                  subtitle: "Others won't see when you've read messages",
                  trailing: Switch(
                    value: settings?.hideReadReceipts ?? false,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'hideReadReceipts': val}),
                  ),
                ),
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: context.textPrimary,
                  title: 'Change Password',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) =>
                          const my_chat_app_password_modal.ChangePasswordModal(),
                    );
                  },
                ),
                SettingsTile(
                  icon: Icons.devices_rounded,
                  iconColor: context.textPrimary,
                  title: 'Active Sessions',
                  subtitle: 'Manage devices logged into your account',
                  onTap: () {
                    context.push('/sessions');
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final localAuth = ref.watch(localAuthProvider);
                    return SettingsTile(
                      icon: Icons.security_rounded,
                      iconColor: context.textPrimary,
                      title: 'Local App Lock',
                      subtitle: localAuth.isPasswordSet ? 'Enabled' : 'Disabled',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const LocalAppLockModal(),
                        );
                      },
                    );
                  },
                ),
                SettingsTile(
                  icon: Icons.block_outlined,
                  iconColor: context.textPrimary,
                  title: 'Blocked Contacts',
                  onTap: () {
                    context.push('/blocked-contacts');
                  },
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // ── Appearance ──────────────────────────────────────────
            SettingsSection(
              title: 'Appearance',
              children: [
                SettingsTile(
                  icon: settings?.theme == 'dark'
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  iconColor: context.textPrimary,
                  title: 'Theme',
                  subtitle:
                      settings?.theme == 'dark' ? 'Dark Mode' : 'Light Mode',
                  onTap: () {
                    final current = settings?.theme ?? 'dark';
                    ref.read(settingsProvider.notifier).updateSettings({
                      'theme': current == 'dark' ? 'light' : 'dark',
                    });
                  },
                ),
              ],
            ),

            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }
}