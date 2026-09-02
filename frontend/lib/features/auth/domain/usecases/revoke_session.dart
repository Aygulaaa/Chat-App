import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';

class RevokeSession {
  final AuthRepository repository;
  const RevokeSession(this.repository);

  Future<void> call(int sessionId) {
    return repository.revokeSession(sessionId);
  }
}