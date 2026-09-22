import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/utils/snackbar_utils.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

/// Saves one setting and tells the user if it didn't stick. The provider
/// already rolls the switch back on failure; without the catch the error
/// surfaced as an unhandled exception and the switch just snapped back
/// with no explanation.
Future<void> saveSetting(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> update,
) async {
  try {
    await ref.read(settingsProvider.notifier).updateSettings(update);
  } catch (_) {
    if (context.mounted) {
      SnackBarUtils.showSnack(
        context,
        "Couldn't save that setting. Check your connection.",
        isError: true,
      );
    }
  }
}

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;

    return SettingsScaffold(
      title: 'Notifications',
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          SettingsSection(
            title: 'Message notifications',
            footer:
                'When off, this account stops sending push notifications to '
                'your devices. New messages still appear inside the app.',
            children: [
              SettingsSwitchTile(
                icon: Icons.notifications_rounded,
                iconColor: SettingsColors.red,
                title: 'Push Notifications',
                value: settings?.notificationsEnabled ?? true,
                onChanged: settings == null
                    ? null
                    : (val) => saveSetting(context, ref, {
                        'notificationsEnabled': val,
                      }),
              ),
            ],
          ),
          const SettingsSection(
            title: 'Per chat',
            footer:
                'To silence a single conversation, long-press it in the chat '
                'list and choose Mute.',
            children: [
              SettingsTile(
                icon: Icons.volume_off_rounded,
                iconColor: SettingsColors.grey,
                title: 'Muted chats',
                subtitle: 'Managed from the chat list',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
