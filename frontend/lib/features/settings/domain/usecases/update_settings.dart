import '../entities/user_settings.dart';
import '../repositories/settings_repository.dart';

class UpdateSettings {
  final SettingsRepository repository;
  const UpdateSettings(this.repository);
  Future<UserSettings> call(Map<String, dynamic> updates) =>
      repository.updateSettings(updates);
}