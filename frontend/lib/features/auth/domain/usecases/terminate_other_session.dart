import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';

class TerminateOtherSessions {
  final AuthRepository repository;
  const TerminateOtherSessions(this.repository);

  Future<void> call() {
    return repository.terminateOtherSessions();
  }
}