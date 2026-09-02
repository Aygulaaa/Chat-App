import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_chat_app/core/di/global_provider.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:my_chat_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:my_chat_app/features/settings/domain/entities/user_settings.dart';
import 'package:my_chat_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:my_chat_app/features/settings/domain/usecases/get_settings.dart';
import 'package:my_chat_app/features/settings/domain/usecases/update_settings.dart';

final settingsDatasourceProvider = Provider(
  (ref) => SettingsRemoteDatasource(ref.read(apiClientProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.read(settingsDatasourceProvider)),
);

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, UserSettings?>(
  SettingsNotifier.new,
);
class SettingsNotifier extends AsyncNotifier<UserSettings?> {
  @override
  Future<UserSettings?> build() async {
    final auth = ref.read(authProvider);
    if (auth.isLoading || auth.user == null) return null;

    // Load cached settings immediately from SharedPreferences
    UserSettings? cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCache = prefs.containsKey('notificationsEnabled');
      if (hasCache) {
        cached = UserSettings(
          userId: auth.user!.id,
          notificationsEnabled: prefs.getBool('notificationsEnabled') ?? true,
          hideLastSeen: prefs.getBool('hideLastSeen') ?? false,
          hideReadReceipts: prefs.getBool('hideReadReceipts') ?? false,
          theme: prefs.getString('theme') ?? 'dark',
        );
      }
    } catch (_) {}

    // Fetch fresh settings in background
    _fetchServerSettings();

    return cached;
  }

  Future<void> _fetchServerSettings() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final settings = await GetSettings(repo)();
      if (!ref.mounted) return;
      state = AsyncData(settings);

      // Persist all fields to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', settings.notificationsEnabled);
      await prefs.setBool('hideLastSeen', settings.hideLastSeen);
      await prefs.setBool('hideReadReceipts', settings.hideReadReceipts);
      await prefs.setString('theme', settings.theme);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.value == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final current = state.value;
    if (current == null) return;

    // 1. Create the optimistic updated model immediately
    final optimisticSettings = current.copyWith(
      notificationsEnabled: updates['notificationsEnabled'] ?? current.notificationsEnabled,
      hideLastSeen: updates['hideLastSeen'] ?? current.hideLastSeen,
      hideReadReceipts: updates['hideReadReceipts'] ?? current.hideReadReceipts,
      theme: updates['theme'] ?? current.theme,
    );

    // 2. Immediately set state so UI updates without waiting for network latency
    state = AsyncData(optimisticSettings);

    try {
      final repo = ref.read(settingsRepositoryProvider);
      final updated = await UpdateSettings(repo)(updates);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', updated.notificationsEnabled);
      await prefs.setBool('hideLastSeen', updated.hideLastSeen);
      await prefs.setBool('hideReadReceipts', updated.hideReadReceipts);
      await prefs.setString('theme', updated.theme);
      
      // 3. Confirm state with server response
      state = AsyncData(updated);
    } catch (e) {
      // 4. Rollback to previous state on error
      state = AsyncData(current);
      rethrow;
    }
  }
}