import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/dialog_utils.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/core/utils/format_last_seen.dart';
import 'package:my_chat_app/core/utils/snackbar_utils.dart';
import 'package:my_chat_app/core/widgets/glass_backdrop.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/avatar_picker_sheet.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_page_scaffold.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_photo_header.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

/// `user == null` → my own profile (a bottom-nav tab).
/// `user != null` → somebody else's profile (pushed full-screen).
class ProfileScreen extends ConsumerWidget {
  final UserEntity? user;
  const ProfileScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user != null) return _OtherProfile(user: user!);

    final me =
        ref.watch(userProfileProvider).value ?? ref.watch(authProvider).user;
    final profileState = ref.watch(userProfileProvider);

    if (me == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: GlassBackdrop(
          child: Center(
            child: profileState.hasError
                ? _LoadFailed(
                    message: ErrorHandler.getReadableErrorMessage(
                      profileState.error,
                    ),
                    onRetry: () =>
                        ref.read(userProfileProvider.notifier).fetchProfile(),
                  )
                : CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }
    return _MyProfile(user: me);
  }
}

// ── My profile ───────────────────────────────────────────────────────────────

class _MyProfile extends ConsumerStatefulWidget {
  final UserEntity user;
  const _MyProfile({required this.user});

  @override
  ConsumerState<_MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends ConsumerState<_MyProfile> {
  bool _uploadingPhoto = false;

  Future<void> _logout() async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Log Out',
      message: 'You will need your password to sign back in on this device.',
      confirmLabel: 'Log Out',
      confirmColor: Colors.redAccent,
    );
    if (confirmed) await ref.read(authProvider.notifier).logout();
  }

  Future<void> _changePhoto() async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AvatarPickerSheet(
        hasAvatar: widget.user.avatar?.isNotEmpty ?? false,
        onCamera: () async {
          ctx.pop();
          await _pickAndUpload(ImageSource.camera);
        },
        onGallery: () async {
          ctx.pop();
          await _pickAndUpload(ImageSource.gallery);
        },
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final XFile? image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await image.readAsBytes();
      await ref
          .read(userProfileProvider.notifier)
          .updateAvatarFromBytes(bytes, image.name);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return ProfilePageScaffold(
      title: user.username,
      subtitle: 'online',
      highlightSubtitle: true,
      imageUrl: user.avatar,
      trailing: PhotoGlassButton(
        icon: Icons.edit_rounded,
        tooltip: 'Edit',
        onTap: () => context.push('/edit-profile', extra: user),
      ),
      onChangePhoto: _changePhoto,
      uploadingPhoto: _uploadingPhoto,
      // My own picture — mine to save. Nobody else's is.
      allowPhotoDownload: true,
      onRefresh: () => ref.read(userProfileProvider.notifier).fetchProfile(),
      // Room for the floating nav bar
      bottomPadding: 120,
      children: [
        _InfoSection(user: user, isMe: true),
        SettingsSection(
          children: [
            SettingsTile(
              icon: Icons.person_rounded,
              iconColor: SettingsColors.blue,
              title: 'Edit Profile',
              onTap: () => context.push('/edit-profile', extra: user),
            ),
            SettingsTile(
              icon: Icons.settings_rounded,
              iconColor: SettingsColors.grey,
              title: 'Settings',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
        SettingsSection(
          children: [
            SettingsTile(
              icon: Icons.logout_rounded,
              iconColor: SettingsColors.red,
              title: 'Log Out',
              destructive: true,
              onTap: _logout,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Someone else's profile ───────────────────────────────────────────────────

class _OtherProfile extends ConsumerStatefulWidget {
  final UserEntity user;
  const _OtherProfile({required this.user});

  @override
  ConsumerState<_OtherProfile> createState() => _OtherProfileState();
}

class _OtherProfileState extends ConsumerState<_OtherProfile> {
  bool _openingChat = false;

  Future<void> _message(UserEntity user) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final chatId = await ref.read(chatRepositoryProvider).createChat(user.id);
      await ref.read(chatProvider.notifier).loadChats();
      if (!mounted) return;
      context.push('/chat/conversation/$chatId', extra: user.username);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnack(
          context,
          ErrorHandler.getReadableErrorMessage(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  /// Runs a contacts action with feedback; failures are explained, not lost.
  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) SnackBarUtils.showSnack(context, done);
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

  Future<void> _block(UserEntity user) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Block ${user.username}?',
      message:
          "They won't be able to message you, and you won't see each "
          "other's online status. You can unblock them any time.",
      confirmLabel: 'Block',
      confirmColor: Colors.redAccent,
    );
    if (!confirmed) return;
    await _run(
      () => ref.read(contactsProvider.notifier).blockUser(user.id),
      '${user.username} is blocked',
    );
  }

  Future<void> _removeContact(UserEntity user) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Remove ${user.username}?',
      message: 'They will be removed from your contacts. Your chat stays.',
      confirmLabel: 'Remove',
      confirmColor: Colors.redAccent,
    );
    if (!confirmed) return;
    await _run(
      () => ref.read(contactsProvider.notifier).removeContact(user.id),
      'Removed from contacts',
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.user;
    final user = ref.watch(userByIdProvider(base.id)).value ?? base;

    final iHideLastSeen =
        ref.watch(settingsProvider).value?.hideLastSeen ?? false;
    final presence = ref.watch(userStatusProvider);
    final isContact = ref.watch(
      contactsProvider.select(
        (v) => v.value?.any((c) => c.id == user.id) ?? false,
      ),
    );
    final isBlocked = ref.watch(
      blockedContactsProvider.select(
        (v) => v.value?.any((c) => c.id == user.id) ?? false,
      ),
    );

    final online = !isBlocked && (presence.onlineUsers[user.id] ?? false);
    final String status;
    if (isBlocked) {
      status = 'blocked';
    } else if (online) {
      status = 'online';
    } else {
      // Hiding my own last seen hides everyone else's from me (reciprocal)
      final lastSeen = iHideLastSeen
          ? null
          : (presence.lastSeen[user.id] ?? user.lastSeen);
      status = TimeUtils.formatLastSeen(
        lastSeen,
        fuzzy: iHideLastSeen
            ? null
            : (presence.lastSeenFuzzy[user.id] ?? user.lastSeenFuzzy),
      );
    }

    return ProfilePageScaffold(
      title: user.username,
      subtitle: status,
      highlightSubtitle: online,
      imageUrl: user.avatar,
      leading: PhotoGlassButton(
        icon: Icons.arrow_back_ios_new_rounded,
        tooltip: 'Back',
        onTap: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (!isBlocked) ...[
                _QuickAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  busy: _openingChat,
                  onTap: () => _message(user),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: isContact
                      ? Icons.person_remove_rounded
                      : Icons.person_add_alt_1_rounded,
                  label: isContact ? 'Remove' : 'Add',
                  onTap: () => isContact
                      ? _removeContact(user)
                      : _run(
                          () => ref
                              .read(contactsProvider.notifier)
                              .addContact(user.id),
                          'Added to contacts',
                        ),
                ),
                const SizedBox(width: 10),
              ],
              _QuickAction(
                icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                label: isBlocked ? 'Unblock' : 'Block',
                destructive: !isBlocked,
                onTap: () => isBlocked
                    ? _run(
                        () => ref
                            .read(blockedContactsProvider.notifier)
                            .unblock(user.id),
                        '${user.username} is unblocked',
                      )
                    : _block(user),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _InfoSection(user: user, isMe: false),
      ],
    );
  }
}

// ── Shared pieces ────────────────────────────────────────────────────────────

/// Username, plus bio and birthday on other people's profiles (mine only
/// shows the username). Value on top, small label beneath; long-press copies
/// the value.
class _InfoSection extends StatelessWidget {
  final UserEntity user;
  final bool isMe;
  const _InfoSection({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bio = user.bio?.trim() ?? '';
    final birthday = user.birthDate;

    return SettingsSection(
      dividerIndent: 16,
      children: [
        _InfoRow(value: '@${user.username}', label: 'Username'),
        if (!isMe && bio.isNotEmpty) _InfoRow(value: bio, label: 'Bio'),
        if (!isMe && birthday != null)
          _InfoRow(
            value: DateFormat.yMMMMd().format(birthday),
            label: 'Birthday',
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String value;
  final String label;

  const _InfoRow({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: value));
        HapticFeedback.selectionClick();
        SnackBarUtils.showSnack(context, '$label copied');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(color: context.textTertiary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool busy;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFFF5A52) : AppColors.primary;

    return Expanded(
      child: Material(
        color: context.glassCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.glassEdge, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 24,
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      : Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadFailed({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: context.textTertiary),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
