import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/di/global_provider.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import '../../domain/repository/user_repository.dart';
import '../../data/repository/user_remote_datasourceImpl.dart';
import '../../data/datasources/user_remote_datasource.dart';

part 'user_provider.g.dart';

@Riverpod(keepAlive: true)
UserRemoteDatasource userRemoteDatasource(Ref ref) {
  final api = ref.watch(apiClientProvider);
  return UserRemoteDatasource(api);
}

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) {
  final remote = ref.watch(userRemoteDatasourceProvider);
  return UserRepositoryImpl(remote);
}

@Riverpod(keepAlive: true)
Future<UserEntity?> userById(Ref ref, int userId) async {
  return ref.read(userRepositoryProvider).getUserById(userId);
}

@Riverpod(keepAlive: true)
class UserProfile extends _$UserProfile {
  @override
  FutureOr<UserEntity?> build() async {
    final authState = ref.watch(authProvider);
    if (authState.isLoading) return null;

    if (authState.user != null) {
      _fetchServerProfile();
      return authState.user;
    }

    UserEntity? cached;
    try {
      final cachedStr = Hive.box<String>(
        'user_profile_cache',
      ).get('my_profile');
      if (cachedStr != null) {
        cached = UserModel.fromJson(jsonDecode(cachedStr));
      }
    } catch (_) {}

    _fetchServerProfile();
    return cached;
  }

  Future<void> _fetchServerProfile() async {
    try {
      final fresh = await ref.read(userRepositoryProvider).getMe();
      if (!ref.mounted) return;
      state = AsyncValue.data(fresh);
      _cacheProfile(fresh);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.value == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> _cacheProfile(UserEntity user) async {
    try {
      final model = UserModel(
        id: user.id,
        username: user.username,
        avatar: user.avatar,
        bio: user.bio,
        birthDate: user.birthDate,
        status: user.status,
        lastSeen: user.lastSeen,
        lastSeenFuzzy: user.lastSeenFuzzy,
      );
      await Hive.box<String>(
        'user_profile_cache',
      ).put('my_profile', jsonEncode(model.toJson()));
    } catch (_) {}
  }

  Future<void> fetchProfile() async {
    state = const AsyncValue.loading();
    await _fetchServerProfile();
  }

  Future<void> updateAvatarFromBytes(Uint8List bytes, String filename) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final updated = await ref
          .read(userRepositoryProvider)
          .uploadAvatarFromBytes(bytes, filename);
      _cacheProfile(updated);
      return updated;
    });
    if (state.hasError) {
      print('❌ Avatar upload failed: ${state.error}');
      state = previous;
    }
  }

  /// Throws on failure. It used to swallow the error (restore the old state,
  /// return normally), so the edit screen closed as if the save had worked
  /// even when the server said e.g. "username already taken".
  Future<void> updateInfo(Map<String, dynamic> data) async {
    final updated = await ref.read(userRepositoryProvider).updateProfile(data);
    if (!ref.mounted) return;
    state = AsyncValue.data(updated);
    _cacheProfile(updated);
  }

  Future<UserEntity> getUserById(int userId) async {
    final result = await ref.read(userRepositoryProvider).getUserById(userId);
    return result;
  }
}
