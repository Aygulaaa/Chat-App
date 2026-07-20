import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/blocked_contacts.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: settingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ── Notifications ─────────────────────────────────────
            SettingsSection(
              title: 'Notifications',
              children: [
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Push Notifications',
                  subtitle: 'Receive message notifications',
                  trailing: Switch(
                    value: settings?.notificationsEnabled ?? true,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'notificationsEnabled': val}),
                  ),
                ),
              ],
            ),

            // ── Privacy ───────────────────────────────────────────
            SettingsSection(
              title: 'Privacy',
              children: [
                SettingsTile(
                  icon: Icons.access_time_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'Hide Last Seen',
                  subtitle: 'Others won\'t see when you were last online',
                  trailing: Switch(
                    value: settings?.hideLastSeen ?? false,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'hideLastSeen': val}),
                  ),
                ),
                SettingsTile(
                  icon: Icons.done_all_rounded,
                  iconColor: Colors.tealAccent,
                  title: 'Hide Read Receipts',
                  subtitle: 'Others won\'t see when you\'ve read messages',
                  trailing: Switch(
                    value: settings?.hideReadReceipts ?? false,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'hideReadReceipts': val}),
                  ),
                ),
              ],
            ),

            // ── Appearance ────────────────────────────────────────
            SettingsSection(
              title: 'Appearance',
              children: [
                SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  iconColor: Colors.purpleAccent,
                  title: 'Theme',
                  subtitle: settings?.theme == 'dark' ? 'Dark' : 'Light',
                  onTap: () {
                    final current = settings?.theme ?? 'dark';
                    ref.read(settingsProvider.notifier).updateSettings({
                      'theme': current == 'dark' ? 'light' : 'dark',
                    });
                  },
                ),
              ],
            ),
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
                )
              ]),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}