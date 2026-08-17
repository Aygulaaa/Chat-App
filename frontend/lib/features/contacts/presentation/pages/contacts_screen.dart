import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: context.appBgGradient,
          ),
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // Sticky Header: Title + Search Bar with Glassmorphic Blur
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ContactsHeaderDelegate(
                    height: 120.h,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          color: context.appBgGradient.colors.first.withValues(alpha: 0.85),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contacts',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22.sp,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              ContactsSearchBar(
                                controller: _searchController,
                                onChanged: (val) => setState(() => _query = val),
                                onClear: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content List
                SliverToBoxAdapter(
                  child: isSearching
                      ? SearchResultsList(query: _query)
                      : const ContactsList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _ContactsHeaderDelegate({required this.height, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _ContactsHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}