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
    String mimeType, {
    Function(int sent, int total)? onProgress,
  });

  Future<void> addMember(int chatId, int userId);
  Future<void> removeMember(int chatId, int userId);
  Future<Map<String, dynamic>> updateGroupInfo(
    int chatId, {
    String? name,
    Uint8List? avatarBytes,
    String? filename,
    String? mimeType,
  });

  Future<void> deleteChat(int chatId);
  Future<void> deleteGroup(int chatId);
  Stream<int> onGroupDeleted();
}