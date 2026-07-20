import 'package:flutter/foundation.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

abstract class ChatRepository {

  Future<List<Chat>> getChats();
  Future<Chat> getChat({required int chatId});
  Future<int> createChat( int contactId);

  Future<List<Message>> getMessages({required int chatId});
  Future<Message> sendMessage( Message message);

  Stream<Message> listenMessages();
  Future<void> joinChat(int chatId);

  Future<Message> sendFileMessage(
    int chatId,
    Uint8List bytes,
    String filename,
    String mimeType,
  );

  // Future<void> deleteChat(String chatId);
}