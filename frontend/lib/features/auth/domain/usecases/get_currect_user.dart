import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';

class GetCurrectUser {
  final AuthRepository repository;

  const GetCurrectUser(this.repository);

  Future<UserEntity?> call() {
    return repository.getCurrentUser();
  }
}
