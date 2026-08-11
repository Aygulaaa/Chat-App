import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/empty_contacts.dart';

class ContactsList extends ConsumerWidget {
  const ContactsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return contactsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(
              '$e',
              style: const TextStyle(color: AppColors.darkTextTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(contactsProvider.notifier).refresh(),
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
      data: (contacts) {
        if (contacts.isEmpty) return const EmptyContacts();

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: contacts.length,
          separatorBuilder: (_, __) => const Divider(
            color: AppColors.darkBorder,
            indent: 70,
            height: 1,
          ),
          itemBuilder: (context, index) {
            final contact = contacts[index];
            final showHeader = index == 0 ||
                contact.username[0].toUpperCase() !=
                    contacts[index - 1].username[0].toUpperCase();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 0, 4),
                    child: Text(
                      contact.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ContactTile(contact: contact),
              ],
            );
          },
        );
      },
    );
  }
}