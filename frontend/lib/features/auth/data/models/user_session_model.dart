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
      id: json['id'] as int,
      deviceName: (json['deviceName'] ?? json['device_name']) as String? ?? 'Unknown Device',
      ipAddress: (json['ipAddress'] ?? json['ip_address']) as String?,
      lastActiveAt: DateTime.parse(
        (json['lastActiveAt'] ?? json['last_active_at']) as String,
      ),
      createdAt: DateTime.parse(
        (json['createdAt'] ?? json['created_at']) as String,
      ),
      isCurrentDevice: (json['isCurrentDevice'] ?? json['is_current_device']) as bool? ?? false,
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