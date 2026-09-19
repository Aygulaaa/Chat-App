import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';

class LocalAuthState {
  final bool isPasswordSet;
  final bool isLocked;

  const LocalAuthState({
    required this.isPasswordSet,
    required this.isLocked,
  });

  LocalAuthState copyWith({
    bool? isPasswordSet,
    bool? isLocked,
  }) {
    return LocalAuthState(
      isPasswordSet: isPasswordSet ?? this.isPasswordSet,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class LocalAuthNotifier extends Notifier<LocalAuthState> {
  static const _boxName = 'local_auth_cache';
  static const _passwordKey = 'local_password';

  @override
  LocalAuthState build() {
    final box = Hive.box<String>(_boxName);
    final password = box.get(_passwordKey);
    final isSet = password != null && password.isNotEmpty;
    return LocalAuthState(
      isPasswordSet: isSet,
      // Only lock on startup if a password is set
      isLocked: isSet,
    );
  }

  Future<void> setLocalPassword(String newPassword) async {
    final box = Hive.box<String>(_boxName);
    await box.put(_passwordKey, newPassword);
    state = state.copyWith(isPasswordSet: true, isLocked: false);
  }

  Future<void> removeLocalPassword() async {
    final box = Hive.box<String>(_boxName);
    await box.delete(_passwordKey);
    state = state.copyWith(isPasswordSet: false, isLocked: false);
  }

  bool unlockWithPassword(String password) {
    final box = Hive.box<String>(_boxName);
    final savedPassword = box.get(_passwordKey);
    if (savedPassword == password) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    return false;
  }

  void lockApp() {
    if (state.isPasswordSet) {
      state = state.copyWith(isLocked: true);
    }
  }

  Future<bool> verifyBackendPassword(String accountPassword) async {
    final authNotifier = ref.read(authProvider.notifier);
    final isValid = await authNotifier.verifyPassword(accountPassword);
    if (isValid) {
      // Allow user to reset/remove local password since they verified via backend
      await removeLocalPassword();
      return true;
    }
    return false;
  }
}

final localAuthProvider = NotifierProvider<LocalAuthNotifier, LocalAuthState>(
  () => LocalAuthNotifier(),
);
