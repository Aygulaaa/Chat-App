import 'package:flutter/foundation.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/storage/secure_storage.dart';
import 'package:my_chat_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';
import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;
  final SecureStorageService storage;
  final ApiClient api;

  const AuthRepositoryImpl({
    required this.remoteDatasource,
    required this.storage,
    required this.api,
  });

  @override
  Future<UserEntity> login({
    required String username,
    required String password,
  }) async {
    final result = await remoteDatasource.login(username, password);
    final token = result['token'] as String;

    await storage.saveToken(token);
    api.setToken(token);

    return result['user'] as UserEntity;
  }

  @override
  Future<UserEntity> register({
    required String username,
    required String password,
  }) async {
    final result = await remoteDatasource.register(username, password);
    final token = result['token'] as String;

    await storage.saveToken(token);
    api.setToken(token);

    return result['user'] as UserEntity;
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final token = await storage.getToken();
    if (token == null || token.isEmpty) return null;

    api.setToken(token);
    return await remoteDatasource.getCurrentUser();
  }

  @override
  Future<void> logout() async {
    try {
      await remoteDatasource.logout();
    } catch (e) {
      // Allow local logout to proceed if network is down or session is expired
      // but log it to avoid silent failures hiding backend issues
      debugPrint('Remote logout failed: $e');
    } finally {
      await storage.deleteToken();
      api.setToken('');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await remoteDatasource.changePassword(currentPassword, newPassword);
  }

  @override
  Future<bool> verifyPassword(String currentPassword) async {
    return await remoteDatasource.verifyPassword(currentPassword);
  }

  @override
  Future<List<UserSessionEntity>> getSessions() async {
    return await remoteDatasource.getSessions();
  }

  @override
  Future<void> revokeSession(int sessionId) async {
    await remoteDatasource.revokeSession(sessionId);
  }

  @override
  Future<void> terminateOtherSessions() async {
    await remoteDatasource.terminateOtherSessions();
  }
}