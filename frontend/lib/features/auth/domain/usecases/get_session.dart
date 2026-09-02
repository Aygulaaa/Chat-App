import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';
import 'package:my_chat_app/features/auth/domain/repositories/auth_repository.dart';

class GetSessions {
  final AuthRepository repository;
  const GetSessions(this.repository);

  Future<List<UserSessionEntity>> call() {
    return repository.getSessions();
  }
}