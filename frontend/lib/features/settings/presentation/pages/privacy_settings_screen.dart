import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/settings/presentation/pages/notifications_settings_screen.dart'
    show saveSetting;
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final blockedCount = ref.watch(
      blockedContactsProvider.select((v) => v.value?.length),
    );
    final appLockOn = ref.watch(
      localAuthProvider.select((s) => s.isPasswordSet),
    );

    return SettingsScaffold(
      title: 'Privacy and Security',
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          SettingsSection(
            title: 'Security',
            footer:
                'Passcode Lock protects the app on this device only. Your '
                'account password is what you use to sign in.',
            children: [
              SettingsTile(
                icon: Icons.pin_rounded,
                iconColor: SettingsColors.green,
                title: 'Passcode Lock',
                value: appLockOn ? 'On' : 'Off',
                onTap: () => context.push('/settings/app-lock'),
              ),
              SettingsTile(
                icon: Icons.key_rounded,
                iconColor: SettingsColors.blue,
                title: 'Change Password',
                onTap: () => context.push('/settings/change-password'),
              ),
              SettingsTile(
                icon: Icons.devices_rounded,
                iconColor: SettingsColors.orange,
                title: 'Active Sessions',
                onTap: () => context.push('/sessions'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Privacy',
            children: [
              SettingsTile(
                icon: Icons.block_rounded,
                iconColor: SettingsColors.red,
                title: 'Blocked Users',
                value: blockedCount == null
                    ? null
                    : (blockedCount == 0 ? 'None' : '$blockedCount'),
                onTap: () => context.push('/blocked-contacts'),
              ),
            ],
          ),
          SettingsSection(
            footer:
                "If you hide your last seen time, you won't be able to see "
                "other people's either. Your online status is always visible.",
            children: [
              SettingsSwitchTile(
                icon: Icons.access_time_filled_rounded,
                iconColor: SettingsColors.cyan,
                title: 'Hide Last Seen',
                value: settings?.hideLastSeen ?? false,
                onChanged: settings == null
                    ? null
                    : (val) => saveSetting(context, ref, {'hideLastSeen': val}),
              ),
            ],
          ),
          SettingsSection(
            footer:
                "If you turn off read receipts, you won't see when others "
                'have read your messages either.',
            children: [
              SettingsSwitchTile(
                icon: Icons.done_all_rounded,
                iconColor: SettingsColors.purple,
                title: 'Hide Read Receipts',
                value: settings?.hideReadReceipts ?? false,
                onChanged: settings == null
                    ? null
                    : (val) =>
                          saveSetting(context, ref, {'hideReadReceipts': val}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
