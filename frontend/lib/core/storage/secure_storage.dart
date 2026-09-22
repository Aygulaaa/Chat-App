import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class SecureStorageKeys {
  static const String token = 'auth_token';
}

class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  /// IMPORTANT — do NOT set `IOSOptions(accessibility: …)` here.
  ///
  /// On iOS the plugin includes the accessibility level in every Keychain
  /// lookup. Change it and items saved under the previous level become
  /// invisible to read/update — but they still exist, so the next write fails
  /// with "-25299 The specified item already exists in the keychain" and
  /// nobody can log in. (Keychain items also survive app reinstalls.)
  /// The default, `unlocked`, is also the stricter choice.
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Recover automatically if the Android keystore gets corrupted
      // (e.g. after restoring a device backup) instead of crashing forever.
      resetOnError: true,
    ),
  );

  /// Saves the authentication token securely.
  Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) return;
    try {
      await _storage.write(key: SecureStorageKeys.token, value: token);
    } on PlatformException catch (e) {
      // Self-heal a stale/duplicate Keychain entry: delete clears the key
      // under every accessibility variant, after which the write succeeds.
      debugPrint('Secure storage write failed (${e.code}); resetting key');
      await _storage.delete(key: SecureStorageKeys.token);
      await _storage.write(key: SecureStorageKeys.token, value: token);
    }
  }

  /// Retrieves the authentication token.
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: SecureStorageKeys.token);
    } on PlatformException catch (e) {
      // An unreadable token is the same as no token: send the user to login
      // rather than crashing at startup.
      debugPrint('Secure storage read failed (${e.code})');
      return null;
    }
  }

  /// Removes the authentication token upon logout.
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: SecureStorageKeys.token);
    } on PlatformException catch (e) {
      debugPrint('Secure storage delete failed (${e.code})');
    }
  }

  /// Clears all encrypted key-value pairs stored by the app.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
