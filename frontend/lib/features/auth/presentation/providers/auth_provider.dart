import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/storage/secure_storage.dart';
import 'package:my_chat_app/features/auth/domain/usecases/logout_user.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/register_user.dart';
import 'package:my_chat_app/features/notification/presentation/providers/notification_provider.dart';
import 'auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref,
    LoginUser(ref.read(authRepositoryProvider)),
    RegisterUser(ref.read(authRepositoryProvider)),
    LogoutUser(ref.read(authRepositoryProvider)),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final secureStorageProvider = Provider((ref) => SecureStorage());

final authRemoteDatasourceProvider = Provider(
  (ref) => AuthRemoteDatasource(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  ),
);

final authRepositoryProvider = Provider(
  (ref) => AuthRepositoryImpl(ref.read(authRemoteDatasourceProvider)),
);

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUser loginUser;
  final RegisterUser registerUser;
  final LogoutUser logoutUser;
  final Ref ref;

  AuthNotifier(this.ref, this.loginUser, this.registerUser, this.logoutUser)
    : super(AuthState());

  Future<void> _connectSocketFromStorage() async {
    final token = await ref.read(secureStorageProvider).getToken();
    if (token != null) {
      ref.read(chatSocketDataSourceProvider).connect(token);
      print("🔌 Socket initialization triggered with stored token");
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await loginUser(username: username, password: password);
      state = state.copyWith(user: user, isLoading: false);
      await _connectSocketFromStorage();
      ref.read(syncFcmTokenProvider).call();
      ref.invalidate(userProfileProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> tryAutoLogin() async {
    final storage = ref.read(secureStorageProvider);
    final api = ref.read(apiClientProvider);
    print('Auto login started');

    final token = await storage.getToken();
    print('Token : $token');

    if (token == null) {
      state = state.copyWith(isLoading: false);
      print('No token → skip auto login');
      return;
    }

    api.setToken(token);
    print('Auto login success, token loaded');

    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      final socket = ref.read(chatSocketDataSourceProvider);
      socket.connect(token);
      ref.read(syncFcmTokenProvider).call();

      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      print('Auto login failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> register(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await registerUser(username: username, password: password);
      state = state.copyWith(user: user, isLoading: false);
      await _connectSocketFromStorage();
      ref.read(syncFcmTokenProvider).call();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> logout() async {
    try {
      await logoutUser();
    } catch (e) {
      print("Backend logout failed, but proceeding with local cleanup: $e");
    }

    ref.read(chatSocketDataSourceProvider).disconnect();
    await ref.read(secureStorageProvider).deleteToken();
    state = AuthState(isLoading: false);

    print("🔒 Logout complete: Socket closed and state reset.");
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> verifyPassword(String currentPassword) async {
    try {
      await ref.read(authRepositoryProvider).verifyPassword(currentPassword);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  void clearError() {
  if (state.error != null) {
    state = state.copyWith(error: null);
  }
}
}
