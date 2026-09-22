import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/widgets/glass_backdrop.dart';
import 'package:my_chat_app/core/utils/dialog_utils.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserEntity user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _maxBio = 150;

  late final TextEditingController _username;
  late final TextEditingController _bio;
  DateTime? _birthday;
  bool _saving = false;
  String? _usernameError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.user.username)
      ..addListener(_onEdited);
    _bio = TextEditingController(text: widget.user.bio ?? '')
      ..addListener(_onEdited);
    _birthday = widget.user.birthDate;
  }

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _onEdited() => setState(() {
    _usernameError = null;
    _saveError = null;
  });

  bool get _dirty =>
      _username.text.trim() != widget.user.username ||
      _bio.text.trim() != (widget.user.bio ?? '').trim() ||
      _birthday != widget.user.birthDate;

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _BirthdayPickerSheet(initialDate: _birthday ?? DateTime(2000)),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    FocusScope.of(context).unfocus();

    // Same rules the server enforces → instant feedback, no round trip
    final username = _username.text.trim();
    if (username.length < 3 || username.length > 30) {
      HapticFeedback.heavyImpact();
      setState(() => _usernameError = 'Use between 3 and 30 characters');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref.read(userProfileProvider.notifier).updateInfo({
        'username': username,
        'bio': _bio.text.trim(),
        'birthDate': _birthday?.toIso8601String(),
      });
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final message = ErrorHandler.getReadableErrorMessage(e);
      setState(() {
        _saving = false;
        // A username problem belongs under the username field
        if (message.toLowerCase().contains('username')) {
          _usernameError = message;
        } else {
          _saveError = message;
        }
      });
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Discard changes?',
      message: "Your edits haven't been saved.",
      confirmLabel: 'Discard',
      confirmColor: Colors.redAccent,
    );
    if (discard && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _dirty && !_saving;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: context.appBg,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: context.glassBar,
            shape: context.glassBarShape,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leadingWidth: 84,
            leading: TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textSecondary, fontSize: 15.5),
              ),
            ),
            title: Text(
              'Edit Profile',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              SizedBox(
                width: 72,
                child: _saving
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: canSave ? _save : null,
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: canSave
                                ? AppColors.primary
                                : context.textTertiary.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: GlassBackdrop(
            child: SafeArea(
              bottom: false,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(top: 20, bottom: 40),
                children: [
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
                          right: -2,
                          bottom: -2,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.appBg,
                                  width: 2.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Tap the photo to change it',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),

                  SettingsSection(
                    dividerIndent: 16,
                    footer:
                        _usernameError ??
                        'People find you by your username. 3–30 characters, '
                            'saved in lowercase.',
                    footerIsError: _usernameError != null,
                    children: [
                      _Field(
                        controller: _username,
                        hint: 'Username',
                        prefix: '@',
                        enabled: !_saving,
                        maxLength: 30,
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                  ),

                  SettingsSection(
                    dividerIndent: 16,
                    footer:
                        'A few words about you. '
                        '${_bio.text.characters.length}/$_maxBio',
                    children: [
                      _Field(
                        controller: _bio,
                        hint: 'Bio',
                        enabled: !_saving,
                        maxLength: _maxBio,
                        maxLines: 4,
                        capitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),

                  SettingsSection(
                    dividerIndent: 16,
                    footer: 'Only shown on your profile.',
                    children: [
                      SettingsTile(
                        title: 'Birthday',
                        value: _birthday == null
                            ? 'Add'
                            : DateFormat.yMMMMd().format(_birthday!),
                        onTap: _saving ? null : _pickDate,
                      ),
                      if (_birthday != null)
                        SettingsTile(
                          title: 'Remove Birthday',
                          destructive: true,
                          onTap: _saving
                              ? null
                              : () => setState(() => _birthday = null),
                        ),
                    ],
                  ),

                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                      child: Text(
                        _saveError!,
                        style: const TextStyle(
                          color: Color(0xFFFF5A52),
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A borderless text field that sits inside a [SettingsSection] card.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final bool enabled;
  final int maxLength;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextCapitalization capitalization;

  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.prefix,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: 1,
        maxLines: maxLines,
        maxLength: maxLength,
        autocorrect: maxLines > 1,
        textCapitalization: capitalization,
        textInputAction: textInputAction,
        cursorColor: AppColors.primary,
        style: TextStyle(color: context.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textTertiary, fontSize: 16),
          prefixText: prefix,
          prefixStyle: TextStyle(color: context.textTertiary, fontSize: 16),
          counterText: '',
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

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
