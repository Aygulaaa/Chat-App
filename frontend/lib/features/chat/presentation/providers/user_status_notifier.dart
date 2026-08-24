import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_state.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';


final userStatusProvider =
    StateNotifierProvider<UserStatusNotifier, UserStatusState>((ref) {
  final datasource = ref.read(chatSocketDataSourceProvider);
  return UserStatusNotifier(datasource, ref);
});




class UserStatusNotifier extends StateNotifier<UserStatusState> {
  final ChatSocketDatasource _datasource;
  final Ref ref;
  final Set<int> _blockedUserIds = {};

  UserStatusNotifier(this._datasource, this.ref) : super(UserStatusState()) {
    _initBlocked();
  }

  Future<void> _initBlocked() async {
    try {
      final blocked = await ref.read(blockedContactsProvider.future);
      _blockedUserIds.addAll(blocked.map((c) => c.id));
    } catch (_) {}

    ref.listen<AsyncValue<List<dynamic>>>(blockedContactsProvider, (_, next) {
      next.whenData((blocked) {
        _blockedUserIds
          ..clear()
          ..addAll(blocked.map((c) => c.id));
          
        final updatedOnline = Map<int, bool>.from(state.onlineUsers);
        bool hasChanges = false;
        
        for (final id in _blockedUserIds) {
          if (updatedOnline[id] == true) {
            updatedOnline[id] = false;
            hasChanges = true;
          }
        }
        
        if (hasChanges) {
          state = state.copyWith(onlineUsers: updatedOnline);
        }
      });
    });

    _init();
    _datasource.requestOnlineUsers();
  }

  void _init() {
    _datasource.onUserStatusChanged().listen((data) {
      print("📡 Status Change Received: $data");
      try {
        final int userId = int.tryParse(data['userId'].toString()) ?? 0;
        if (userId == 0) return;

        // ── Block filter ──────────────────────────────────────────
        if (_blockedUserIds.contains(userId)) return;
        // ──────────────────────────────────────────────────────────

        final bool isOnline = data['status'] == 'online';

        final updatedOnline = Map<int, bool>.from(state.onlineUsers);
        updatedOnline[userId] = isOnline;

        final updatedLastSeen = Map<int, DateTime?>.from(state.lastSeen);
        final updatedLastSeenFuzzy = Map<int, String?>.from(state.lastSeenFuzzy);

        if (!isOnline) {
          updatedLastSeen[userId] = data['lastSeen'] != null
              ? DateTime.tryParse(data['lastSeen'].toString())
              : null;
          updatedLastSeenFuzzy[userId] = data['lastSeenFuzzy']?.toString();
        }

        state = state.copyWith(
          onlineUsers: updatedOnline,
          lastSeen: updatedLastSeen,
          lastSeenFuzzy: updatedLastSeenFuzzy,
        );
      } catch (e) {
        print("❌ Error parsing status change: $e");
      }
    });

    _datasource.onInitialOnlineUsers().listen((userIds) {
      print("📊 Initial List Received: $userIds");
      final updated = Map<int, bool>.from(state.onlineUsers);
      for (final id in userIds) {
        if (!_blockedUserIds.contains(id)) {
          updated[id] = true;
        }
      }
      state = state.copyWith(onlineUsers: updated);
    });
  }

  
  void setLastSeen(int userId, DateTime? lastSeen, {String? lastSeenFuzzy}) {
    final updatedLastSeen = Map<int, DateTime?>.from(state.lastSeen);
    final updatedLastSeenFuzzy = Map<int, String?>.from(state.lastSeenFuzzy);

    updatedLastSeen[userId] = lastSeen;
    updatedLastSeenFuzzy[userId] = lastSeenFuzzy;

    state = state.copyWith(lastSeen: updatedLastSeen, lastSeenFuzzy: updatedLastSeenFuzzy);
  }
}