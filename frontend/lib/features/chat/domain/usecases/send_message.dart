import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';

class SendMessage {
  final ChatRepository repository;

  SendMessage(this.repository);

  Future<void> call(Message message) {
    if (message.text?.trim().isEmpty ?? true) {
      throw Exception("Message cannot be empty");
    }

    return repository.sendMessage(message);
  }
}