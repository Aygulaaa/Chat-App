import '../repositories/chat_repository.dart';

class CreateChat {
  final ChatRepository repository;

  CreateChat(this.repository);

  Future<int> call(int contactId) {
    return repository.createChat(contactId);
  }
}