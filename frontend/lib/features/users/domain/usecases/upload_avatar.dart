import 'dart:typed_data';

import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/users/domain/repository/user_repository.dart';

class UploadAvatar {
  final UserRepository repository;

  const UploadAvatar(this.repository);

  Future<UserEntity> call(Uint8List bytes, String filename) {
    return repository.uploadAvatarFromBytes(bytes, filename);
  }
}