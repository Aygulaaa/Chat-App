import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => of(const LightColors());
  static ThemeData get dark => of(const DarkColors());

  /// Material theme for one of [AppColors.palettes].
  static ThemeData of(AppColorScheme scheme) => ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: scheme.primary,
      brightness: scheme.brightness,
    ),
    scaffoldBackgroundColor: scheme.bg,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: scheme.appBar,
      foregroundColor: scheme.textPrimary,
    ),
    extensions: [AppPalette(scheme)],
  );
}
