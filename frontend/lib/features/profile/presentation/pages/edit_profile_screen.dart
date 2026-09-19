import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:go_router/go_router.dart';

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
    FocusScope.of(
      context,
    ).unfocus(); // Dismiss keyboard before opening date picker
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _BirthdayPickerSheet(initialDate: _selectedDate ?? DateTime(1995)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username cannot be empty')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(userProfileProvider.notifier).updateInfo({
        'username': username,
        'bio': _bioController.text.trim(),
        if (_selectedDate != null)
          'birthDate': _selectedDate!.toIso8601String(),
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appBg,
          elevation: 0,
          scrolledUnderElevation: 0,
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isSaving
                  ? Padding(
                      key: const ValueKey('saving'),
                      padding: EdgeInsets.all(16.r),
                      child: SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : TextButton(
                      key: const ValueKey('save'),
                      onPressed: _save,
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20.r, 12.r, 20.r, 40.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with a small edit badge instead of caption text
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(
                      username: widget.user.username,
                      imageUrl: widget.user.avatar,
                      isMe: true,
                    ),
                    Positioned(
                      right: -2.r,
                      bottom: -2.r,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.appBg, width: 2.5),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 13.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 36.h),

              _SectionLabel('About you'),
              SizedBox(height: 10.h),
              _GlassGroup(
                children: [
                  _GroupField(
                    label: 'Username',
                    controller: _usernameController,
                    hint: 'Add a username',
                  ),
                  const _GroupDivider(),
                  _GroupField(
                    label: 'Bio',
                    controller: _bioController,
                    hint: 'Say something about yourself',
                    maxLines: 4,
                    maxLength: 150,
                  ),
                ],
              ),

              SizedBox(height: 24.h),
              _SectionLabel('Birthday'),
              SizedBox(height: 10.h),
              _GlassGroup(
                children: [
                  _GroupRow(
                    onTap: _pickDate,
                    leading: Icons.cake_rounded,
                    label: _selectedDate != null
                        ? '${_selectedDate!.day} / ${_selectedDate!.month} / ${_selectedDate!.year}'
                        : 'Set your birthday',
                    isPlaceholder: _selectedDate == null,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Text(
                  "Only you can see your birthday. It's never shown on your profile.",
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 12.sp,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        text,
        style: TextStyle(
          color: context.textTertiary,
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// A frosted container in the spirit of an iOS grouped list: real backdrop
/// blur, a single hairline edge, and no drop shadow — glass, not a card.
class _GlassGroup extends StatelessWidget {
  final List<Widget> children;
  const _GlassGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final radius = 18.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.glassBorder, width: 1),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.w),
      child: Divider(height: 1, thickness: 0.6, color: context.glassBorder),
    );
  }
}

class _GroupField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;

  const _GroupField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100.w,
            child: Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? 14.h : 0),
              child: Text(
                label,
                style: TextStyle(color: context.textSecondary, fontSize: 15.sp),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              maxLength: maxLength,
              style: TextStyle(color: context.textPrimary, fontSize: 15.sp),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: TextStyle(color: context.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterStyle: TextStyle(
                  color: context.textTertiary,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with a spinning wheel date picker, styled like the native
/// iOS "Date of Birth" picker: drag handle, Cancel / Done bar, frosted
/// backdrop, rounded top corners, no shadow.
class _BirthdayPickerSheet extends StatefulWidget {
  final DateTime initialDate;
  const _BirthdayPickerSheet({required this.initialDate});

  @override
  State<_BirthdayPickerSheet> createState() => _BirthdayPickerSheetState();
}

class _BirthdayPickerSheetState extends State<_BirthdayPickerSheet> {
  late DateTime _tempDate = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border(
              top: BorderSide(color: context.glassBorder, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: context.glassBorder,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    Text(
                      'Birthday',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.sp,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_tempDate),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 0.6, color: context.glassBorder),
              SizedBox(
                height: 216.h,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20.sp,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _tempDate,
                    minimumDate: DateTime(1900),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (value) =>
                        setState(() => _tempDate = value),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final VoidCallback onTap;
  final IconData leading;
  final String label;
  final bool isPlaceholder;

  const _GroupRow({
    required this.onTap,
    required this.leading,
    required this.label,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(leading, size: 18.sp, color: context.textTertiary),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isPlaceholder
                      ? context.textTertiary
                      : context.textPrimary,
                  fontSize: 15.sp,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18.sp,
              color: context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
