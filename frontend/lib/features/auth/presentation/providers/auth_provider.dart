import 'dart:async';
import 'dart:convert';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Core imports
import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/di/global_provider.dart';
import 'package:my_chat_app/core/network/api_client.dart';

// Data & Domain imports
import 'package:my_chat_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';
import 'package:my_chat_app/features/auth/domain/usecases/login_user.dart';
import 'package:my_chat_app/features/auth/domain/usecases/logout_user.dart';
import 'package:my_chat_app/features/auth/domain/usecases/register_user.dart';
import 'package:my_chat_app/features/auth/domain/usecases/get_currect_user.dart';

// Cross-feature providers
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/send_queue.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/notification/presentation/providers/notification_provider.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';

import 'auth_state.dart';

part 'auth_provider.g.dart';

// -----------------------------------------------------------------------------
// Data Layer
// -----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
AuthRemoteDatasource authRemoteDatasource(Ref ref) {
  return AuthRemoteDatasourceImpl(ref.watch(apiClientProvider));
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    remoteDatasource: ref.watch(authRemoteDatasourceProvider),
    storage: ref.watch(secureStorageProvider),
    api: ref.watch(apiClientProvider),
  );
}

// -----------------------------------------------------------------------------
// Domain Layer Use Cases
// -----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
LoginUser loginUser(Ref ref) => LoginUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
RegisterUser registerUser(Ref ref) =>
    RegisterUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
LogoutUser logoutUser(Ref ref) => LogoutUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
GetCurrentUser getCurrentUser(Ref ref) =>
    GetCurrentUser(ref.watch(authRepositoryProvider));

// -----------------------------------------------------------------------------
// Presentation Notifier
// -----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  bool _isLoggingOut = false;

  @override
  AuthState build() {
    // Any authenticated request that comes back 401 means this session was
    // revoked or expired — sign out instead of leaving the user in a broken,
    // half-logged-in app where every screen shows an error.
    final api = ref.watch(apiClientProvider);
    api.onUnauthorized = () {
      if (state.token != null) logout();
    };
    ref.onDispose(() => api.onUnauthorized = null);

    // Initialized directly via main.dart before UI mount
    return const AuthState(isLoading: true);
  }

  Future<void> _initializePostAuthSession(String token) async {
    try {
      ref.read(chatSocketDataSourceProvider).connect(token);

      // Sync actual device FCM token to server
      try {
        final notificationRepo = ref.read(notificationRepositoryProvider);
        final fcmToken = await notificationRepo.getFcmToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await notificationRepo.syncFcmToken(fcmToken: fcmToken);
        }
      } catch (_) {}

      ref.invalidate(userProfileProvider);
    } catch (_) {}
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await ref
          .read(loginUserProvider)
          .call(username: username, password: password);
      final token = await ref.read(secureStorageProvider).getToken();

      state = state.copyWith(user: user, token: token, isLoading: false);

      if (token != null && token.isNotEmpty) {
        await _initializePostAuthSession(token);
      }
    } catch (e) {
      state = state.copyWith(error: _formatErrorMessage(e), isLoading: false);
    }
  }

  Future<void> register(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await ref
          .read(registerUserProvider)
          .call(username: username, password: password);
      final token = await ref.read(secureStorageProvider).getToken();

      state = state.copyWith(user: user, token: token, isLoading: false);

      if (token != null && token.isNotEmpty) {
        await _initializePostAuthSession(token);
      }
    } catch (e) {
      state = state.copyWith(error: _formatErrorMessage(e), isLoading: false);
    }
  }

  Future<void> tryAutoLogin() async {
    final storage = ref.read(secureStorageProvider);

    try {
      final token = await storage.getToken();

      if (token == null || token.isEmpty) {
        state = state.copyWith(isLoading: false, user: null, token: null);
        return;
      }

      // 1. Immediately read cached user profile if available
      UserEntity? cachedUser;
      try {
        final cachedStr = Hive.box<String>('user_profile_cache').get('my_profile');
        if (cachedStr != null) {
          cachedUser = UserModel.fromJson(jsonDecode(cachedStr));
        }
      } catch (_) {}

      // 2. Set token and cached user, set isLoading to false
      ref.read(apiClientProvider).setToken(token);
      state = state.copyWith(token: token, user: cachedUser, isLoading: false);

      // 3. Silently fetch full profile & connect sockets in background
      _verifySessionWithServer(token);
    } catch (_) {
      state = state.copyWith(isLoading: false, user: null, token: null);
    }
  }

  Future<void> _verifySessionWithServer(String token) async {
    try {
      final user = await ref.read(getCurrentUserProvider).call();

      if (!ref.mounted) return;

      if (user == null) {
        await logout();
        return;
      }

      try {
        final userModel = UserModel(
          id: user.id,
          username: user.username,
          avatar: user.avatar,
          bio: user.bio,
          birthDate: user.birthDate,
          status: user.status,
          lastSeen: user.lastSeen,
          lastSeenFuzzy: user.lastSeenFuzzy,
        );
        await Hive.box<String>('user_profile_cache').put('my_profile', jsonEncode(userModel.toJson()));
      } catch (_) {}

      ref.read(chatSocketDataSourceProvider).connect(token);

      // Sync actual device FCM token to server
      try {
        final notificationRepo = ref.read(notificationRepositoryProvider);
        final fcmToken = await notificationRepo.getFcmToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await notificationRepo.syncFcmToken(fcmToken: fcmToken);
        }
      } catch (_) {}

      state = state.copyWith(user: user);
    } catch (e) {
      if (!ref.mounted) return;

      // Only an explicit 401 means the session is dead. A 5xx, a timeout or
      // the host's "waking up" HTML page must NOT sign the user out — stay on
      // the cached session and let normal retries recover.
      if (e is ApiException && e.isUnauthorized) {
        await logout();
      }
    }
  }

  Future<void> logout() async {
    // A revoked session makes the logout request itself return 401, which
    // would call logout() again through onUnauthorized.
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      // Detach this device's push token first (needs the session, so it must
      // happen before the server-side logout). Otherwise the phone keeps
      // receiving this account's messages after signing out.
      final api = ref.read(apiClientProvider);
      if (api.hasToken) {
        try {
          await api.delete(ApiEndpoints.sendFcmToken());
        } catch (_) {}
      }

      await ref.read(logoutUserProvider).call();
    } catch (_) {
    } finally {
      try {
        ref.read(chatSocketDataSourceProvider).disconnect();
      } catch (_) {}

      try {
        await Hive.box<String>('chats_cache').clear();
        await Hive.box<String>('messages_cache').clear();
        await Hive.box<String>('user_profile_cache').clear();
        await Hive.box<String>('contacts_cache').clear();
      } catch (_) {}

      await ref.read(secureStorageProvider).deleteToken();
      ref.read(apiClientProvider).setToken('');

      state = const AuthState(isLoading: false);

      // These providers are keepAlive: without a reset the NEXT account to log
      // in on this device would see the previous user's chats, contacts and
      // profile straight from memory.
      ref.read(sendQueueProvider.notifier).clear();
      ref.invalidate(chatProvider);
      ref.invalidate(contactsProvider);
      ref.invalidate(blockedContactsProvider);
      ref.invalidate(userStatusProvider);
      ref.invalidate(userProfileProvider);

      _isLoggingOut = false;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
    } catch (e) {
      throw Exception(_formatErrorMessage(e));
    }
  }

  Future<bool> verifyPassword(String currentPassword) async {
    try {
      return await ref
          .read(authRepositoryProvider)
          .verifyPassword(currentPassword);
    } catch (e) {
      throw Exception(_formatErrorMessage(e));
    }
  }

  Future<List<UserSessionEntity>> getSessions() async {
    try {
      return await ref.read(authRepositoryProvider).getSessions();
    } catch (e) {
      throw Exception(_formatErrorMessage(e));
    }
  }

  Future<void> revokeSession(int sessionId) async {
    try {
      await ref.read(authRepositoryProvider).revokeSession(sessionId);
    } catch (e) {
      throw Exception(_formatErrorMessage(e));
    }
  }

  Future<void> terminateOtherSessions() async {
    try {
      await ref.read(authRepositoryProvider).terminateOtherSessions();
    } catch (e) {
      throw Exception(_formatErrorMessage(e));
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  String _formatErrorMessage(Object e) =>
      ErrorHandler.getReadableErrorMessage(e);
}
