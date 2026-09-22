import 'dart:async';
import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:my_chat_app/features/auth/data/models/user_session_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';

part 'sessions_provider.g.dart';

@riverpod
class SessionsNotifier extends _$SessionsNotifier {
  StreamSubscription<void>? _subscription;

  static const _box = 'user_profile_cache'; // cleared on logout
  static const _key = 'sessions';

  /// Cache-first: the list appears instantly from the last known state and is
  /// refreshed from the server in the background. A spinner is only ever shown
  /// the very first time (nothing cached yet).
  @override
  FutureOr<List<UserSessionEntity>> build() async {
    final socket = ref.watch(chatSocketDataSourceProvider);

    _subscription = socket.onSessionsUpdated().listen((_) {
      refresh();
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    final cached = _readCache();
    if (cached != null) {
      unawaited(refresh());
      return cached;
    }
    final fresh = await _fetchSessions();
    _writeCache(fresh);
    return fresh;
  }

  List<UserSessionEntity>? _readCache() {
    try {
      final raw = Hive.box<String>(_box).get(_key);
      if (raw == null) return null;
      return (jsonDecode(raw) as List)
          .map((e) => UserSessionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  void _writeCache(List<UserSessionEntity> sessions) {
    try {
      final json = sessions
          .map(
            (s) => UserSessionModel(
              id: s.id,
              deviceName: s.deviceName,
              ipAddress: s.ipAddress,
              lastActiveAt: s.lastActiveAt,
              createdAt: s.createdAt,
              isCurrentDevice: s.isCurrentDevice,
            ).toJson(),
          )
          .toList();
      Hive.box<String>(_box).put(_key, jsonEncode(json));
    } catch (_) {}
  }

  Future<List<UserSessionEntity>> _fetchSessions() async {
    return await ref.read(authProvider.notifier).getSessions();
  }

  /// Silent refresh: keeps showing the current list while it loads, and keeps
  /// it if the request fails (an error replaces the list only when there is
  /// nothing to show).
  Future<void> refresh() async {
    try {
      final sessions = await _fetchSessions();
      if (!ref.mounted) return;
      state = AsyncValue.data(sessions);
      _writeCache(sessions);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.value == null) state = AsyncValue.error(e, st);
    }
  }

  /// The row disappears immediately; the server confirms in the background
  /// and the list is restored if it refuses.
  Future<void> revokeSession(int sessionId) async {
    final before = state.value;
    if (before != null) {
      state = AsyncValue.data(before.where((s) => s.id != sessionId).toList());
    }
    try {
      await ref.read(authProvider.notifier).revokeSession(sessionId);
    } catch (_) {
      if (ref.mounted && before != null) state = AsyncValue.data(before);
      rethrow;
    }
    await refresh();
  }

  Future<void> terminateOtherSessions() async {
    final before = state.value;
    if (before != null) {
      state = AsyncValue.data(before.where((s) => s.isCurrentDevice).toList());
    }
    try {
      await ref.read(authProvider.notifier).terminateOtherSessions();
    } catch (_) {
      if (ref.mounted && before != null) state = AsyncValue.data(before);
      rethrow;
    }
    await refresh();
  }
}
