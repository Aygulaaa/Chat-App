import 'package:my_chat_app/core/common/entities/user_entity.dart';

abstract class AuthRepository {
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
}