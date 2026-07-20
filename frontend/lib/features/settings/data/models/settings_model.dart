import 'package:my_chat_app/features/settings/domain/entities/user_settings.dart';

class SettingsModel extends UserSettings {
  const SettingsModel({
    required super.userId,
    super.notificationsEnabled,
    super.theme,
    super.hideLastSeen,
    super.hideReadReceipts,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      userId: json['userId'] ?? 0,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      theme: json['theme'] ?? 'dark',
      hideLastSeen: json['hideLastSeen'] ?? false,
      hideReadReceipts: json['hideReadReceipts'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'theme': theme,
    'hideLastSeen': hideLastSeen,
    'hideReadReceipts': hideReadReceipts,
  };
}