import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
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

  // The app-lock password used to be written to disk as PLAINTEXT. It is now
  // stored as  v1$<salt>$<hash>  — a salted, iterated SHA-256 — so reading the
  // app's files no longer reveals a password people tend to reuse elsewhere.
  static const _hashPrefix = r'v1$';
  static const _iterations = 20000;

  static String _hash(String password, String saltHex) {
    var digest = sha256.convert(utf8.encode('$saltHex:$password')).bytes;
    for (var i = 0; i < _iterations; i++) {
      digest = sha256.convert([...digest, ...utf8.encode(saltHex)]).bytes;
    }
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _encode(String password) {
    final random = Random.secure();
    final salt = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '$_hashPrefix$salt\$${_hash(password, salt)}';
  }

  static bool _matches(String password, String stored) {
    if (!stored.startsWith(_hashPrefix)) return stored == password; // legacy
    final parts = stored.split(r'$');
    if (parts.length != 3) return false;
    final expected = parts[2];
    final actual = _hash(password, parts[1]);
    // Constant-time comparison
    var diff = expected.length ^ actual.length;
    for (var i = 0; i < expected.length && i < actual.length; i++) {
      diff |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    return diff == 0;
  }

  @override
  LocalAuthState build() {
    final box = Hive.box<String>(_boxName);
    final password = box.get(_passwordKey);
    final isSet = password != null && password.isNotEmpty;

    // One-time upgrade of a password saved by an older build
    if (isSet && !password.startsWith(_hashPrefix)) {
      box.put(_passwordKey, _encode(password));
    }

    return LocalAuthState(
      isPasswordSet: isSet,
      // Only lock on startup if a password is set
      isLocked: isSet,
    );
  }

  Future<void> setLocalPassword(String newPassword) async {
    final box = Hive.box<String>(_boxName);
    await box.put(_passwordKey, _encode(newPassword));
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
    if (savedPassword != null && _matches(password, savedPassword)) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    return false;
  }

  /// Checks a passcode WITHOUT changing the lock state — used before letting
  /// someone change or turn off the lock from Settings.
  bool verifyLocalPassword(String password) {
    final saved = Hive.box<String>(_boxName).get(_passwordKey);
    return saved != null && _matches(password, saved);
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
