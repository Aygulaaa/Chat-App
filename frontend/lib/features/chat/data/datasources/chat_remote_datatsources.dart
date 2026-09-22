import 'dart:typed_data';

import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/features/chat/data/models/chat_model.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class ChatRemoteDatatsources {
  final ApiClient api;
  ChatRemoteDatatsources(this.api);

  Future<List<ChatModel>> getChats() async {
    final data = await api.get(ApiEndpoints.chats);

    return (data as List).map((e) => ChatModel.fromJson(e)).toList();
  }

  Future<ChatModel> getChat(int chatId) async {
    final response = await api.get(ApiEndpoints.chat(chatId));

    return ChatModel.fromJson(response);
  }

  Future<ChatModel> createChat({required int contactId}) async {
    final response = await api.post(ApiEndpoints.createChat(contactId), {
      'contactId': contactId,
    });

    return ChatModel.fromJson(response);
  }

  Future<MessageModel> sendMessageHttp(Message message) async {
    final response = await api.post(ApiEndpoints.messages(message.chatId), {
      'text': message.text,
      if (message.replyTo != null) 'replyToId': message.replyTo!.id,
    });
    return MessageModel.fromJson(response);
  }

  /// Newest first. Pass [beforeId] (the oldest id already loaded) to page back.
  Future<List<MessageModel>> getMessages(
    int chatId, {
    int limit = 50,
    int? beforeId,
  }) async {
    final query = [
      'limit=$limit',
      if (beforeId != null) 'before=$beforeId',
    ].join('&');
    final response = await api.get('${ApiEndpoints.messages(chatId)}?$query');

    if (response is! List) {
      throw Exception('Server returned invalid data format');
    }

    return response
        .whereType<Map>()
        .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MessageModel> sendFileMessage(
    int chatId,
    Uint8List bytes,
    String filename,
    String mimeType, {
    int? replyToId,
    Function(int sent, int total)? onProgress,
    Future<void>? abortTrigger,
  }) async {
    final response = await api.postMultipartBytes(
      ApiEndpoints.fileMessage(chatId),
      bytes: bytes,
      filename: filename,
      field: 'file',
      mimeType: mimeType,
      fields: {if (replyToId != null) 'replyToId': '$replyToId'},
      onProgress: onProgress,
      abortTrigger: abortTrigger,
    );
    return MessageModel.fromJson(response);
  }

  Future<Map<String, dynamic>> createGroupChat({
    required String name,
    required List<int> memberIds,
    String? avatar,
  }) async {
    final response = await api.post(ApiEndpoints.createGroupChat, {
      'name': name,
      'memberIds': memberIds,
      'avatar': avatar,
    });
    return response as Map<String, dynamic>;
  }

  Future<void> addMember(int chatId, int userId) async {
    await api.post(ApiEndpoints.addMember(chatId), {'userId': userId});
  }

  Future<void> removeMember(int chatId, int userId) async {
    await api.delete(ApiEndpoints.removeMember(chatId, userId));
  }

  Future<Map<String, dynamic>> updateGroupInfo(
    int chatId, {
    String? name,
    Uint8List? avatarBytes,
    String? filename,
    String? mimeType,
  }) async {
    final fields = <String, String>{};
    if (name != null) fields['name'] = name;

    if (avatarBytes != null && filename != null && mimeType != null) {
      final response = await api.patchMultipartBytes(
        ApiEndpoints.groupInfo(chatId),
        fields: fields,
        bytes: avatarBytes,
        filename: filename,
        field: 'avatar',
        mimeType: mimeType,
      );
      return response as Map<String, dynamic>;
    } else {
      final response = await api.patch(ApiEndpoints.groupInfo(chatId), fields);
      return response as Map<String, dynamic>;
    }
  }

  /// Per-recipient delivered/read status of one of my messages.
  Future<List<Map<String, dynamic>>> getMessageReceipts(
    int chatId,
    int messageId,
  ) async {
    final response = await api.get(
      '${ApiEndpoints.deleteMessage(chatId, messageId)}/receipts',
    );
    return (response as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Adds, replaces or clears my reaction. Returns the message's new list.
  Future<List<MessageReaction>> setReaction(
    int chatId,
    int messageId,
    String emoji,
  ) async {
    final response = await api.put(
      ApiEndpoints.messageReaction(chatId, messageId),
      {'emoji': emoji},
    );
    if (response is! Map) return const [];
    return MessageModel.parseReactions(response['reactions']);
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    await api.delete(ApiEndpoints.deleteMessage(chatId, messageId));
  }

  Future<void> markMessagesRead(int chatId) async {
    await api.patch(ApiEndpoints.markMessagesRead(chatId), {});
  }

  Future<void> deleteChat(int chatId) async {
    await api.delete(ApiEndpoints.deleteChat(chatId));
  }

  Future<void> deleteGroup(int chatId) async {
    await api.delete(ApiEndpoints.deleteGroup(chatId));
  }
}
