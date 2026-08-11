import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat_lis.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat_search_bar.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat_search_result.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/create_group_modal.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  String get _query => _searchController.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    ref.read(chatSocketDataSourceProvider);
    ref.read(chatProvider);
    ref.read(userStatusProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatState = ref.read(chatProvider);
      if (chatState.chats.isEmpty && !chatState.isLoading) {
        ref.read(chatProvider.notifier).loadChats();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.appBg,
        foregroundColor: context.textPrimary,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isSearching
              ? ChatSearchBar(
                  key: const ValueKey('search'),
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  onClose: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                    });
                  },
                )
              : Text(
                  'Chats',
                  key: const ValueKey('title'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20.sp,
                    color: context.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
        ),
        actions: _isSearching
            ? []
            : [
                IconButton(
                  icon: Icon(Icons.search_rounded, color: context.textSecondary),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                IconButton(
                  icon: Icon(Icons.group_add_outlined, color: context.textSecondary),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CreateGroupModal(),
                    );
                  },
                ),
              ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.appBgGradient),
        child: _isSearching
            ? ChatSearchResults(query: _query)
            : const ChatList(),
      ),
    );
  }
}