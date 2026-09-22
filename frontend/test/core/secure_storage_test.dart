import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat_app/core/storage/secure_storage.dart';

/// Reproduces the login failure from the bug report: the Keychain holds an
/// item the plugin can't see, so every write is rejected as a duplicate until
/// the key is deleted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> store;
  late bool ghostItem;
  late List<String> calls;

  setUp(() {
    store = {};
    calls = [];
    ghostItem = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      calls.add(call.method);
      switch (call.method) {
        case 'write':
          if (ghostItem) {
            throw PlatformException(
              code: 'Unexpected security result code',
              message: 'Code: -25299, Message: The specified item already exists in the keychain.',
            );
          }
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          ghostItem = false; // delete clears every accessibility variant
          store.remove(args['key']);
          return null;
        case 'read':
          return store[args['key']];
      }
      return null;
    });
  });

  test('saveToken recovers from a duplicate Keychain item by itself', () async {
    const service = SecureStorageService(SecureStorageService.instance);

    await service.saveToken('fresh-token'); // must not throw

    expect(calls, ['write', 'delete', 'write']);
    expect(await service.getToken(), 'fresh-token');
  });

  test('no iOS accessibility override is configured (the cause of the bug)', () {
    // Changing this makes previously saved items invisible-but-present.
    expect(SecureStorageService.instance.iOptions.toMap()['accessibility'], 'unlocked');
  });

  test('an unreadable token means "logged out", not a crash', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'Unexpected security result code');
    });
    const service = SecureStorageService(SecureStorageService.instance);
    expect(await service.getToken(), isNull);
    await service.deleteToken(); // must not throw either
  });
}
