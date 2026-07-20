import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/empty_contacts.dart';

class BlockedList extends ConsumerWidget {
  const BlockedList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedContactsProvider);

    return blockedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('$e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (blocked) => blocked.isEmpty
          ? const EmptyContacts(
              message: 'No blocked users',
              subtitle: 'Users you block will appear here',
              icon: Icons.block_rounded,
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: blocked.length,
              separatorBuilder: (_, __) => const Divider(
                color: Colors.white10,
                indent: 70,
                height: 1,
              ),
              itemBuilder: (_, i) => ContactTile(contact: blocked[i]),
            ),
    );
  }
}