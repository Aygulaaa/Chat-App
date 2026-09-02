import 'dart:typed_data';

import 'package:my_chat_app/features/chat/data/datasources/chat_remote_datatsources.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/domain/entities/group_update_result.dart';
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
  Future<List<Message>> getMessages({
    required int chatId,
    int limit = 50,
    int? beforeId,
  }) {
    return remote.getMessages(chatId);
  }

  @override
  Future<Message> sendMessage({
    required int chatId,
    required String text,
  }) async {
    try {
      final message = MessageModel(
        id: 0,
        chatId: chatId,
        senderId: 0,
        text: text,
        createdAt: DateTime.now(),
      );
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
  Future<void> leaveChat(int chatId) {
    return socket.leaveChat(chatId);
  }

  @override
  Future<int> createChat(int contactId) async {
    final chat = await remote.createChat(contactId: contactId);
    return chat.id; // ✅ return just the id
  }

  @override
  Future<int> createGroupChat({
    required String name,
    required List<int> memberIds,
    String? avatar,
  }) async {
    final response = await remote.createGroupChat(
      name: name,
      memberIds: memberIds,
      avatar: avatar,
    );
    return response['id'] as int;
  }

  @override
  Future<Message> sendFileMessage({
    required int chatId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
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
  Future<void> addMember({required int chatId, required int userId}) {
    return remote.addMember(chatId, userId);
  }

  @override
  Future<void> removeMember({required int chatId, required int userId}) {
    return remote.removeMember(chatId, userId);
  }

  @override
  Future<GroupUpdateResult> updateGroupInfo({
    required int chatId,
    String? name,
    Uint8List? avatarBytes,
    String? filename,
    String? mimeType,
  }) async {
    final response = await remote.updateGroupInfo(
      chatId,
      name: name,
      avatarBytes: avatarBytes,
      filename: filename,
      mimeType: mimeType,
    );
    return GroupUpdateResult(
      id: response['id'] ?? chatId,
      name: response['name'],
      avatar: response['avatar'],
      type: response['type'] ?? 'group',
    );
  }

  @override
  Future<void> markMessagesRead(int chatId) {
    return remote.markMessagesRead(chatId);
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

  @override
  Future<void> deleteMessage({required int chatId, required int messageId}) {
    return remote.deleteMessage(chatId, messageId);
  }
}
