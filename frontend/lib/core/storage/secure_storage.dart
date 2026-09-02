import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class SecureStorageKeys {
  static const String token = 'auth_token';
}

class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  /// Hardened configuration without deprecated parameters
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Saves the authentication token securely.
  Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) return;
    await _storage.write(
      key: SecureStorageKeys.token,
      value: token,
    );
  }

  /// Retrieves the authentication token.
  Future<String?> getToken() async {
    return _storage.read(key: SecureStorageKeys.token);
  }

  /// Removes the authentication token upon logout.
  Future<void> deleteToken() async {
    await _storage.delete(key: SecureStorageKeys.token);
  }

  /// Clears all encrypted key-value pairs stored by the app.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}