import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/group/add_member.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/group/edit_name.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/group/member_list.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/group/profile_header.dart';

class GroupProfileScreen extends ConsumerStatefulWidget {
  final int chatId;
  const GroupProfileScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends ConsumerState<GroupProfileScreen> {
  bool _isUploading = false;
  double _sheetExtent = 0.5; // Default starts at 50% of screen

  Future<void> _pickAndUploadPhoto() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      await ref.read(chatProvider.notifier).updateGroupInfo(
            widget.chatId,
            avatarBytes: bytes,
            filename: image.name,
            mimeType: 'image/jpeg',
          );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _editName(BuildContext context, Chat chat) {
    showDialog(
      context: context,
      builder: (ctx) => EditNameDialog(
        initialName: chat.name ?? '',
        onSave: (newName) async {
          await ref
              .read(chatProvider.notifier)
              .updateGroupInfo(widget.chatId, name: newName);
        },
      ),
    );
  }

  void _showAddMemberDialog(
    BuildContext context,
    List<UserEntity> currentMembers,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AddMembersBottomSheet(
        chatId: widget.chatId,
        currentMembers: currentMembers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final chats = chatState.chats.where((c) => c.id == widget.chatId).toList();

    if (chats.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final chat = chats.first;
    final myId = ref.read(authProvider).user?.id;
    final totalHeight = MediaQuery.of(context).size.height;

    // Image height dynamically squeezes as sheet moves from 50% (0.5) to 65% (0.65)
    final imageHeight = totalHeight * (1.0 - _sheetExtent);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          setState(() {
            _sheetExtent = notification.extent;
          });
          return true;
        },
        child: Stack(
          children: [
            // 1. Top Telegram-Style Image Header (occupies top ~50% and squeezes up to 35%)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageHeight,
              child: ProfileHeaderImage(
                avatarUrl: chat.avatar,
                fallbackName: chat.name,
                chatName: chat.name ?? 'Group',
                memberCount: chat.participants.length,
                isUploading: _isUploading,
                onCameraTap: _pickAndUploadPhoto,
                onAddMemberTap: () =>
                    _showAddMemberDialog(context, chat.participants),
                onEditNameTap: () => _editName(context, chat),
              ),
            ),

            // 2. Back Navigation Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8.h,
              left: 12.w,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // 3. Telegram-Style Draggable Sheet (Initial: 50%, Max: 65%)
            DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.5,
              maxChildSize: 0.65,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: context.appBg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(height: 12.h),
                      Center(
                        child: Container(
                          width: 36.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: context.textTertiary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      MemberListSection(
                        participants: chat.participants,
                        currentUserId: myId,
                        onAddPressed: () =>
                            _showAddMemberDialog(context, chat.participants),
                        onRemoveMember: (memberId) async {
                          await ref
                              .read(chatProvider.notifier)
                              .removeMember(widget.chatId, memberId);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}