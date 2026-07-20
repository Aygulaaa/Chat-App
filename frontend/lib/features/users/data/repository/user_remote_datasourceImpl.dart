import 'dart:typed_data';

import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/users/data/datasources/user_remote_datasource.dart';
import 'package:my_chat_app/features/users/domain/repository/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDatasource  remoteDatasource;

  UserRepositoryImpl(this.remoteDatasource);

  @override
  Future<UserEntity> getMe() async {
    final user= await remoteDatasource.getMe();
    print("DEBUG: Repository mapped user: ${user.id}, ${user.username}");
    return user;
  }

  @override
  Future<UserEntity> updateProfile(Map<String, dynamic> body) async {
    return await remoteDatasource.updateProfile(body);
  }

  @override
  Future<UserEntity> uploadAvatarFromBytes(Uint8List bytes, String filename) async {
    return await remoteDatasource.uploadAvatarFromBytes(bytes, filename);
  }

  @override
  Future<UserEntity> getUserById(int userId) async {
    return await remoteDatasource.getUserById(userId);
  }

}