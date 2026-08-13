import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

/// Add Members Modal Sheet
class AddMembersBottomSheet extends ConsumerWidget {
  final int chatId;
  final List<UserEntity> currentMembers;

  const AddMembersBottomSheet({
    super.key,
    required this.chatId,
    required this.currentMembers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.88,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: context.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Add Members',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final contactsAsync = ref.watch(contactsProvider);
                      return contactsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            'Error loading contacts: $e',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                        data: (contacts) {
                          final currentMemberIds =
                              currentMembers.map((m) => m.id).toSet();
                          final addableContacts = contacts
                              .where((c) => !currentMemberIds.contains(c.id))
                              .toList();

                          if (addableContacts.isEmpty) {
                            return Center(
                              child: Text(
                                'No contacts available to add.',
                                style: TextStyle(
                                  color: context.textTertiary,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            itemCount: addableContacts.length,
                            itemBuilder: (context, index) {
                              final contact = addableContacts[index];
                              return Container(
                                margin: EdgeInsets.only(bottom: 8.h),
                                decoration: BoxDecoration(
                                  color: context.textPrimary.withValues(
                                    alpha: 0.03,
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: context.glassBorder.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 4.h,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 22.r,
                                    backgroundImage: contact.avatar != null
                                        ? NetworkImage(contact.avatar!)
                                        : null,
                                    backgroundColor: AppColors.primary,
                                    child: contact.avatar == null
                                        ? Text(
                                            contact.username[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    contact.username,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_rounded,
                                      color: AppColors.primary,
                                      size: 26,
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await ref
                                          .read(chatProvider.notifier)
                                          .addMember(chatId, contact.id);
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
