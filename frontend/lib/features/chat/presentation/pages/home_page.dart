import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
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
      backgroundColor: const Color(0xFF0B0F14),

      // ───────────────── APP BAR ─────────────────
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,

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
              : const Text(
                  'Chats',
                  key: ValueKey('title'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),

        actions: _isSearching
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.group_add_outlined),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B0F14), Color(0xFF111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isSearching
            ? ChatSearchResults(query: _query)
            : const ChatList(),
      ),
    );
  }
}
