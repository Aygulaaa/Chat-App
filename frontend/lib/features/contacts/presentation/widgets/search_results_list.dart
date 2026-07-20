import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/empty_contacts.dart';

class SearchResultsList extends ConsumerWidget {
  final String query;

  const SearchResultsList({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(searchUsersProvider(query));

    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('$e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (results) => results.isEmpty
          ? const EmptyContacts(
              message: 'No users found',
              subtitle: 'Try a different username',
              icon: Icons.search_off_rounded,
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(
                color: Colors.white10,
                indent: 70,
                height: 1,
              ),
              itemBuilder: (_, i) => ContactTile(contact: results[i]),
            ),
    );
  }
}