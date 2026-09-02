import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/info_card.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/my_profile.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_delegate.dart';

class ProfileScreen extends ConsumerWidget {
  final UserEntity? user;
  const ProfileScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user != null) return _OtherProfile(user: user!);

    final profileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (authState.user == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: Center(
          child: Text(
            'Please log in',
            style: TextStyle(color: context.textSecondary),
          ),
        ),
      );
    }
    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.appBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.appBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48.sp),
              SizedBox(height: 16.h),
              Text(
                '$e',
                style: TextStyle(color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () =>
                    ref.read(userProfileProvider.notifier).fetchProfile(),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (me) {
        if (me == null) {
          return Scaffold(
            backgroundColor: context.appBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return MyProfile(user: me);
      },
    );
  }
}

class _OtherProfile extends ConsumerWidget {
  final UserEntity user;
  const _OtherProfile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullUserAsync = ref.watch(userByIdProvider(user.id));
    final effectiveUser = fullUserAsync.maybeWhen(
      data: (fetchedUser) => fetchedUser ?? user,
      orElse: () => user,
    );

    // Watch contacts list to know state (isContact, isBlocked)
    final contactsAsync = ref.watch(contactsProvider);
    final blockedContactsAsync = ref.watch(blockedContactsProvider);

    final isContact = contactsAsync.maybeWhen(
      data: (contacts) => contacts.any((c) => c.id == effectiveUser.id),
      orElse: () => false,
    );

    final isBlocked = blockedContactsAsync.maybeWhen(
      data: (blocked) => blocked.any((c) => c.id == effectiveUser.id),
      orElse: () => false,
    );

    final topPadding = MediaQuery.of(context).padding.top;
    final maxHeaderHeight = 320.h;
    final minHeaderHeight = kToolbarHeight + topPadding;

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileHeaderDelegate(
              user: effectiveUser,
              isMe: false,
              maxExtentHeight: maxHeaderHeight,
              minExtentHeight: minHeaderHeight,
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 20.h),
                InfoCard(user: effectiveUser),
                SizedBox(height: 16.h),

                // Action Card matching InfoCard style
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: context.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Send Message Row
                      if (!isBlocked) ...[
                        _ActionCardRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: AppColors.accent,
                          iconBgColor: AppColors.primary.withValues(alpha: 0.12),
                          title: 'Send message',
                          onTap: () async {
                            try {
                              final chatRepo = ref.read(chatRepositoryProvider);
                              final chatId = await chatRepo.createChat(effectiveUser.id);

                              await ref.read(chatProvider.notifier).loadChats();

                              if (!context.mounted) return;

                              context.push(
                                '/chat/conversation/$chatId',
                                extra: effectiveUser.username,
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
                        Divider(color: context.glassBorder, height: 1, indent: 52.w),
                      ],

                      // Add / Remove from Contacts Row
                      if (!isBlocked) ...[
                        if (!isContact)
                          _ActionCardRow(
                            icon: Icons.person_add_outlined,
                            iconColor: AppColors.online,
                            iconBgColor: AppColors.online.withValues(alpha: 0.12),
                            title: 'Add to contacts',
                            onTap: () {
                              ref
                                  .read(contactsProvider.notifier)
                                  .addContact(effectiveUser.id);
                            },
                          )
                        else
                          _ActionCardRow(
                            icon: Icons.person_remove_outlined,
                            iconColor: Colors.orangeAccent,
                            iconBgColor: Colors.orangeAccent.withValues(alpha: 0.12),
                            title: 'Remove from contacts',
                            onTap: () {
                              ref
                                  .read(contactsProvider.notifier)
                                  .removeContact(effectiveUser.id);
                            },
                          ),
                        Divider(color: context.glassBorder, height: 1, indent: 52.w),
                      ],

                      // Block / Unblock User Row
                      if (!isBlocked)
                        _ActionCardRow(
                          icon: Icons.block_rounded,
                          iconColor: AppColors.error,
                          iconBgColor: AppColors.error.withValues(alpha: 0.12),
                          title: 'Block user',
                          titleColor: AppColors.error,
                          onTap: () {
                            ref.read(contactsProvider.notifier).blockUser(effectiveUser.id);
                          },
                        )
                      else
                        _ActionCardRow(
                          icon: Icons.lock_open_rounded,
                          iconColor: AppColors.online,
                          iconBgColor: AppColors.online.withValues(alpha: 0.12),
                          title: 'Unblock user',
                          titleColor: AppColors.online,
                          onTap: () {
                            ref
                                .read(blockedContactsProvider.notifier)
                                .unblock(effectiveUser.id);
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCardRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionCardRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? context.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}