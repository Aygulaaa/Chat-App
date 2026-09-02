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
    });
    return MessageModel.fromJson(response);
  }

  Future<List<MessageModel>> getMessages(int chatId) async {
    try {
      final response = await api.get(ApiEndpoints.messages(chatId));
      print('DEBUG: Raw Response from API: $response');
      print('DEBUG: Response Type: ${response.runtimeType}');

      if (response is! List) {
        print('❌ ERROR: Expected a List but got ${response.runtimeType}');
        throw Exception('Server returned invalid data format');
      }

      return response.map((e) {
        try {
          return MessageModel.fromJson(e as Map<String, dynamic>);
        } catch (e) {
          print('❌ JSON PARSING ERROR: $e');
          print('DATA AT FAULT: $e');
          rethrow;
        }
      }).toList();
    } catch (err) {
      print('❌ getMessages failure: $err');
      rethrow;
    }
  }

  Future<MessageModel> sendFileMessage(
    int chatId,
    Uint8List bytes,
    String filename,
    String mimeType, {
    Function(int sent, int total)? onProgress,
  }) async {
    final response = await api.postMultipartBytes(
      ApiEndpoints.fileMessage(chatId),
      bytes: bytes,
      filename: filename,
      field: 'file',
      mimeType: mimeType,
      onProgress: onProgress,
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
