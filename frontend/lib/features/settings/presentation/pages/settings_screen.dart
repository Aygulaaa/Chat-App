import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/blocked_contacts.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/change_password_modal.dart' as my_chat_app_password_modal;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17.sp,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: AppColors.error, fontSize: 13.sp)),
        ),
        data: (settings) => ListView(
          padding: EdgeInsets.only(bottom: 40.h),
          children: [
            // ── Notifications ──────────────────────────────────────
            SettingsSection(
              title: 'Notifications',
              children: [
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.primary,
                  title: 'Push Notifications',
                  subtitle: 'Receive message notifications',
                  trailing: Switch(
                    value: settings?.notificationsEnabled ?? true,
                    activeColor: AppColors.primary,
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'notificationsEnabled': val}),
                  ),
                ),
              ],
            ),

            // ── Privacy ─────────────────────────────────────────────
            SettingsSection(
              title: 'Privacy',
              children: [
                SettingsTile(
                  icon: Icons.access_time_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'Hide Last Seen',
                  subtitle: "Others won't see when you were last online",
                  trailing: Switch(
                    value: settings?.hideLastSeen ?? false,
                    activeColor: AppColors.primary,
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'hideLastSeen': val}),
                  ),
                ),
                SettingsTile(
                  icon: Icons.done_all_rounded,
                  iconColor: Colors.tealAccent,
                  title: 'Hide Read Receipts',
                  subtitle: "Others won't see when you've read messages",
                  trailing: Switch(
                    value: settings?.hideReadReceipts ?? false,
                    activeColor: AppColors.primary,
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'hideReadReceipts': val}),
                  ),
                ),
              ],
            ),

            // ── Appearance ──────────────────────────────────────────
            SettingsSection(
              title: 'Appearance',
              children: [
                SettingsTile(
                  icon: settings?.theme == 'dark'
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  iconColor: Colors.purpleAccent,
                  title: 'Theme',
                  subtitle: settings?.theme == 'dark' ? 'Dark Mode' : 'Light Mode',
                  onTap: () {
                    final current = settings?.theme ?? 'dark';
                    ref.read(settingsProvider.notifier).updateSettings({
                      'theme': current == 'dark' ? 'light' : 'dark',
                    });
                  },
                ),
              ],
            ),

            // ── Security ─────────────────────────────────────────────
            SettingsSection(
              title: 'Security',
              children: [
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: Colors.orangeAccent,
                  title: 'Change Password',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const my_chat_app_password_modal.ChangePasswordModal(),
                    );
                  },
                ),
              ],
            ),

            // ── Blocked ─────────────────────────────────────────────
            SettingsSection(
              title: 'Blocked Contacts',
              children: [
                SettingsTile(
                  icon: Icons.block_outlined,
                  iconColor: Colors.cyanAccent,
                  title: 'Blocked Contacts',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BlockedContactsPage()),
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}