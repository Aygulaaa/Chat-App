import 'dart:typed_data';
import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import '../models/user_model.dart';

class UserRemoteDatasource {
  final ApiClient api;

  UserRemoteDatasource(this.api);

  Future<UserModel> getMe() async {
    final response = await api.get(ApiEndpoints.me);
    return UserModel.fromJson(response);
  }

  Future<UserModel> updateProfile(Map<String, dynamic> updateData) async {
    final response= await api.put(ApiEndpoints.me, updateData);
    return UserModel.fromJson(response);
  }

  Future<UserModel> getUserById(int userId) async {
    final response = await api.get(ApiEndpoints.userById(userId));
    return UserModel.fromJson(response);
  }

Future<UserModel> uploadAvatarFromBytes(Uint8List bytes, String filename) async {
  final ext = filename.split('.').last.toLowerCase();
  final mimeType = switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png'           => 'image/png',
    'webp'          => 'image/webp',
    'gif'           => 'image/gif',
    _               => 'image/jpeg', 
  };
  final response = await api.postMultipartBytes(
    ApiEndpoints.uploadAvatar,
    bytes: bytes,
    filename: filename,
    field: 'avatar',
    mimeType:mimeType, 
  );
  return UserModel.fromJson(response);
}
}