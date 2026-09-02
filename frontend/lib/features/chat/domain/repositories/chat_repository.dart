// domain/repositories/chat_repository.dart
import 'package:flutter/foundation.dart';
import '../entities/chat.dart';
import '../entities/group_update_result.dart';
import '../entities/message.dart';

abstract class ChatRepository {
  Future<List<Chat>> getChats();
  Future<Chat> getChat({required int chatId});
  Future<int> createChat(int contactId);
  Future<int> createGroupChat({
    required String name,
    required List<int> memberIds,
    String? avatar,
  });

  // Added pagination parameters matching backend (limit & beforeId)
  Future<List<Message>> getMessages({
    required int chatId,
    int limit = 50,
    int? beforeId,
  });

  Future<Message> sendMessage({
    required int chatId,
    required String text,
  });

  Future<Message> sendFileMessage({
    required int chatId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    Function(int sent, int total)? onProgress,
  });

  Stream<Message> listenMessages();
  Future<void> joinChat(int chatId);
  Future<void> leaveChat(int chatId);

  Future<void> addMember({required int chatId, required int userId});
  Future<void> removeMember({required int chatId, required int userId});
  
  Future<GroupUpdateResult> updateGroupInfo({
    required int chatId,
    String? name,
    Uint8List? avatarBytes,
    String? filename,
    String? mimeType,
  });

  Future<void> markMessagesRead(int chatId);
  Future<void> deleteChat(int chatId);
  Future<void> deleteGroup(int chatId);
  Stream<int> onGroupDeleted();
  Future<void> deleteMessage({required int chatId, required int messageId});
}