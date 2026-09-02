import 'package:flutter/material.dart';

/// Single access point for theme-aware tokens.
/// Resolves colors dynamically while retaining identical variable names.
abstract final class AppColors {
  // Static Brand Colors
  static const Color primary = Color(0xFF6366F1);
  static const Color accent = Color(0xFF818CF8);
  static const Color online = Color(0xFF10B981);
  static const Color error = Colors.redAccent;

  // Static Dark-theme convenience aliases
  // (used by widgets that can't reach BuildContext, e.g. inside const/static contexts)
  static const Color darkCard = Color(0xFF171326);
  static const Color darkCardAlt = Color(0xFF1F1A33);
  static const Color darkBorder = Color(0x2B818CF8);
  static const Color darkGlassBorder = Color(0x33818CF8);
  static const Color darkInputFill = Color(0xFF19142B);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF5A585A);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Resolves theme-dependent colors based on [Brightness]
  static AppColorScheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const DarkColors()
        : const LightColors();
  }
}

/// Base contract for theme-aware tokens.
abstract interface class AppColorScheme {
  Color get bg;
  Color get authBg;
  Color get card;
  Color get cardAlt;
  Color get surface;
  Color get appBar;
  Color get inputFill;
  Color get modalBg;
  Color get modalSurface;

  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;

  Color get border;
  Color get glassBorder;

  LinearGradient get bgGradient;
  LinearGradient get authGradient;
  LinearGradient get headerGradient;
}

/// Light Theme Color Palette (Glassmorphic Sky Blue)
final class LightColors implements AppColorScheme {
  const LightColors();

  @override
  Color get bg => const Color(0xFFF0F6FF);
  @override
  Color get authBg => const Color(0xFFF0F6FF);
  @override
  Color get card => const Color(0xCCFFFFFF);
  @override
  Color get cardAlt => const Color(0xB8F0F7FF);
  @override
  Color get surface => const Color(0xE6FAFCFF);
  @override
  Color get appBar => const Color(0xD9EBF3FE);
  @override
  Color get inputFill => const Color(0x99E2EEFF);
  @override
  Color get modalBg => const Color(0xFFF4F8FE);
  @override
  Color get modalSurface => const Color(0xE6FFFFFF);

  @override
  Color get textPrimary => const Color(0xFF0F172A);
  @override
  Color get textSecondary => const Color(0xFF334155);
  @override
  Color get textTertiary => const Color(0xFF64748B);

  @override
  Color get border => const Color(0x3B3B82F6);
  @override
  Color get glassBorder => const Color(0x66FFFFFF);

  @override
  LinearGradient get bgGradient => const LinearGradient(
        colors: [Color(0xFFEBF3FE), Color(0xFFF8FAFC)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  @override
  LinearGradient get authGradient => bgGradient;

  @override
  LinearGradient get headerGradient => const LinearGradient(
        colors: [Color(0xE6E2EEFF), Color(0xCCF0F7FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

/// Dark Theme Color Palette (Deep Void Purple)
final class DarkColors implements AppColorScheme {
  const DarkColors();

  @override
  Color get bg => const Color(0xFF0B0914);
  @override
  Color get authBg => const Color(0xFF0B0B0E);
  @override
  Color get card => const Color(0xFF171326);
  @override
  Color get cardAlt => const Color(0xFF1F1A33);
  @override
  Color get surface => const Color(0xFF0B0914);
  @override
  Color get appBar => const Color(0xFF120E21);
  @override
  Color get inputFill => const Color(0xFF19142B);
  @override
  Color get modalBg => const Color(0xFF0B0914);
  @override
  Color get modalSurface => const Color(0xFF1C1733);

  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFFCBD5E1);
  @override
  Color get textTertiary => const Color.fromARGB(255, 90, 88, 90);

  @override
  Color get border => const Color(0x2B818CF8);
  @override
  Color get glassBorder => const Color(0x33818CF8);

  @override
  LinearGradient get bgGradient => const LinearGradient(
        colors: [Color(0xFF0B0914), Color(0xFF1A132C)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  @override
  LinearGradient get authGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B0B0E), Color(0xFF1A1525), Color(0xFF2D1B4E)],
        stops: [0.0, 0.5, 1.0],
      );

  @override
  LinearGradient get headerGradient => const LinearGradient(
        colors: [Color(0xFF120E21), Color(0xFF221A3B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}