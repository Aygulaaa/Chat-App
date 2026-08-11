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
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/profile/presentation/pages/profile_screen.dart';

class GroupProfileScreen extends ConsumerStatefulWidget {
  final int chatId;
  const GroupProfileScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends ConsumerState<GroupProfileScreen> {
  bool _isUploading = false;

  void _editName(BuildContext context, Chat chat) {
    final controller = TextEditingController(text: chat.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Edit Group Name', style: TextStyle(color: context.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter group name',
            hintStyle: TextStyle(color: context.textTertiary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.glassBorder)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != chat.name) {
                Navigator.pop(ctx);
                await ref.read(chatProvider.notifier).updateGroupInfo(widget.chatId, name: newName);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
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

  void _showAddMemberDialog(BuildContext context, List<UserEntity> currentMembers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final contactsAsync = ref.watch(contactsProvider);
                return contactsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => Center(child: Text('Error loading contacts: $e', style: const TextStyle(color: AppColors.error))),
                  data: (contacts) {
                    final currentMemberIds = currentMembers.map((m) => m.id).toSet();
                    final addableContacts = contacts.where((c) => !currentMemberIds.contains(c.id)).toList();
                    if (addableContacts.isEmpty) {
                      return const Center(child: Text('No contacts available to add.', style: TextStyle(color: AppColors.darkTextTertiary)));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: addableContacts.length,
                      itemBuilder: (context, index) {
                        final contact = addableContacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: contact.avatar != null ? NetworkImage(contact.avatar!) : null,
                            backgroundColor: AppColors.primary,
                            child: contact.avatar == null ? Text(contact.username[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                          ),
                          title: Text(contact.username, style: TextStyle(color: context.textPrimary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await ref.read(chatProvider.notifier).addMember(widget.chatId, contact.id);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final chats = chatState.chats.where((c) => c.id == widget.chatId).toList();
    
    if (chats.isEmpty) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    
    final chat = chats.first;
    final isDark = !context.isLight;
    final myId = ref.read(authProvider).user?.id;

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.h,
            pinned: true,
            backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
            iconTheme: IconThemeData(color: context.textPrimary),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: context.textPrimary),
                onPressed: () => _editName(context, chat),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(colors: [AppColors.darkCard, AppColors.darkInputFill], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                          : const LinearGradient(colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 80.h,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, context.appBg.withOpacity(0.6)],
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 60.h),
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadPhoto,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100.r, height: 100.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: chat.avatar != null ? DecorationImage(image: NetworkImage(chat.avatar!), fit: BoxFit.cover) : null,
                                gradient: chat.avatar == null ? const LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
                              ),
                              child: chat.avatar == null
                                  ? Center(child: Text(chat.name != null && chat.name!.isNotEmpty ? chat.name![0].toUpperCase() : 'G', style: TextStyle(color: Colors.white, fontSize: 34.sp, fontWeight: FontWeight.bold)))
                                  : null,
                            ),
                            if (_isUploading)
                              const CircularProgressIndicator(color: Colors.white),
                            if (!_isUploading)
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: Icon(Icons.camera_alt, color: Colors.white, size: 16.sp),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        chat.name ?? 'Group',
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 22.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4.h),
                      Text('${chat.participants.length} members', style: TextStyle(color: context.textTertiary, fontSize: 13.sp)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Members', style: TextStyle(color: context.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => _showAddMemberDialog(context, chat.participants),
                        icon: const Icon(Icons.person_add, color: AppColors.primary),
                        label: const Text('Add', style: TextStyle(color: AppColors.primary)),
                      )
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: context.glassBorder),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: chat.participants.length,
                    separatorBuilder: (context, index) => Divider(color: context.glassBorder, height: 1, indent: 52.w),
                    itemBuilder: (context, index) {
                      final member = chat.participants[index];
                      final isCurrentUser = member.id == myId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: member.avatar != null ? NetworkImage(member.avatar!) : null,
                          backgroundColor: AppColors.primary.withOpacity(0.8),
                          child: member.avatar == null ? Text(member.username[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                        ),
                        title: Text(isCurrentUser ? 'You' : member.username, style: TextStyle(color: context.textPrimary)),
                        onTap: () {
                          if (!isCurrentUser) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: member)));
                          }
                        },
                        trailing: isCurrentUser ? null : IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                          onPressed: () async {
                            await ref.read(chatProvider.notifier).removeMember(widget.chatId, member.id);
                          },
                        ),
                      );
                    },
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