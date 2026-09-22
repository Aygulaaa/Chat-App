import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';

String read(dynamic e) => ErrorHandler.getReadableErrorMessage(e);

/// Nothing a user sees may look like this.
final _jargon = RegExp(
  r"Exception|Error\(|PlatformException|-25299|null\)|errno|package:|Instance of|\bOS Error\b",
);

void main() {
  test('the Keychain error from the bug report is readable and actionable', () {
    final e = PlatformException(
      code: 'Unexpected security result code',
      message: 'Code: -25299, Message: The specified item already exists in the keychain.',
      details: -25299,
    );
    final msg = read(e);
    expect(msg, isNot(matches(_jargon)));
    expect(msg, contains("couldn't be saved securely"));
    expect(msg, contains('try again'));

    // …and also if it arrives already flattened into a string
    expect(read(Exception(e.toString())), isNot(matches(_jargon)));
  });

  test('every kind of failure yields plain language with a next step', () {
    final cases = <dynamic, String>{
      const SocketException('Failed host lookup: x (OS Error: nodename nor servname, errno = 8)'): 'Wi-Fi',
      http.ClientException('SocketException: Connection refused'): 'Wi-Fi',
      const ApiException(ApiException.noConnection, 'No internet connection.'): 'Wi-Fi',
      TimeoutException('Future not completed'): 'wait a few seconds',
      const ApiException(ApiException.timedOut, 'x'): 'wait a few seconds',
      const HandshakeException('CERTIFICATE_VERIFY_FAILED'): 'date and time',
      const FormatException('Unexpected character'): 'update',
      const ApiException(401, 'Invalid username or password'): 'Create an account',
      const ApiException(401, 'Session invalid or expired'): 'log in again',
      const ApiException(400, 'Username is already taken'): 'adding numbers',
      const ApiException(400, 'Incorrect password'): 'Caps Lock',
      const ApiException(429, 'Too many attempts, please try again in 15 minutes'): '15 minutes',
      const ApiException(413, 'File is too large'): '50 MB',
      const ApiException(403, 'Access denied: You are not a member of this chat'): 'no longer a member',
      const ApiException(403, 'Only the group creator can remove other members'): 'Ask them',
      const ApiException(404, 'Chat not found'): 'no longer exists',
      const ApiException(500, 'Internal server error'): "it's not you",
      const ApiException(502, 'The server is temporarily unavailable.'): "it's not you",
      StateError('Bad state: No element'): 'try again',
      "type 'Null' is not a subtype of type 'String'": 'try again',
      null: 'try again',
    };
    cases.forEach((error, expected) {
      final msg = read(error);
      expect(msg, contains(expected), reason: '$error');
      expect(msg, isNot(matches(_jargon)), reason: '$error → $msg');
    });
  });

  test('messages already written for people pass through, even re-wrapped', () {
    expect(read(const ApiException(400, 'Group name cannot be empty')), 'Group name cannot be empty');
    expect(
      read(Exception('Exception: Message is too long (max 4000 characters)')),
      'Message is too long (max 4000 characters)',
    );
    // translating twice must not change the text
    final once = read(const ApiException(401, 'Invalid username or password'));
    expect(read(Exception(once)), once);
  });
}
