import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
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
      loading: () => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ],
      ),
      error: (e, _) => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$e',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      data: (results) {
        if (results.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyContacts(
                  message: 'No users found',
                  subtitle: 'Try a different username',
                  icon: Icons.search_off_rounded,
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final contact = results[index];

                  return Column(
                    children: [
                      ContactTile(contact: contact),
                      if (index < results.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 70),
                          child: const Divider(
                            color: Colors.white10,
                            height: 1,
                          ),
                        ),
                    ],
                  );
                },
                childCount: results.length,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const SizedBox.shrink(),
                  childCount: 0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}