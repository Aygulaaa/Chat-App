
class UserStatusState {
  final Map<int, bool> onlineUsers;
  final Map<int, DateTime?> lastSeen; 
  final Map<int, String?> lastSeenFuzzy;

  const UserStatusState({
    this.onlineUsers = const {},
    this.lastSeen = const {},
    this.lastSeenFuzzy = const {},
  });

  UserStatusState copyWith({
    Map<int, bool>? onlineUsers,
    Map<int, DateTime?>? lastSeen,
    Map<int, String?>? lastSeenFuzzy,
  }) {
    return UserStatusState(
      onlineUsers: onlineUsers ?? this.onlineUsers,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSeenFuzzy: lastSeenFuzzy ?? this.lastSeenFuzzy,
    );
  }
}

