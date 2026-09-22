import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which dark palette this device uses (Midnight, Violet, Burgundy…).
///
/// Light vs dark is an account setting and syncs through the server, which
/// only knows those two values. The palette is a purely visual, per-device
/// choice, so it lives in local preferences.
final darkPaletteProvider = NotifierProvider<DarkPaletteNotifier, String>(
  DarkPaletteNotifier.new,
);

class DarkPaletteNotifier extends Notifier<String> {
  static const _key = 'darkPalette';

  @override
  String build() => const DarkColors().id;

  /// Reads the saved choice. Awaited before the first frame so the app never
  /// flashes the default palette.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppColors.byId(prefs.getString(_key)).id;
    } catch (_) {}
  }

  Future<void> select(String id) async {
    state = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, id);
    } catch (_) {}
  }
}
