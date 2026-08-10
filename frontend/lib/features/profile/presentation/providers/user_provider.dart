import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import '../../domain/repository/user_repository.dart';
import '../../data/repository/user_remote_datasourceImpl.dart';
import '../../data/datasources/user_remote_datasource.dart';
import 'dart:async';

final userRemoteDatasourceProvider = Provider((ref) {
  final api = ref.read(apiClientProvider);
  return UserRemoteDatasource(api);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final remote = ref.read(userRemoteDatasourceProvider);
  return UserRepositoryImpl(remote);
});

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserEntity?>(() {
      return UserProfileNotifier();
    });

final userByIdProvider =
    FutureProvider.family<UserEntity?, int>((ref, userId) async {
  return ref.read(userRepositoryProvider).getUserById(userId);
});

class UserProfileNotifier extends AsyncNotifier<UserEntity?> {
  @override
  FutureOr<UserEntity?> build() async {
    final authState = ref.watch(authProvider);
    if (authState.isLoading) return null;

    if (authState.user == null) return null;

    return ref.read(userRepositoryProvider).getMe();
  }

  Future<void> fetchProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).getMe(),
    );
  }

Future<void> updateAvatarFromBytes(Uint8List bytes, String filename) async {
  final previous = state;
  state = await AsyncValue.guard(() async {
    return ref
        .read(userRepositoryProvider)
        .uploadAvatarFromBytes(bytes, filename);
  });
  if (state.hasError) {
    print('❌ Avatar upload failed: ${state.error}');
    state = previous;
  }
}

  Future<void> updateInfo(Map<String, dynamic> data) async {
    final previous = state;
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).updateProfile(data),
    );
    if (state.hasError) state = previous;
  }

  Future<UserEntity> getUserById(int userId) async {
    state = 
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).getUserById(userId),
    );
    return state.value!;
  }
}
