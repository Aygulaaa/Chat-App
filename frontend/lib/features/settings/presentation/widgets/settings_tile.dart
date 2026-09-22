import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

/// One row inside a [SettingsSection].
///
///  [■ icon]  Title                      value  ›
///            optional subtitle
class SettingsTile extends StatelessWidget {
  final IconData? icon;

  /// Fill of the rounded icon square (the glyph itself is always white).
  final Color? iconColor;
  final String title;
  final String? subtitle;

  /// Short current value shown on the right, before the chevron ("On", "3"…).
  final String? value;

  /// Replaces value + chevron entirely (e.g. a checkmark).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Red title, no chevron — for "Log Out", "Turn Off…".
  final bool destructive;

  /// Centered accent-colored title with no icon — for action rows.
  final bool centered;

  const SettingsTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive
        ? const Color(0xFFFF5A52)
        : centered
        ? AppColors.primary
        : context.textPrimary;

    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: titleColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      ),
    );

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                SettingsIcon(
                  icon: icon!,
                  color: iconColor ?? AppColors.primary,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: subtitle == null
                    ? titleText
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleText,
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
              ),
              if (trailing != null)
                trailing!
              else if (!centered) ...[
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 15.5,
                    ),
                  ),
                ],
                if (onTap != null && !destructive) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: context.textTertiary.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row whose trailing control is a switch; tapping anywhere toggles it.
class SettingsSwitchTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// The small filled rounded square with a white glyph.
class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const SettingsIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    );
  }
}

/// Icon-square colors shared across the settings pages so the same concept
/// always has the same color.
abstract final class SettingsColors {
  static const red = Color(0xFFF2554D);
  static const orange = Color(0xFFF59331);
  static const green = Color(0xFF3DBD63);
  static const blue = Color(0xFF3D8EF0);
  static const cyan = Color(0xFF35AEDC);
  static const purple = Color(0xFF8B6CF0);
  static const grey = Color(0xFF8C8C96);
}
