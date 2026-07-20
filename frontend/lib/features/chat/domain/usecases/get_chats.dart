import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';

class GetChats {
  final ChatRepository  repository;

  const GetChats(this.repository);

  Future<List<Chat>> call(){
    return repository.getChats();
  }
}