import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_state.dart';

final userStatusProvider =
    StateNotifierProvider<UserStatusNotifier, UserStatusState>((ref) {
  final datasource = ref.read(chatSocketDataSourceProvider);
  return UserStatusNotifier(datasource);
});



class UserStatusNotifier extends StateNotifier<UserStatusState> {
  final ChatSocketDatasource _datasource;

  UserStatusNotifier(this._datasource) : super(UserStatusState()) {
    _init();
    _datasource.requestOnlineUsers();
  }

  void _init() {
    _datasource.onUserStatusChanged().listen((data) {
      print("📡 Status Change Received: $data");
      try {
        final int userId = int.tryParse(data['userId'].toString()) ?? 0;
        if (userId == 0) return;

        final bool isOnline = data['status'] == 'online';

        final updatedOnline = Map<int, bool>.from(state.onlineUsers);
        updatedOnline[userId] = isOnline;

        final updatedLastSeen = Map<int, DateTime?>.from(state.lastSeen);

        if (!isOnline) {
          updatedLastSeen[userId] = data['lastSeen'] != null
              ? DateTime.tryParse(data['lastSeen'].toString())
              : null;
        }

        state = state.copyWith(
          onlineUsers: updatedOnline,
          lastSeen: updatedLastSeen,
        );
      } catch (e) {
        print("❌ Error parsing status change: $e");
      }
    });

    _datasource.onInitialOnlineUsers().listen((userIds) {
      print("📊 Initial List Received: $userIds");
      final updated = Map<int, bool>.from(state.onlineUsers);
      for (final id in userIds) {
        updated[id] = true;
      }
      state = state.copyWith(onlineUsers: updated);
    });
  }

  

  void setLastSeen(int userId, DateTime? lastSeen) {
    if (state.lastSeen.containsKey(userId)) return;
    final updated = Map<int, DateTime?>.from(state.lastSeen);
    updated[userId] = lastSeen;
    state = state.copyWith(lastSeen: updated);
  }
}