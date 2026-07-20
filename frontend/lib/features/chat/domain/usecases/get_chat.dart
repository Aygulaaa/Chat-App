import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';

class GetChat {
  final ChatRepository repository;

  const GetChat(this.repository);

  Future<Chat> call ({ required int chatId}) {
    return repository.getChat(chatId: chatId);
  }
}