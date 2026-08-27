import '../../../../core/common/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remote;

  AuthRepositoryImpl(this.remote);

  @override
  Future<UserEntity> login({
    required String username,
    required String password,
  }) {
    return remote.login(username, password);
  }

  @override
  Future<UserEntity> register({
    required String username,
    required String password,
  }) {
    return remote.register(username, password);
  }

  @override
  Future<UserEntity?> getCurrentUser() {
    return remote.getCurrentUser();
  }

  @override
  Future<void> logout() {
    return remote.logout();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return remote.changePassword(currentPassword, newPassword);
  }
}
