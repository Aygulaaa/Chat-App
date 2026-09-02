// domain/usecases/send_message.dart
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class SendMessageParams {
  final int chatId;
  final String text;

  const SendMessageParams({
    required this.chatId,
    required this.text,
  });
}

class SendMessage {
  final ChatRepository repository;
  SendMessage(this.repository);

  Future<Message> call(SendMessageParams params) async {
    final sanitizedText = params.text.trim();
    
    if (params.chatId <= 0) {
      throw ArgumentError('Chat ID must be a positive integer.');
    }
    if (sanitizedText.isEmpty) {
      throw ArgumentError('Message text cannot be empty.');
    }

    return await repository.sendMessage(
      chatId: params.chatId,
      text: sanitizedText,
    );
  }
}