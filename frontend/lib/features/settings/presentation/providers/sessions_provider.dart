import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';

part 'sessions_provider.g.dart';

@riverpod
class SessionsNotifier extends _$SessionsNotifier {
  StreamSubscription<void>? _subscription;

  @override
  FutureOr<List<UserSessionEntity>> build() async {
    final socket = ref.watch(chatSocketDataSourceProvider);

    _subscription = socket.onSessionsUpdated().listen((_) {
      refresh();
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return _fetchSessions();
  }

  Future<List<UserSessionEntity>> _fetchSessions() async {
    return await ref.read(authProvider.notifier).getSessions();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final sessions = await _fetchSessions();
      if (!ref.mounted) return;
      state = AsyncValue.data(sessions);
    } catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> revokeSession(int sessionId) async {
    await ref.read(authProvider.notifier).revokeSession(sessionId);
    await refresh();
  }

  Future<void> terminateOtherSessions() async {
    await ref.read(authProvider.notifier).terminateOtherSessions();
    await refresh();
  }
}