import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';

abstract interface class AuthRepository {
  Future<UserEntity> login({
    required String username,
    required String password,
  });

  Future<UserEntity> register({
    required String username,
    required String password,
  });

  Future<UserEntity?> getCurrentUser();

  Future<void> logout();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<bool> verifyPassword(String currentPassword);
  
  Future<List<UserSessionEntity>> getSessions();
  
  Future<void> revokeSession(int sessionId);
  
  Future<void> terminateOtherSessions();
}