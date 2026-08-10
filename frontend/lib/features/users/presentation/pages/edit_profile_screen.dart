import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/users/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/users/presentation/widgets/profile_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserEntity user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _selectedDate = widget.user.birthDate;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1995),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (_, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(userProfileProvider.notifier).updateInfo({
        'username': username,
        'bio': _bioController.text.trim(),
        if (_selectedDate != null) 'birthDate': _selectedDate!.toIso8601String(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17.sp,
          ),
        ),
        actions: [
          _isSaving
              ? Padding(
                  padding: EdgeInsets.all(16.r),
                  child: SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: const CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: const Color(0xFF6366F1),
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: ProfileAvatar(
                username: widget.user.username,
                imageUrl: widget.user.avatar,
                isMe: true,
              ),
            ),
            SizedBox(height: 8.h),
            Center(
              child: Text(
                'Tap avatar to change photo',
                style: TextStyle(color: context.textTertiary, fontSize: 12.sp),
              ),
            ),
            SizedBox(height: 32.h),

            _Field(
              label: 'Username',
              controller: _usernameController,
              hint: 'Enter your username',
            ),
            SizedBox(height: 16.h),

            _Field(
              label: 'Bio',
              controller: _bioController,
              hint: 'Tell something about yourself',
              maxLines: 4,
              maxLength: 150,
            ),
            SizedBox(height: 16.h),

            // Birthday picker
            Text(
              'Birthday',
              style: TextStyle(color: context.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
                decoration: BoxDecoration(
                  color: context.glassBg,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: context.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: context.textTertiary, size: 18.sp),
                    SizedBox(width: 12.w),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Set birthday',
                      style: TextStyle(
                        color: _selectedDate != null ? context.textPrimary : context.textTertiary,
                        fontSize: 15.sp,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_outlined, color: context.textTertiary, size: 15.sp),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 13.sp),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: TextStyle(color: context.textPrimary, fontSize: 15.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.textTertiary),
            filled: true,
            fillColor: context.glassBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: context.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: context.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            contentPadding: EdgeInsets.all(16.r),
            counterStyle: TextStyle(color: context.textTertiary),
          ),
        ),
      ],
    );
  }
}