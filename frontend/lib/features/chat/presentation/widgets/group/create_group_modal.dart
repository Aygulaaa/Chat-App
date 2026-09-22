import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

/// Opens the "New Group" sheet above the whole app shell (nav bar included).
Future<void> showCreateGroupModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CreateGroupModal(),
  );
}

class CreateGroupModal extends ConsumerStatefulWidget {
  const CreateGroupModal({super.key});

  @override
  ConsumerState<CreateGroupModal> createState() => _CreateGroupModalState();
}

class _CreateGroupModalState extends ConsumerState<CreateGroupModal> {
  static const _maxNameLength = 100;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  /// Insertion-ordered, so chips appear in the order people were picked.
  final _selected = <int, Contact>{};

  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _name.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_creating && _name.text.trim().isNotEmpty && _selected.isNotEmpty;

  /// Tells the user what is still missing instead of a dead button.
  String get _hint {
    if (_selected.isEmpty) return 'Choose at least one person';
    if (_name.text.trim().isEmpty) return 'Give your group a name';
    final n = _selected.length;
    return '$n ${n == 1 ? 'person' : 'people'} selected';
  }

  void _toggle(Contact contact) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (_selected.remove(contact.id) == null) {
        _selected[contact.id] = contact;
      }
    });
  }

  Future<void> _create() async {
    if (!_canCreate) {
      // Point at what's missing
      if (_name.text.trim().isEmpty) _nameFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final name = _name.text.trim();
      final result = await ref
          .read(chatRemoteDataSourceProvider)
          .createGroupChat(name: name, memberIds: _selected.keys.toList());
      final chatId = int.parse(result['id'].toString());

      await ref.read(chatProvider.notifier).loadChats();
      if (!mounted) return;

      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/chat/conversation/$chatId', extra: name);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // Shown INSIDE the sheet — a SnackBar would appear on the page hidden
      // behind it.
      setState(() {
        _creating = false;
        _error = ErrorHandler.getReadableErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.92,
        padding: EdgeInsets.only(bottom: keyboard),
        decoration: BoxDecoration(
          color: context.modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            _buildHeader(context),
            _buildNameField(context),
            _buildSelectedChips(context),
            _buildSearchField(context),
            if (_error != null) _buildError(context, _error!),
            const SizedBox(height: 4),
            Expanded(
              child: contactsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => _Placeholder(
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load your contacts",
                  message: ErrorHandler.getReadableErrorMessage(e),
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(contactsProvider),
                ),
                data: (contacts) => _buildContacts(context, contacts),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          TextButton(
            onPressed: _creating ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary, fontSize: 15.5),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'New Group',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _hint,
                    key: ValueKey(_hint),
                    style: TextStyle(color: context.textTertiary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: _creating
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _create,
                    child: Text(
                      'Create',
                      style: TextStyle(
                        color: _canCreate
                            ? AppColors.primary
                            : context.textTertiary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    final name = _name.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          // Live preview of the group's default avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            alignment: Alignment.center,
            child: name.isEmpty
                ? const Icon(Icons.groups_rounded, color: Colors.white, size: 26)
                : Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _name,
              focusNode: _nameFocus,
              enabled: !_creating,
              maxLength: _maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              cursorColor: AppColors.primary,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: TextStyle(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: context.textTertiary.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 1.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChips(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _selected.isEmpty
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                itemCount: _selected.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final contact = _selected.values.elementAt(index);
                  return _SelectedChip(
                    key: ValueKey(contact.id),
                    contact: contact,
                    onRemove: _creating ? null : () => _toggle(contact),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: TextField(
        controller: _search,
        enabled: !_creating,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.primary,
        style: TextStyle(color: context.textPrimary, fontSize: 15.5),
        decoration: InputDecoration(
          hintText: 'Search contacts',
          hintStyle: TextStyle(color: context.textTertiary, fontSize: 15.5),
          isDense: true,
          filled: true,
          fillColor: context.inputFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: context.textTertiary,
          ),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: context.textTertiary,
                  ),
                  onPressed: _search.clear,
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    const color = Color(0xFFFF5A52);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContacts(BuildContext context, List<Contact> contacts) {
    if (contacts.isEmpty) {
      return const _Placeholder(
        icon: Icons.person_add_alt_1_rounded,
        title: 'No contacts yet',
        message:
            'Add people from the Contacts tab first — then you can put them '
            'in a group.',
      );
    }

    final query = _search.text.trim().toLowerCase();
    final visible =
        contacts
            .where((c) => c.username.toLowerCase().contains(query))
            .toList()
          ..sort(
            (a, b) =>
                a.username.toLowerCase().compareTo(b.username.toLowerCase()),
          );

    if (visible.isEmpty) {
      return _Placeholder(
        icon: Icons.search_off_rounded,
        title: 'No one named "${_search.text.trim()}"',
        message: 'Check the spelling, or clear the search to see everyone.',
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final contact = visible[index];
        return _ContactRow(
          contact: contact,
          selected: _selected.containsKey(contact.id),
          onTap: _creating ? null : () => _toggle(contact),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final Contact contact;
  final double size;

  const _Avatar({required this.contact, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        contact.username.isEmpty ? '?' : contact.username[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final url = contact.avatar;
    return SizedBox(
      width: size,
      height: size,
      child: url == null || url.isEmpty
          ? placeholder
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final bool selected;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bio = contact.bio?.trim() ?? '';
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _Avatar(contact: contact, size: 44),
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
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : context.textTertiary.withValues(alpha: 0.6),
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onRemove;

  const _SelectedChip({super.key, required this.contact, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove ${contact.username}',
      child: GestureDetector(
        onTap: onRemove,
        child: SizedBox(
          width: 58,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Avatar(contact: contact, size: 50),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.textTertiary,
                        border: Border.all(color: context.modalBg, width: 2),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                contact.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Placeholder({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: context.textTertiary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
