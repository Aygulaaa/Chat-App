import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';

class GetMessages {
  final ChatRepository repository;

  const GetMessages(this.repository);

  Future<List<Message>> call({required int chatId}) {
    return repository.getMessages(chatId: chatId);
  }
}