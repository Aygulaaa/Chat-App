
class UserStatusState {
  final Map<int, bool> onlineUsers;
  final Map<int, DateTime?> lastSeen; 

  const UserStatusState({
    this.onlineUsers = const {},
    this.lastSeen = const {},
  });

  UserStatusState copyWith({
    Map<int, bool>? onlineUsers,
    Map<int, DateTime?>? lastSeen,
  }) {
    return UserStatusState(
      onlineUsers: onlineUsers ?? this.onlineUsers,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

