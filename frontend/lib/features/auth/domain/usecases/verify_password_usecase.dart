import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';

class VerifyPassword {
  final AuthRepository repository;

  const VerifyPassword(this.repository);

  Future<bool> call(String currentPassword) {
    return repository.verifyPassword(currentPassword);
  }
}