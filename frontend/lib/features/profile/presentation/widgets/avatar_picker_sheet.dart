import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

/// Action sheet for changing the profile photo.
///
/// iOS grouping: one frosted card holding the actions, Cancel on its own card
/// below it. Deliberately flat — the rows *are* the interface, so there are no
/// gradient tiles, no coloured glows and no chevrons competing with them.
/// Every colour comes from the theme, so it follows the chosen palette instead
/// of being hardcoded to the dark one.
class AvatarPickerSheet extends StatelessWidget {
  /// Reserved for a future "Remove Photo" row; nothing reads it yet.
  final bool hasAvatar;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const AvatarPickerSheet({
    super.key,
    required this.hasAvatar,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      'Profile Photo',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 13,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const _Hairline(),
                  _SheetAction(
                    icon: Icons.photo_camera_outlined,
                    label: 'Take Photo',
                    onTap: onCamera,
                  ),
                  const _Hairline(),
                  _SheetAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Choose from Gallery',
                    onTap: onGallery,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _GlassCard(
              child: _SheetAction(
                label: 'Cancel',
                centered: true,
                weight: FontWeight.w600,
                onTap: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted rounded group. One blur per card, not per row.
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.modalSurface,
            borderRadius: radius,
            border: Border.all(color: context.glassEdge, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Hairline between rows, inset the way a grouped iOS list insets its
/// separators.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 16,
      color: context.glassEdge,
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool centered;
  final FontWeight weight;

  const _SheetAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.centered = false,
    this.weight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 16,
        fontWeight: weight,
        letterSpacing: -0.2,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: centered
              ? Center(child: text)
              : Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(icon, size: 21, color: context.textSecondary),
                    const SizedBox(width: 14),
                    Expanded(child: text),
                    const SizedBox(width: 16),
                  ],
                ),
        ),
      ),
    );
  }
}
