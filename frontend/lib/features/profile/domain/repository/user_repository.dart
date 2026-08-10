import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'dart:typed_data';

abstract class UserRepository{
  Future<UserEntity> getMe();
  Future<UserEntity> updateProfile(Map<String, dynamic> body);
  Future<UserEntity> uploadAvatarFromBytes(Uint8List bytes, String filename);
  Future<UserEntity> getUserById(int userId);
}