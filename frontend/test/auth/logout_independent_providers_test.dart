import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/storage/secure_storage.dart';
import 'package:my_chat_app/core/di/global_provider.dart';
import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/send_queue.dart';

class FakeApiClient extends ApiClient {
  @override
  bool get hasToken => true;

  @override
  void setToken(String token) {}

  @override
  Future<dynamic> delete(String path) async => null;
}

class FakeSecureStorage extends SecureStorageService {
  String? _token;

  FakeSecureStorage() : super(FlutterSecureStorage());

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> deleteToken() async {
    _token = null;
  }
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<UserEntity> login({
    required String username,
    required String password,
  }) async => UserEntity(id: 1, username: username);

  @override
  Future<UserEntity> register({
    required String username,
    required String password,
  }) async => UserEntity(id: 1, username: username);

  @override
  Future<UserEntity?> getCurrentUser() async => UserEntity(id: 1, username: 'aygul');

  @override
  Future<void> logout() async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<bool> verifyPassword(String currentPassword) async => true;

  @override
  Future<List<UserSessionEntity>> getSessions() async => const [];

  @override
  Future<void> revokeSession(int sessionId) async {}

  @override
  Future<void> terminateOtherSessions() async {}
}

class FakeChatSocket implements ChatSocketDatasource {
  @override
  void connect(String token) {}

  @override
  void disconnect() {}

  @override
  void requestOnlineUsers() {}

  @override
  Future<void> joinChat(int chatId) async {}

  @override
  void setActiveChat(int? chatId) {}

  @override
  int? get activeChatId => null;

  @override
  void setAppForeground(bool foreground) {}

  @override
  bool get appInForeground => false;

  @override
  Future<void> sendMessage(dynamic message) async {}

  @override
  Future<void> sendTypingEvent(int chatId, bool isTyping, int userId) async {}

  @override
  Future<void> markChatAsRead(int chatId) async {}

  @override
  Future<void> leaveChat(int chatId) async {}

  @override
  void emitMessageReceived(int messageId) {}

  @override
  Stream<Map<String, dynamic>> onMessage() => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> onUserTyping() => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> onUserStatusChanged() => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> onMessagesRead() => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> onChatRead() => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> onMessagesDelivered() => const Stream.empty();
  @override
  Stream<List<int>> onInitialOnlineUsers() => const Stream.empty();
  @override
  Stream<int> onGroupDeleted() => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> onMessageDeleted() => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> onMessageReaction() => const Stream.empty();
  @override
  Stream<void> onSessionsUpdated() => const Stream.empty();
  @override
  Stream<void> onSessionRevoked() => const Stream.empty();
}

class FakeSendQueue extends SendQueue {
  @override
  Map<int, List<Message>> build() => const {};
}

void main() {
  test('logout resets the session without throwing', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWith((ref) => FakeApiClient()),
        secureStorageProvider.overrideWith((ref) => FakeSecureStorage()),
        authRepositoryProvider.overrideWith((ref) => FakeAuthRepository()),
        chatSocketDataSourceProvider.overrideWith((ref) => FakeChatSocket()),
        sendQueueProvider.overrideWith(() => FakeSendQueue()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(secureStorageProvider).saveToken('test-token');

    final auth = container.read(authProvider.notifier);
    await auth.login('aygul', 'password');
    expect(container.read(authProvider).isAuthenticated, isTrue);

    // Make a real auth-dependent provider part of the graph, exactly like the
    // UI does — logout must reset it through the dependency, never by
    // invalidating it from the auth notifier.
    final sub = container.listen(chatProvider, (previous, next) {});
    addTearDown(sub.close);

    await auth.logout();
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(authProvider).user, isNull);
    expect(container.read(authProvider).token, isNull);
  });
}
