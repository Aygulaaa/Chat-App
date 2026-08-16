import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contact_tile.dart';

class BlockedContactsPage extends ConsumerWidget {
  const BlockedContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedContactsProvider);
    ref.listen(blockedContactsProvider, (previous, next) {
      print("Blocked list updated! New count: ${next.value?.length}");
    });

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.appBg,
        foregroundColor: context.textPrimary,
        title: Text(
          'Blocked Users',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: context.appBgGradient,
        ),
        child: blockedAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error: $err',
              style: const TextStyle(color: AppColors.error),
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
                    color: context.cardBg,
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