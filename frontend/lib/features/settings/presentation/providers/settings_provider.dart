import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, UserSettings?>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<UserSettings?> {
  @override
  Future<UserSettings?> build() async {
    final auth = ref.watch(authProvider);
    if (auth.isLoading || auth.user == null) return null;

    final repo = ref.read(settingsRepositoryProvider);
    final settings = await GetSettings(repo)();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', settings.notificationsEnabled);
    return settings;
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final repo = ref.read(settingsRepositoryProvider);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
        notificationsEnabled: updates['notificationsEnabled'] ??
            current.notificationsEnabled,
        hideLastSeen: updates['hideLastSeen'] ?? current.hideLastSeen,
        hideReadReceipts:
            updates['hideReadReceipts'] ?? current.hideReadReceipts,
        theme: updates['theme'] ?? current.theme,
      ));
    }

    try {
      final updated = await UpdateSettings(repo)(updates);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', updated.notificationsEnabled);
      state = AsyncData(updated);
    } catch (e) {
      if (current != null) state = AsyncData(current);
      rethrow;
    }
  }
}