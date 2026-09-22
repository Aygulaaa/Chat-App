import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:my_chat_app/core/network/api_client.dart';

/// Turns any thrown object into a sentence a person can act on:
/// **what happened** + **what to do next**. Never class names, codes or
/// stack fragments — those go to the debug console instead.
///
/// Every place that shows an error to the user goes through
/// [getReadableErrorMessage].
class ErrorHandler {
  static const _generic =
      'Something went wrong on our side. Please try again — if it keeps '
      'happening, close and reopen the app.';

  static String getReadableErrorMessage(dynamic error) {
    final message = _translate(error);
    if (kDebugMode) debugPrint('⚠️ [${error.runtimeType}] $error → "$message"');
    return message;
  }

  static String _translate(dynamic error) {
    if (error == null) return _generic;

    // ── Typed errors first: no guessing from text ────────────────────────
    if (error is ApiException) return _fromApi(error);

    if (error is PlatformException) return _fromPlatform(error);

    if (error is TimeoutException) return _timeout;

    if (error is HandshakeException || error is TlsException) return _tls;

    if (error is SocketException || error is http.ClientException) {
      return _offline;
    }

    if (error is MissingPluginException) {
      return 'A part of the app failed to start. Close the app completely '
          'and open it again.';
    }

    if (error is FormatException || error is TypeError) {
      return "The app received a response it didn't understand. Please update "
          'to the latest version, or try again in a few minutes.';
    }

    // Dart `Error`s (StateError, RangeError…) are bugs in our code. Their text
    // is for developers and is never useful to the person using the app.
    if (error is Error) return _generic;

    // ── Everything else: inspect the text ────────────────────────────────
    final text = _stripPrefix(error.toString());
    final lower = text.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('no internet')) {
      return _offline;
    }
    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('took too long')) {
      return _timeout;
    }
    if (lower.contains('handshake') || lower.contains('certificate')) {
      return _tls;
    }
    if (lower.contains('platformexception') || lower.contains('keychain')) {
      return _secureStorage;
    }

    final known = _knownMessage(text);
    if (known != null) return known;

    // A message we (or the server) wrote for humans passes through untouched;
    // anything that smells like a raw exception does not.
    return _looksTechnical(text) ? _generic : text;
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  static const _offline =
      "Can't reach the server. Check your Wi-Fi or mobile data, then try "
      'again.';

  static const _timeout =
      'This is taking longer than usual. The server may be waking up — wait '
      'a few seconds and try again.';

  static const _tls =
      "A secure connection couldn't be established. Make sure your device's "
      'date and time are set automatically, then try again.';

  static const _secureStorage =
      "Your login couldn't be saved securely on this device. Close the app "
      'completely and try again. If it still fails, reinstall the app.';

  static const _serverDown =
      "Our server is having trouble right now — it's not you. Wait a moment "
      'and try again.';

  static const _sessionEnded =
      'Your session has ended. Please log in again to continue.';

  static String _fromPlatform(PlatformException e) {
    final detail = '${e.code} ${e.message}'.toLowerCase();
    if (detail.contains('keychain') ||
        detail.contains('security result') ||
        detail.contains('keystore') ||
        detail.contains('-25')) {
      return _secureStorage;
    }
    if (detail.contains('permission') || detail.contains('denied')) {
      return "The app doesn't have permission to do that. Open your phone's "
          'Settings, find this app, and allow the permission.';
    }
    if (detail.contains('camera')) {
      return "The camera couldn't be opened. Close other apps using it and "
          'try again.';
    }
    return _generic;
  }

  static String _fromApi(ApiException e) {
    final known = _knownMessage(e.message);
    if (known != null) return known;

    switch (e.statusCode) {
      case ApiException.noConnection:
        return _offline;
      case ApiException.timedOut:
        return _timeout;
      case 401:
        return _sessionEnded;
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return "We couldn't find that — it may have been deleted. Go back "
            'and refresh.';
      case 413:
        return 'That file is too large. The limit is 50 MB — try a smaller '
            'file or compress it first.';
      case 429:
        return 'Too many attempts. Please wait about 15 minutes before '
            'trying again.';
    }
    if (e.statusCode >= 500) return _serverDown;

    // 400-level: the server's text is written for users — keep it unless it
    // leaked something technical.
    return _looksTechnical(e.message) ? _generic : e.message;
  }

  /// Server / app messages we know, rewritten with a concrete next step.
  static String? _knownMessage(String raw) {
    final m = raw.toLowerCase();

    if (m.contains('invalid username or password')) {
      return 'Wrong username or password. Check for typos — or tap '
          '"Create an account" if you\'re new here.';
    }
    if (m.contains('already taken')) {
      return 'That username is already taken. Try a variation, like adding '
          'numbers or an underscore.';
    }
    if (m.contains('incorrect password')) {
      return "That password isn't right. Check Caps Lock and try again.";
    }
    if (m.contains('too many')) {
      return 'Too many attempts. Please wait about 15 minutes before trying '
          'again.';
    }
    if (m.contains('session invalid') ||
        m.contains('session expired') ||
        m.contains('token missing') ||
        m.contains('unauthorized') ||
        m.contains('not authenticated')) {
      return _sessionEnded;
    }
    if (m.contains('not a member')) {
      return "You're no longer a member of this chat. Go back to your chat "
          'list and refresh.';
    }
    if (m.contains('only the group creator')) {
      return 'Only the person who created this group can do that. Ask them '
          'to do it for you.';
    }
    if (m.contains('file is too large') || m.contains('too large')) {
      return 'That file is too large. The limit is 50 MB — try a smaller '
          'file or compress it first.';
    }
    if (m.contains('temporarily unavailable') ||
        m.contains('internal server error') ||
        m.contains('invalid response')) {
      return _serverDown;
    }
    if (m.contains('user not found')) {
      return "We couldn't find that user — the account may have been deleted.";
    }
    if (m.contains('chat not found') || m.contains('group not found')) {
      return 'This chat no longer exists. Go back to your chat list and '
          'refresh.';
    }
    return null;
  }

  static String _stripPrefix(String text) {
    var out = text.trim();
    // "Exception: Exception: message" happens when errors are re-wrapped
    while (out.startsWith('Exception: ')) {
      out = out.substring('Exception: '.length).trim();
    }
    return out;
  }

  static final _technical = RegExp(
    r'(Exception|Error)\b[:(]|\bnull\b|^type |is not a subtype|Bad state|'
    r"#\d+\s|package:|dart:|errno|Instance of '|\bStackTrace\b|[{}<>]",
  );

  static bool _looksTechnical(String text) =>
      text.isEmpty || text.length > 220 || _technical.hasMatch(text);
}
