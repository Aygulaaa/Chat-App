import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

void showUserActionSheet(BuildContext context, Contact contact) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.glassBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 16),

                // User header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: contact.avatar != null
                            ? NetworkImage(contact.avatar!)
                            : null,
                        backgroundColor: AppColors.primary,
                        child: contact.avatar == null
                            ? (contact.username.isNotEmpty
                                  ? Text(
                                      contact.username[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ))
                            : null,
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.username,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (contact.bio != null)
                              Text(
                                contact.bio!,
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Divider(color: context.glassBorder),

                if (!contact.isBlocked) ...[
                  if (!contact.isContact)
                    ListTile(
                      leading: const Icon(
                        Icons.person_add_outlined,
                        color: AppColors.online,
                      ),
                      title: Text(
                        'Add to contacts',
                        style: TextStyle(color: context.textPrimary),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(contactsProvider.notifier)
                            .addContact(contact.id);
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(
                        Icons.person_remove_outlined,
                        color: Colors.orangeAccent,
                      ),
                      title: Text(
                        'Remove from contacts',
                        style: TextStyle(color: context.textPrimary),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(contactsProvider.notifier)
                            .removeContact(contact.id);
                      },
                    ),

                  ListTile(
                    leading: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Send message',
                      style: TextStyle(color: context.textPrimary),
                    ),
                    onTap: () async {
                      try {
                        final chatRepo = ref.read(chatRepositoryProvider);
                        final chatId = await chatRepo.createChat(contact.id);

                        await ref.read(chatProvider.notifier).loadChats();

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              username: contact.username,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to open chat: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],

                if (!contact.isBlocked)
                  ListTile(
                    leading: const Icon(Icons.block, color: AppColors.error),
                    title: const Text(
                      'Block user',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(contactsProvider.notifier).blockUser(contact.id);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(
                      Icons.lock_open_outlined,
                      color: AppColors.online,
                    ),
                    title: const Text(
                      'Unblock user',
                      style: TextStyle(color: AppColors.online),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ref
                          .read(blockedContactsProvider.notifier)
                          .unblock(contact.id);
                    },
                  ),

                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}