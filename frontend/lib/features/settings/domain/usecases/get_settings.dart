import 'package:my_chat_app/features/settings/domain/entities/user_settings.dart';
import 'package:my_chat_app/features/settings/domain/repositories/settings_repository.dart';

 class GetSettings {
  final SettingsRepository repository;
  const GetSettings(this.repository);
  Future<UserSettings> call()=> repository.getSettings();
}