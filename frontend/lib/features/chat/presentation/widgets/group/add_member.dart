import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/user_avatar.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

/// Pick contacts to add to a group. Same chrome as the New Group sheet.
///
/// Tapping "Add" adds that person straight away and the sheet stays open, so
/// several people can be added in one go; a row disappears once its person has
/// joined.
class AddMembersBottomSheet extends ConsumerStatefulWidget {
  final int chatId;

  const AddMembersBottomSheet({super.key, required this.chatId});

  @override
  ConsumerState<AddMembersBottomSheet> createState() =>
      _AddMembersBottomSheetState();
}

class _AddMembersBottomSheetState extends ConsumerState<AddMembersBottomSheet> {
  final _adding = <int>{};
  String? _error;

  Future<void> _add(Contact contact) async {
    setState(() {
      _adding.add(contact.id);
      _error = null;
    });
    try {
      await ref
          .read(chatProvider.notifier)
          .addMember(widget.chatId, contact.id);
    } catch (e) {
      if (mounted) {
        setState(() => _error = ErrorHandler.getReadableErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(contact.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    // Live, so a row goes away as soon as that person is in the group
    final memberIds = ref.watch(
      chatProvider.select(
        (s) => s.chats
            .where((c) => c.id == widget.chatId)
            .expand((c) => c.participants)
            .map((u) => u.id)
            .toSet(),
      ),
    );

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: BoxDecoration(
        color: context.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Row(
                children: [
                  const SizedBox(width: 72),
                  Expanded(
                    child: Text(
                      'Add Members',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: context.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF5A52),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
            Expanded(
              child: contactsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: context.primaryColor),
                ),
                error: (e, _) =>
                    _Note(text: ErrorHandler.getReadableErrorMessage(e)),
                data: (contacts) {
                  final addable =
                      contacts.where((c) => !memberIds.contains(c.id)).toList()
                        ..sort(
                          (a, b) => a.username.toLowerCase().compareTo(
                            b.username.toLowerCase(),
                          ),
                        );

                  if (addable.isEmpty) {
                    return _Note(
                      text: contacts.isEmpty
                          ? 'You have no contacts yet. Add people from the '
                                'Contacts tab first.'
                          : 'Everyone in your contacts is already in this '
                                'group.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    itemCount: addable.length,
                    itemBuilder: (context, index) {
                      final contact = addable[index];
                      return _ContactRow(
                        contact: contact,
                        busy: _adding.contains(contact.id),
                        onAdd: () => _add(contact),
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

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final bool busy;
  final VoidCallback onAdd;

  const _ContactRow({
    required this.contact,
    required this.busy,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final bio = contact.bio?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          UserAvatar(
            name: contact.username,
            imageUrl: contact.avatar,
            isOnline: false,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (bio.isNotEmpty)
                  Text(
                    bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.textTertiary, fontSize: 13),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            height: 32,
            child: busy
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.primaryColor,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: onAdd,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: context.primaryColor.withValues(
                        alpha: 0.14,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Add',
                      style: TextStyle(
                        color: context.primaryColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
