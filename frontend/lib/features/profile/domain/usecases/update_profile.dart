import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/profile/domain/repository/user_repository.dart';

class UpdateProfile {
  final UserRepository repository;

  const UpdateProfile(this.repository);

  Future<UserEntity> call(Map<String, dynamic> body) {
    return repository.updateProfile(body);
  }
}