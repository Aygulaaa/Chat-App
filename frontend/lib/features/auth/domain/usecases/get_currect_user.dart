import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';

class GetCurrentUser {
  final AuthRepository repository;

  const GetCurrentUser(this.repository);

  Future<UserEntity?> call() {
    return repository.getCurrentUser();
  }
}