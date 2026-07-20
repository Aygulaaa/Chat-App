import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';

class LogoutUser {
  final AuthRepository repository;

  const LogoutUser(this.repository);

  Future<void> call() {
    return repository.logout();
  }
}
