import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

/// An inset, rounded group of rows — the basic building block of every
/// settings page. Optional small-caps [title] above and explanatory [footer]
/// below, like the grouped lists in Telegram / iOS Settings.
class SettingsSection extends StatelessWidget {
  final String? title;
  final String? footer;

  /// Renders the footer in red — for a validation message about this group.
  final bool footerIsError;
  final List<Widget> children;

  /// Where the hairline between rows starts. 58 lines it up with the row
  /// titles when rows have a leading icon; use 16 for icon-less rows.
  final double dividerIndent;

  const SettingsSection({
    super.key,
    this.title,
    this.footer,
    this.footerIsError = false,
    required this.children,
    this.dividerIndent = 58,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(
                title!.toUpperCase(),
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          // Material + clip so each row's ink ripple is cut to the rounded card.
          // Translucent fill + light edge: frosted glass over a GlassBackdrop.
          Material(
            color: context.glassCard,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.glassEdge, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.6,
                      thickness: 0.6,
                      indent: dividerIndent,
                      color: context.textTertiary.withValues(alpha: 0.22),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  color: footerIsError
                      ? const Color(0xFFFF5A52)
                      : context.textTertiary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
