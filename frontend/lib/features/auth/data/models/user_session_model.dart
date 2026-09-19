import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';

class UserSessionModel extends UserSessionEntity {
  const UserSessionModel({
    required super.id,
    required super.deviceName,
    super.ipAddress,
    required super.lastActiveAt,
    required super.createdAt,
    super.isCurrentDevice,
  });

  factory UserSessionModel.fromJson(Map<String, dynamic> json) {
    return UserSessionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceName: (json['deviceName'] ?? json['device_name'] ?? 'Unknown Device') as String,
      ipAddress: (json['ipAddress'] ?? json['ip_address']) as String?,
      lastActiveAt: DateTime.parse(
        (json['lastActiveAt'] ?? json['last_active_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      isCurrentDevice: (json['isCurrentDevice'] ?? json['is_current_device']) as bool? ?? false,
      createdAt: DateTime.parse(
        (json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'ipAddress': ipAddress,
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isCurrentDevice': isCurrentDevice,
    };
  }
}
