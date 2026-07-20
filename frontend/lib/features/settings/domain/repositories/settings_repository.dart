import 'package:my_chat_app/features/settings/domain/entities/user_settings.dart';

abstract class SettingsRepository {
  Future<UserSettings> getSettings();
  Future<UserSettings> updateSettings(Map<String, dynamic> updates);
}