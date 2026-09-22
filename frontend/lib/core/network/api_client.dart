import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_chat_app/core/constants/api_config.dart';
import 'package:http_parser/http_parser.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Carries the HTTP status so callers can tell "you are logged out" (401)
/// apart from "the server hiccuped" (5xx) instead of string-matching messages.
/// `toString()` keeps the old `Exception: <message>` shape on purpose — a lot
/// of UI code strips that prefix before showing the text.
class ApiException implements Exception {
  /// Pseudo status codes for failures that never reached the server.
  static const int noConnection = 0;
  static const int timedOut = -1;

  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'Exception: $message';
}

/// Thrown when the user cancels an upload. Not an error to report.
class UploadCancelledException implements Exception {
  const UploadCancelledException();
  @override
  String toString() => 'Upload cancelled';
}

class ApiClient {
  String? _token;

  /// Invoked when an authenticated request comes back 401, i.e. the session
  /// was revoked or expired. Wired to logout in the auth provider.
  void Function()? onUnauthorized;
  String? _deviceName;

  // Increased timeouts for weak network stability
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 120);

  ApiClient() {
    _initDeviceName();
  }

  Future<void> _initDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
         final webInfo = await deviceInfo.webBrowserInfo;
         _deviceName = webInfo.userAgent;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.name;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _deviceName = macInfo.computerName;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        _deviceName = winInfo.computerName;
      }
    } catch (e) {
      _log('Failed to get device info: $e');
    }
  }

  void setToken(String token) {
    // An empty token must not be sent as "Authorization: Bearer "
    _token = token.isEmpty ? null : token;
  }

  void clearToken() {
    _token = null;
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Uri _uri(String path) {
    return Uri.parse('${ApiConfig.baseUrl}$path');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_deviceName != null) 'x-device-name': _deviceName!,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Map<String, String> get _publicHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_deviceName != null) 'x-device-name': _deviceName!,
      };

  Future<dynamic> postPublic(String path, Map<String, dynamic>? body) async {
    return _safeRequest(() => http.post(
          _uri(path),
          headers: _publicHeaders,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> post(String path, Map<String, dynamic>? body) async {
    return _safeRequest(() => http.post(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> get(String path) async {
    _log('🌐 GET ${ApiConfig.baseUrl}$path \n🔑 Token: ${_token != null ? "Present" : "Missing"}');
    return _safeRequest(() => http.get(_uri(path), headers: _headers));
  }

  Future<dynamic> patch(String path, Map<String, dynamic>? body) async {
    return _safeRequest(() => http.patch(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> delete(String path) async {
    return _safeRequest(() => http.delete(_uri(path), headers: _headers));
  }

  Future<dynamic> put(String path, Map<String, dynamic>? body) async {
    return _safeRequest(() => http.put(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> _safeRequest(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn().timeout(_timeout);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(ApiException.timedOut, 'The request timed out.');
    } on SocketException {
      throw const ApiException(ApiException.noConnection, 'No internet connection.');
    } on http.ClientException {
      // What package:http throws for DNS failures, dropped connections…
      // Its toString() is unreadable ("ClientException with SocketException…").
      throw const ApiException(ApiException.noConnection, 'No internet connection.');
    } on HandshakeException {
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response) {
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('📡 URL: ${response.request?.url}');
    _log('📬 Status: ${response.statusCode}');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final contentType = response.headers['content-type'] ?? '';

    if (!contentType.contains('application/json')) {
      // Typically the hosting provider's HTML error page while the server
      // is waking up or redeploying.
      throw ApiException(
        response.statusCode,
        'The server is temporarily unavailable. Please try again in a moment.',
      );
    }

    dynamic data;
    try {
      data = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } on FormatException {
      throw ApiException(response.statusCode, 'Server returned an invalid response.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    // Only treat it as "session is dead" when we actually sent a session.
    if (response.statusCode == 401 &&
        response.request?.headers.containsKey('Authorization') == true) {
      onUnauthorized?.call();
    }

    final errorMessage = (data is Map && data.containsKey('error'))
        ? data['error'].toString()
        : data is Map && data.containsKey('message')
            ? data['message'].toString()
            : 'Request failed with status: ${response.statusCode}';

    throw ApiException(response.statusCode, errorMessage);
  }

  Future<dynamic> postMultipartBytes(
    String path, {
    required Uint8List bytes,
    required String filename,
    required String field,
    required String mimeType,
    Map<String, String> fields = const {},
    Function(int sent, int total)? onProgress,

    /// Complete this future to abort the upload mid-flight.
    Future<void>? abortTrigger,
  }) async {
    _log('🌐 POST multipart: ${ApiConfig.baseUrl}$path');

    try {
      final request = http.MultipartRequest('POST', _uri(path));

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      if (_deviceName != null) {
        request.headers['x-device-name'] = _deviceName!;
      }

      request.fields.addAll(fields);

      request.files.add(
        http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );

      http.Response response;

      if (onProgress != null) {
        final totalBytes = request.contentLength;
        final byteStream = request.finalize();
        int sentBytes = 0;

        final progressStream = byteStream.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (data, sink) {
              sentBytes += data.length;
              onProgress(sentBytes, totalBytes);
              sink.add(data);
            },
          ),
        );

        final streamedRequest = http.AbortableStreamedRequest(
          'POST',
          _uri(path),
          abortTrigger: abortTrigger,
        );
        streamedRequest.headers.addAll(request.headers);
        streamedRequest.contentLength = totalBytes;

        progressStream.listen(
          streamedRequest.sink.add,
          onDone: streamedRequest.sink.close,
          onError: streamedRequest.sink.addError,
          cancelOnError: true,
        );

        final streamedResponse = await streamedRequest.send().timeout(_uploadTimeout);
        response = await http.Response.fromStream(streamedResponse);
      } else {
        final streamedResponse = await request.send().timeout(_uploadTimeout);
        response = await http.Response.fromStream(streamedResponse);
      }

      return _handleResponse(response);
    } on http.RequestAbortedException {
      throw const UploadCancelledException();
    } on TimeoutException {
      throw const ApiException(ApiException.timedOut, 'The upload timed out.');
    } on SocketException {
      throw const ApiException(ApiException.noConnection, 'No internet connection.');
    } on http.ClientException {
      throw const ApiException(ApiException.noConnection, 'No internet connection.');
    }
  }

  Future<dynamic> patchMultipartBytes(
    String path, {
    required Map<String, String> fields,
    Uint8List? bytes,
    String? filename,
    String? field,
    String? mimeType,
  }) async {
    _log('🌐 PATCH multipart: ${ApiConfig.baseUrl}$path');

    try {
      final request = http.MultipartRequest('PATCH', _uri(path));

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      if (_deviceName != null) {
        request.headers['x-device-name'] = _deviceName!;
      }

      request.fields.addAll(fields);

      if (bytes != null && field != null && filename != null && mimeType != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            field,
            bytes,
            filename: filename,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(ApiException.timedOut, 'The upload timed out.');
    } on SocketException {
      throw const ApiException(ApiException.noConnection, 'No internet connection.');
    } on http.ClientException {
      throw const ApiException(ApiException.noConnection, 'No internet connection.');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }
}