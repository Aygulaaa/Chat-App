import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';

class BlockedContactsPage extends ConsumerWidget {
  const BlockedContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedContactsProvider);

    return SettingsScaffold(
      title: 'Blocked Users',
      body: Container(
        child: blockedAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Text(
              "Couldn't load blocked users",
              style: TextStyle(color: context.textTertiary),
            ),
          ),
          data: (blocked) {
            if (blocked.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.block_flipped,
                      color: context.textTertiary.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No blocked users',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              itemCount: blocked.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final contact = blocked[index];

                return Container(
                  decoration: BoxDecoration(
                    color: context.glassCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.glassBorder),
                  ),
                  child: ContactTile(contact: contact),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
