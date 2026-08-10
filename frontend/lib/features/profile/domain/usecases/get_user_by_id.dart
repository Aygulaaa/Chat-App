import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/profile/domain/repository/user_repository.dart';

class GetUserById {
  final UserRepository repository;
  const GetUserById(this.repository);

  Future<UserEntity> call(int userId) {
    return repository.getUserById(userId);
  }
}