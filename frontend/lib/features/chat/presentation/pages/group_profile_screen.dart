import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/dialog_utils.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/core/utils/snackbar_utils.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/group/add_member.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/group/edit_name.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/user_avatar.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_page_scaffold.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_photo_header.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

/// A group's page. Same layout as a person's profile: the photo on top,
/// then plain scrolling sections — actions, members, and (for the creator)
/// deleting the group.
class GroupProfileScreen extends ConsumerStatefulWidget {
  final int chatId;
  const GroupProfileScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends ConsumerState<GroupProfileScreen> {
  bool _isUploading = false;

  /// Runs a group action; failures are explained, not lost.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnack(
          context,
          ErrorHandler.getReadableErrorMessage(e),
          isError: true,
        );
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    await _run(() async {
      final bytes = await image.readAsBytes();
      await ref
          .read(chatProvider.notifier)
          .updateGroupInfo(
            widget.chatId,
            avatarBytes: bytes,
            filename: image.name,
            mimeType: 'image/jpeg',
          );
    });
    if (mounted) setState(() => _isUploading = false);
  }

  void _editName(Chat chat) {
    showDialog(
      context: context,
      builder: (ctx) => EditNameDialog(
        initialName: chat.name ?? '',
        onSave: (newName) => _run(
          () => ref
              .read(chatProvider.notifier)
              .updateGroupInfo(widget.chatId, name: newName),
        ),
      ),
    );
  }

  void _addMembers() {
    showModalBottomSheet(
      context: context,
      // Above the app shell, so the bottom nav bar can't sit on top of it
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AddMembersBottomSheet(chatId: widget.chatId),
    );
  }

  Future<void> _removeMember(UserEntity member) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Remove ${member.username}?',
      message: 'They will stop receiving messages from this group.',
      confirmLabel: 'Remove',
      confirmColor: Colors.redAccent,
    );
    if (!confirmed) return;
    await _run(
      () => ref
          .read(chatProvider.notifier)
          .removeMember(widget.chatId, member.id),
    );
  }

  Future<void> _deleteGroup() async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Delete Group?',
      message:
          'This permanently deletes the group and all its messages for '
          "everyone. This can't be undone.",
      confirmLabel: 'Delete',
      confirmColor: Colors.redAccent,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(chatProvider.notifier).deleteGroup(widget.chatId);
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(
      chatProvider.select(
        (s) => s.chats.where((c) => c.id == widget.chatId).firstOrNull,
      ),
    );

    if (chat == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: Center(
          child: CircularProgressIndicator(color: context.primaryColor),
        ),
      );
    }

    final myId = ref.watch(authProvider.select((s) => s.user?.id));
    final isCreator = myId != null && chat.createdBy == myId;

    // Me first, then everyone else by name
    final members = [...chat.participants]
      ..sort((a, b) {
        if (a.id == myId) return -1;
        if (b.id == myId) return 1;
        return a.username.toLowerCase().compareTo(b.username.toLowerCase());
      });
    final count = members.length;

    return ProfilePageScaffold(
      title: chat.name ?? 'Group',
      subtitle: count == 1 ? '1 member' : '$count members',
      imageUrl: chat.avatar,
      leading: PhotoGlassButton(
        icon: Icons.arrow_back_ios_new_rounded,
        tooltip: 'Back',
        onTap: () => Navigator.of(context).maybePop(),
      ),
      trailing: PhotoGlassButton(
        icon: Icons.edit_rounded,
        tooltip: 'Edit name',
        onTap: () => _editName(chat),
      ),
      onChangePhoto: _pickAndUploadPhoto,
      uploadingPhoto: _isUploading,
      children: [
        SettingsSection(
          children: [
            SettingsTile(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: SettingsColors.blue,
              title: 'Add Members',
              onTap: _addMembers,
            ),
          ],
        ),
        SettingsSection(
          title: 'Members',
          dividerIndent: 70,
          footer: isCreator
              ? null
              : 'Only the person who created the group can remove members.',
          children: [
            for (final member in members)
              _MemberRow(
                member: member,
                isMe: member.id == myId,
                isCreator: member.id == chat.createdBy,
                onRemove: isCreator && member.id != myId
                    ? () => _removeMember(member)
                    : null,
              ),
          ],
        ),
        if (isCreator)
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.delete_rounded,
                iconColor: SettingsColors.red,
                title: 'Delete Group',
                destructive: true,
                onTap: _deleteGroup,
              ),
            ],
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final UserEntity member;
  final bool isMe;
  final bool isCreator;
  final VoidCallback? onRemove;

  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.isCreator,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isMe ? null : () => context.push('/user-profile', extra: member),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          children: [
            UserAvatar(
              name: member.username,
              imageUrl: member.avatar,
              isOnline: false,
              size: 42,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isMe ? 'You' : member.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (isCreator)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  'owner',
                  style: TextStyle(color: context.textTertiary, fontSize: 13.5),
                ),
              ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove from group',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Color(0xFFFF5A52),
                  size: 22,
                ),
                onPressed: onRemove,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
