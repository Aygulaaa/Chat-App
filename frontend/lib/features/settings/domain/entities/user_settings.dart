import 'package:equatable/equatable.dart';

class UserSettings extends Equatable{
  final int userId;
  final bool hideLastSeen;
  final bool hideReadReceipts;
  final bool notificationsEnabled;
  final String theme;

  const UserSettings({
    required this.userId,
    this.hideLastSeen=false,
    this.hideReadReceipts=false,
    this.notificationsEnabled=true,
    this.theme='dark',
  });

  UserSettings copyWith({
    bool? notificationsEnabled,
    String? theme,
    bool? hideLastSeen,
    bool? hideReadReceipts,
  }) {
    return UserSettings(
      userId: userId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      theme: theme ?? this.theme,
      hideLastSeen: hideLastSeen ?? this.hideLastSeen,
      hideReadReceipts: hideReadReceipts ?? this.hideReadReceipts,
    );
  }

  @override
  List<Object?> get props =>
      [userId, notificationsEnabled, theme, hideLastSeen, hideReadReceipts];
}