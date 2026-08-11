import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
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
      backgroundColor: context.appBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: context.appBg,
            elevation: 0,
            title: Text(
              'Contacts',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                letterSpacing: -0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(64.h),
              child: ColoredBox(
                color: context.appBg,
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
        body: isSearching ? SearchResultsList(query: _query) : const ContactsList(),
      ),
    );
  }
}