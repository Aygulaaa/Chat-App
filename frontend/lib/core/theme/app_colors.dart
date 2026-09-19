import 'package:flutter/material.dart';

/// Single access point for theme-aware tokens.
abstract final class AppColors {
  // Static Brand Colors (Warm, vibrant, pastel-friendly palette)
  static const Color primary = Color(0xFFFF8A80); // Soft pastel coral/pink
  static const Color accent = Color(0xFFFFD180);  // Soft pastel amber/peach
  static const Color online = Color(0xFFA7FFEB);  // Soft pastel mint green
  static const Color error = Color(0xFFFF8A80);

  // Static Dark-theme convenience aliases
  static const Color darkCard = Color(0x1FFFFFFF); // ~12% translucent white
  static const Color darkCardAlt = Color(0x0FFFFFFF); // ~6% translucent white
  static const Color darkBorder = Color(0x26FFFFFF); // 15% translucent white
  static const Color darkGlassBorder = Color(0x38FFFFFF); // ~22% translucent white
  static const Color darkInputFill = Color(0xFF24232C); // Deep rich gray with warm undertone
  static const Color darkTextPrimary = Color(0xFFFFF1F2); // Warm soft white
  static const Color darkTextSecondary = Color(0xFFD7CCC8); // Warm taupe-gray
  static const Color darkTextTertiary = Color(0xFF8D8381); // Muted warm gray

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF8A80), Color(0xFFFFD180)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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

/// Light Theme Color Palette (Cozy, Airy Pastel Peach & Lavender)
final class LightColors implements AppColorScheme {
  const LightColors();

  @override
  Color get bg => const Color(0xFFFFF8F6);
  @override
  Color get authBg => const Color(0xFFFFF8F6);
  @override
  Color get card => const Color(0xE6FFFFFF);
  @override
  Color get cardAlt => const Color(0xB8FFF0EC);
  @override
  Color get surface => const Color(0xE6FFF5F2);
  @override
  Color get appBar => const Color(0xD9FFEBE5);
  @override
  Color get inputFill => const Color(0xFFFFE0D9);
  @override
  Color get modalBg => const Color(0xFFFFF4F2);
  @override
  Color get modalSurface => const Color(0xE6FFFFFF);

  @override
  Color get textPrimary => const Color(0xFF3E2723);
  @override
  Color get textSecondary => const Color(0xFF6D4C41);
  @override
  Color get textTertiary => const Color(0xFFA1887F);

  @override
  Color get border => const Color(0x3BFF8A80);
  @override
  Color get glassBorder => const Color(0x80FFFFFF);

  @override
  LinearGradient get bgGradient => const LinearGradient(
    colors: [Color(0xFFFFEBE5), Color(0xFFFFF9F8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override
  LinearGradient get authGradient => bgGradient;
  @override
  LinearGradient get headerGradient => const LinearGradient(
    colors: [Color(0xE6FFE0D9), Color(0xCCFFF0EC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Dark Theme Color Palette (Rich Midnight Velvet & Warm Pastels)
final class DarkColors implements AppColorScheme {
  const DarkColors();

  // Cozy deep dark purple-gray instead of dead pitch-black.
  @override
  Color get bg => const Color(0xFF16141A);
  @override
  Color get authBg => const Color(0xFF16141A);

  // Soft translucent surfaces with warm undertones.
  @override
  Color get card => const Color(0x1AFFFFFF); // ~10% White
  @override
  Color get cardAlt => const Color(0x0DFFFFFF); // ~5% White
  @override
  Color get surface => const Color(0x14FFFFFF);
  @override
  Color get appBar => const Color(0x1A16141A);

  // Inputs feel comfortably layered.
  @override
  Color get inputFill => const Color(0xFF232029);

  // Elevated modal backgrounds
  @override
  Color get modalBg => const Color(0xFF1E1B24);
  @override
  Color get modalSurface => const Color(0x24FFFFFF);

  // Soft high-contrast warm text
  @override
  Color get textPrimary => const Color(0xFFFCE4EC);
  @override
  Color get textSecondary => const Color(0xFFD7CCC8);
  @override
  Color get textTertiary => const Color(0xFF9E9290);

  // Subtle warm glowing borders
  @override
  Color get border => const Color(0x26FF8A80);
  @override
  Color get glassBorder => const Color(0x38FFFFFF);

  @override
  LinearGradient get bgGradient => const LinearGradient(
    colors: [
      Color(0xFF231F2E), 
      Color(0xFF1A1721), 
      Color(0xFF16141A), 
    ],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0.0, 0.5, 1.0],
  );
  @override
  LinearGradient get authGradient => bgGradient;

  @override
  LinearGradient get headerGradient => const LinearGradient(
    colors: [
      Color(0x662B2533),
      Color(0x0016141A),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}