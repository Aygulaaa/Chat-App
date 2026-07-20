import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository repository;

  const LoginUser(this.repository);

  Future<UserEntity> call({
    required String username,
    required String password,
  }) {
    return  repository.login(username: username, password: password);
  }
}