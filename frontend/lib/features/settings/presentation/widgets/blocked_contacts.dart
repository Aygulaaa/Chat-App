import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
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
      backgroundColor: AppColors.darkBg, 
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.darkCard,
        foregroundColor: Colors.white,
        title: const Text(
          'Blocked Users',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          
          gradient: LinearGradient(
            colors: [AppColors.darkBg, AppColors.darkInputFill],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: blockedAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
          ),
          data: (blocked) {
            if (blocked.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_flipped, color: Colors.white10, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'No blocked users',
                      style: TextStyle(color: AppColors.darkTextTertiary, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            // Using ListView.builder for full-screen scrollability
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              itemCount: blocked.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final contact = blocked[index];
                
                // Matching your "Container" card style from the section
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.darkBorder),
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