import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/users/domain/repository/user_repository.dart';

class GetMe {
  final UserRepository repository;

  const GetMe(this.repository);

  Future<UserEntity> call(){
    return repository.getMe();
  }
}