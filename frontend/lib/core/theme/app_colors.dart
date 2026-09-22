import 'package:flutter/material.dart';

/// Single access point for theme-aware tokens.
abstract final class AppColors {
  /// Every palette the user can pick, in the order Appearance shows them.
  static const List<AppColorScheme> palettes = [
    LightColors(),
    DarkColors(),
    VioletColors(),
    BurgundyColors(),
  ];

  static AppColorScheme _active = const DarkColors();

  /// The palette the app is currently drawn in. The root widget sets it
  /// together with the [ThemeData], so code without a [BuildContext] (and the
  /// many `AppColors.primary` call sites) follows the chosen palette.
  static AppColorScheme get active => _active;
  static set active(AppColorScheme scheme) => _active = scheme;

  static AppColorScheme byId(String? id) =>
      palettes.firstWhere((p) => p.id == id, orElse: () => const DarkColors());

  // Brand colors of the active palette
  static Color get primary => _active.primary;
  static Color get accent => _active.accent;

  // Muted green, not a neon mint: it has to sit as a small dot on a photo and
  // as small text on a dark surface without glowing at either size.
  static const Color online = Color(0xFF4CC38A);
  static const Color error = Color(0xFFFF8A80);

  // Static Dark-theme convenience aliases
  static const Color darkCard = Color(0x1FFFFFFF); // ~12% translucent white
  static const Color darkCardAlt = Color(0x0FFFFFFF); // ~6% translucent white
  static const Color darkBorder = Color(0x26FFFFFF); // 15% translucent white
  static const Color darkGlassBorder = Color(
    0x38FFFFFF,
  ); // ~22% translucent white
  static const Color darkInputFill = Color(
    0xFF24232C,
  ); // Deep rich gray with warm undertone
  static const Color darkTextPrimary = Color(0xFFFFF1F2); // Warm soft white
  static const Color darkTextSecondary = Color(0xFFD7CCC8); // Warm taupe-gray
  static const Color darkTextTertiary = Color(0xFF8D8381); // Muted warm gray

  static LinearGradient get primaryGradient => _active.primaryGradient;

  static AppColorScheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>()?.scheme ??
        (theme.brightness == Brightness.dark
            ? const DarkColors()
            : const LightColors());
  }
}

/// Carries the chosen [AppColorScheme] on the [ThemeData], so a palette change
/// rebuilds everything that reads its tokens through [AppColors.of].
class AppPalette extends ThemeExtension<AppPalette> {
  final AppColorScheme scheme;
  const AppPalette(this.scheme);

  @override
  AppPalette copyWith({AppColorScheme? scheme}) =>
      AppPalette(scheme ?? this.scheme);

  // Palettes switch, they don't blend
  @override
  AppPalette lerp(AppPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Base contract for theme-aware tokens.
abstract interface class AppColorScheme {
  /// Stable key the choice is saved under.
  String get id;
  String get label;
  Brightness get brightness;

  Color get primary;
  Color get accent;
  LinearGradient get primaryGradient;

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
  Color get glass;
  Color get glassBorder;

  LinearGradient get bgGradient;
  LinearGradient get authGradient;
  LinearGradient get headerGradient;
}

/// Light Theme Color Palette (Cozy, Airy Pastel Peach & Lavender)
final class LightColors implements AppColorScheme {
  const LightColors();

  @override
  String get id => 'light';
  @override
  String get label => 'Light';
  @override
  Brightness get brightness => Brightness.light;

  @override
  Color get primary => const Color(0xFFFF8A80); // Soft pastel coral
  @override
  Color get accent => const Color(0xFFFFD180); // Soft pastel peach
  @override
  LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
  Color get glass => const Color(0xA6FFFFFF); // ~65% white
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

  @override
  String get id => 'midnight';
  @override
  String get label => 'Midnight';
  @override
  Brightness get brightness => Brightness.dark;

  @override
  Color get primary => const Color(0xFFFF8A80); // Soft pastel coral
  @override
  Color get accent => const Color(0xFFFFD180); // Soft pastel peach
  @override
  LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
  Color get glass => const Color(0x17FFFFFF); // ~9% white
  @override
  Color get glassBorder => const Color(0x38FFFFFF);

  @override
  LinearGradient get bgGradient => const LinearGradient(
    colors: [Color(0xFF231F2E), Color(0xFF1A1721), Color(0xFF16141A)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0.0, 0.5, 1.0],
  );
  @override
  LinearGradient get authGradient => bgGradient;

  @override
  LinearGradient get headerGradient => const LinearGradient(
    colors: [Color(0x662B2533), Color(0x0016141A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Purple on near-black. Shares Midnight's translucent surfaces; only the
/// tinted tokens change.
final class VioletColors extends DarkColors {
  const VioletColors();

  @override
  String get id => 'violet';
  @override
  String get label => 'Violet';

  @override
  Color get primary => const Color(0xFF9F7AEA);
  @override
  Color get accent => const Color(0xFFC9B2FF);

  // Deeper than primary → accent, so white text and icons stay readable on it
  @override
  LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF6B4BC8), Color(0xFFA688F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Color get bg => const Color(0xFF0D0A13);
  @override
  Color get authBg => bg;
  @override
  Color get appBar => const Color(0x1A0D0A13);
  @override
  Color get inputFill => const Color(0xFF1C1628);
  @override
  Color get modalBg => const Color(0xFF171121);

  @override
  Color get textPrimary => const Color(0xFFF1ECFA);
  @override
  Color get textSecondary => const Color(0xFFC9C0DA);
  @override
  Color get textTertiary => const Color(0xFF8E859E);

  @override
  Color get border => const Color(0x269F7AEA);

  @override
  LinearGradient get bgGradient => const LinearGradient(
    colors: [Color(0xFF1B1329), Color(0xFF120D1B), Color(0xFF0B0810)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0.0, 0.5, 1.0],
  );

  @override
  LinearGradient get headerGradient => const LinearGradient(
    colors: [Color(0x66221833), Color(0x000D0A13)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Burgundy on near-black.
final class BurgundyColors extends DarkColors {
  const BurgundyColors();

  @override
  String get id => 'burgundy';
  @override
  String get label => 'Burgundy';

  @override
  Color get primary => const Color(0xFFC0415F);
  @override
  Color get accent => const Color(0xFFE58FA3);

  // Deeper than primary → accent, so white text and icons stay readable on it
  @override
  LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF7A1D36), Color(0xFFC24C69)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Color get bg => const Color(0xFF110A0C);
  @override
  Color get authBg => bg;
  @override
  Color get appBar => const Color(0x1A110A0C);
  @override
  Color get inputFill => const Color(0xFF23151A);
  @override
  Color get modalBg => const Color(0xFF1B1014);

  @override
  Color get textPrimary => const Color(0xFFF8ECEE);
  @override
  Color get textSecondary => const Color(0xFFD6C3C7);
  @override
  Color get textTertiary => const Color(0xFF9A878B);

  @override
  Color get border => const Color(0x26C0415F);

  @override
  LinearGradient get bgGradient => const LinearGradient(
    colors: [Color(0xFF26111A), Color(0xFF170B10), Color(0xFF0E0709)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0.0, 0.5, 1.0],
  );

  @override
  LinearGradient get headerGradient => const LinearGradient(
    colors: [Color(0x66301520), Color(0x00110A0C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
