import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contacts_search_bar.dart';

class CreateGroupModal extends ConsumerStatefulWidget {
  const CreateGroupModal({super.key});

  @override
  ConsumerState<CreateGroupModal> createState() => _CreateGroupModalState();
}

class _CreateGroupModalState extends ConsumerState<CreateGroupModal> {
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _groupNameController = TextEditingController();

  final Set<int> _selectedIds = {};

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter group name')));
      return;
    }

    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 members')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final datasource = ref.read(chatRemoteDataSourceProvider);

      final result = await datasource.createGroupChat(
        name: groupName,
        memberIds: _selectedIds.toList(),
      );

      final chatId = result['id'] as int;

      await ref.read(chatProvider.notifier).loadChats();

      if (!mounted) return;

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, username: groupName),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.darkModalBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(100),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New Group',
                      style: TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  _isCreating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : TextButton(
                          onPressed: _createGroup,
                          child: const Text(
                            'Create',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _groupNameController,
                style: const TextStyle(color: AppColors.darkTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
                  prefixIcon: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.darkTextTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.darkModalSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            ContactsSearchBar(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() {}), 
              onClear: () {
                _searchController.clear();
                setState(() {});
              },
            ),

            if (_selectedIds.isNotEmpty) ...[
              const SizedBox(height: 18),

              SizedBox(
                height: 90,
                child: contactsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (contacts) {
                    final selectedContacts = contacts
                        .where((c) => _selectedIds.contains(c.id))
                        .toList();

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, index) {
                        final contact = selectedContacts[index];

                        return Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage: contact.avatar != null
                                      ? NetworkImage(contact.avatar!)
                                      : null,
                                  child: contact.avatar == null
                                      ? Text(
                                          contact.username[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.darkTextPrimary,
                                          ),
                                        )
                                      : null,
                                ),

                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedIds.remove(contact.id);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.error,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AppColors.darkTextPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            SizedBox(
                              width: 64,
                              child: Text(
                                contact.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.darkTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: selectedContacts.length,
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 10),

            Expanded(
              child: contactsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '$e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                data: (contacts) {
                  final query = _searchController.text.trim().toLowerCase();

                  final filtered = contacts.where((c) {
                    final username = c.username.toLowerCase();
                    final bio = (c.bio ?? '').toLowerCase();

                    return username.contains(query) || bio.contains(query);
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(color: AppColors.darkTextTertiary),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final contact = filtered[index];

                      final selected = _selectedIds.contains(contact.id);

                      return _ContactTile(
                        contact: contact,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(contact.id);
                            } else {
                              _selectedIds.add(contact.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final bool selected;
  final VoidCallback onTap;

  const _ContactTile({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withOpacity(0.12)
            : AppColors.darkCardAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.darkBorder,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          backgroundImage: contact.avatar != null
              ? NetworkImage(contact.avatar!)
              : null,
          child: contact.avatar == null
              ? Text(
                  contact.username[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.darkTextPrimary),
                )
              : null,
        ),
        title: Text(
          contact.username,
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          contact.bio ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 12),
        ),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: AppColors.darkTextPrimary, size: 14)
              : null,
        ),
      ),
    );
  }
}