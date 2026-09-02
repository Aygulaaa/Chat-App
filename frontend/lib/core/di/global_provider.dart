import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/storage/secure_storage.dart';

part 'global_provider.g.dart';

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient();

@Riverpod(keepAlive: true)
FlutterSecureStorage flutterSecureStorage(Ref ref) => const FlutterSecureStorage();

@Riverpod(keepAlive: true)
SecureStorageService secureStorage(Ref ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
}