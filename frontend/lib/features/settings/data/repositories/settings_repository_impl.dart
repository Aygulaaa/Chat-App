import 'package:my_chat_app/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:my_chat_app/features/settings/domain/entities/user_settings.dart';
import 'package:my_chat_app/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsRemoteDatasource remote;
  const SettingsRepositoryImpl(this.remote);

  @override
  Future<UserSettings> getSettings() => remote.getSettings();

  @override
  Future<UserSettings> updateSettings(Map<String, dynamic> updates) =>
      remote.updateSettings(updates);
}
