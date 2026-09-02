import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_state.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

part 'user_status_notifier.g.dart';

// -----------------------------------------------------------------------------
// Presentation Layer — User Online Status Notifier
// -----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class UserStatusNotifier extends _$UserStatusNotifier {
  final Set<int> _blockedUserIds = {};
  StreamSubscription? _statusSub;
  StreamSubscription? _initialOnlineSub;

  @override
  UserStatusState build() {
    ref.onDispose(() {
      _statusSub?.cancel();
      _initialOnlineSub?.cancel();
    });

    Future.microtask(() => _initBlocked());
    return const UserStatusState();
  }

  Future<void> _initBlocked() async {
    try {
      final blocked = await ref.read(blockedContactsProvider.future);
      if (!ref.mounted) return;
      _blockedUserIds.addAll(blocked.map((c) => c.id));
    } catch (_) {}

    if (!ref.mounted) return;

    ref.listen<AsyncValue<List<dynamic>>>(blockedContactsProvider, (_, next) {
      if (!ref.mounted) return;
      next.whenData((blocked) {
        _blockedUserIds
          ..clear()
          ..addAll(blocked.map((c) => c.id));

        // Suppress online status for any newly blocked users.
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
    ref.read(chatSocketDataSourceProvider).requestOnlineUsers();
  }

  void _init() {
    final datasource = ref.read(chatSocketDataSourceProvider);

    _statusSub?.cancel();
    _statusSub = datasource.onUserStatusChanged().listen((data) {
      if (!ref.mounted) return;
      try {
        final int userId = int.tryParse(data['userId']?.toString() ?? '') ?? 0;
        if (userId == 0) return;

        // Ignore blocked users
        if (_blockedUserIds.contains(userId)) return;

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
      } catch (_) {}
    });

    _initialOnlineSub?.cancel();
    _initialOnlineSub = datasource.onInitialOnlineUsers().listen((userIds) {
      if (!ref.mounted) return;
      try {
        final updated = Map<int, bool>.from(state.onlineUsers);

        // Reset state against incoming batch
        final Set<int> activeIds = userIds.map((e) => int.tryParse(e.toString())).whereType<int>().toSet();

        for (final id in activeIds) {
          if (!_blockedUserIds.contains(id)) {
            updated[id] = true;
          }
        }

        state = state.copyWith(onlineUsers: updated);
      } catch (_) {}
    });
  }

  void setLastSeen(int userId, DateTime? lastSeen, {String? lastSeenFuzzy}) {
    final updatedLastSeen = Map<int, DateTime?>.from(state.lastSeen);
    final updatedLastSeenFuzzy = Map<int, String?>.from(state.lastSeenFuzzy);

    updatedLastSeen[userId] = lastSeen;
    updatedLastSeenFuzzy[userId] = lastSeenFuzzy;

    state = state.copyWith(
      lastSeen: updatedLastSeen,
      lastSeenFuzzy: updatedLastSeenFuzzy,
    );
  }
}