import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/palette_provider.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/settings/presentation/pages/notifications_settings_screen.dart'
    show saveSetting;
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final isLight = settings?.theme == 'light';
    final current = isLight
        ? const LightColors().id
        : ref.watch(darkPaletteProvider);

    void select(AppColorScheme palette) {
      if (settings == null || palette.id == current) return;
      HapticFeedback.selectionClick();

      final wantsLight = palette.brightness == Brightness.light;
      if (!wantsLight) {
        ref.read(darkPaletteProvider.notifier).select(palette.id);
      }
      if (wantsLight != isLight) {
        saveSetting(context, ref, {'theme': wantsLight ? 'light' : 'dark'});
      }
    }

    const palettes = AppColors.palettes;

    return SettingsScaffold(
      title: 'Appearance',
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          SettingsSection(
            title: 'Color theme',
            footer:
                'Light or dark is saved to your account and follows you to '
                'other devices. The dark palette is remembered on this device.',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                child: Column(
                  children: [
                    // Two previews per row
                    for (var i = 0; i < palettes.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 18),
                      Row(
                        children: [
                          for (var j = i; j < i + 2; j++) ...[
                            if (j > i) const SizedBox(width: 14),
                            Expanded(
                              child: j < palettes.length
                                  ? _ThemeOption(
                                      label: palettes[j].label,
                                      colors: palettes[j],
                                      selected: palettes[j].id == current,
                                      onTap: () => select(palettes[j]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A miniature chat drawn in the option's own palette, so you see what you
/// are choosing before you choose it.
class _ThemeOption extends StatelessWidget {
  final String label;
  final AppColorScheme colors;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  Widget _bubble({required bool mine, required double width}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: 18,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          gradient: mine ? colors.primaryGradient : null,
          color: mine ? null : colors.textPrimary.withValues(alpha: 0.13),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(9),
            topRight: const Radius.circular(9),
            bottomLeft: Radius.circular(mine ? 9 : 3),
            bottomRight: Radius.circular(mine ? 3 : 9),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 112,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: colors.bgGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : context.textTertiary.withValues(alpha: 0.3),
                  width: selected ? 2.2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bubble(mine: false, width: 70),
                  _bubble(mine: true, width: 84),
                  _bubble(mine: false, width: 52),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : context.textTertiary,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
