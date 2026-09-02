import 'package:equatable/equatable.dart';

class UserSessionEntity extends Equatable {
  final int id;
  final String deviceName;
  final String? ipAddress;
  final DateTime lastActiveAt;
  final DateTime createdAt;
  final bool isCurrentDevice;

  const UserSessionEntity({
    required this.id,
    required this.deviceName,
    this.ipAddress,
    required this.lastActiveAt,
    required this.createdAt,
    this.isCurrentDevice = false,
  });

  UserSessionEntity copyWith({
    int? id,
    String? deviceName,
    String? ipAddress,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    bool? isCurrentDevice,
  }) {
    return UserSessionEntity(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    );
  }

  @override
  List<Object?> get props => [
        id,
        deviceName,
        ipAddress,
        lastActiveAt,
        createdAt,
        isCurrentDevice,
      ];
}