import 'dart:typed_data';

import 'package:my_chat_app/features/chat/data/datasources/chat_remote_datatsources.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDatatsources remote;
  final ChatSocketDatasource socket;

  ChatRepositoryImpl({required this.remote, required this.socket});

  @override
  Future<Chat> getChat({required int chatId}) {
    return remote.getChat(chatId);
  }

  @override
  Future<List<Chat>> getChats() {
    return remote.getChats();
  }

  @override
  Future<List<Message>> getMessages({required int chatId}) {
    return remote.getMessages(chatId);
  }

  @override
  Future<Message> sendMessage(Message message) async {
    try {
      final response = await remote.sendMessageHttp(message);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<Message> listenMessages() {
    return socket.onMessage().map((data) {
      return MessageModel.fromJson(data);
    });
  }

  @override
  Future<void> joinChat(int chatId) {
    return socket.joinChat(chatId);
  }

  @override
  Future<int> createChat(int contactId) async {
    final chat = await remote.createChat(contactId: contactId);
    return chat.id; // ✅ return just the id
  }

  @override
  Future<Message> sendFileMessage(
    int chatId,
    Uint8List bytes,
    String filename,
    String mimeType, {
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      final response = await remote.sendFileMessage(
        chatId,
        bytes,
        filename,
        mimeType,
        onProgress: onProgress,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addMember(int chatId, int userId) {
    return remote.addMember(chatId, userId);
  }

  @override
  Future<void> removeMember(int chatId, int userId) {
    return remote.removeMember(chatId, userId);
  }

  @override
  Future<Map<String, dynamic>> updateGroupInfo(
    int chatId, {
    String? name,
    Uint8List? avatarBytes,
    String? filename,
    String? mimeType,
  }) {
    return remote.updateGroupInfo(
      chatId,
      name: name,
      avatarBytes: avatarBytes,
      filename: filename,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> deleteChat(int chatId) {
    return remote.deleteChat(chatId);
  }

  @override
  Future<void> deleteGroup(int chatId) {
    return remote.deleteGroup(chatId);
  }

  @override
  Stream<int> onGroupDeleted() {
    return socket.onGroupDeleted();
  }
}
