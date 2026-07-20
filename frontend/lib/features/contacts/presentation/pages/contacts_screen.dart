import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contact_list.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contacts_search_bar.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/search_results_list.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            title: const Text(
              'Contacts',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: ColoredBox(
                color: const Color(0xFF0F172A),
                child: ContactsSearchBar(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
            ),
          ),
        ],
        body: isSearching
            ? SearchResultsList(query: _query)
            : const ContactsList(),
      ),
    );
  }
}