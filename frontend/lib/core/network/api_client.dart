import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_chat_app/core/constants/api_config.dart';
import 'package:http_parser/http_parser.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiClient {
  String? _token;
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
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

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
    } on TimeoutException {
      throw Exception('Connection timed out due to slow network. Please try again.');
    } on SocketException {
      throw Exception('No internet connection available.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unexpected network error occurred: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('📡 URL: ${response.request?.url}');
    _log('📬 Status: ${response.statusCode}');
    _log('📦 Body: ${response.body}');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final contentType = response.headers['content-type'] ?? '';

    if (!contentType.contains('application/json')) {
      throw Exception(
        'Server returned non-JSON response (status ${response.statusCode}).',
      );
    }
    
    final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final errorMessage = (data is Map && data.containsKey('error'))
        ? data['error'].toString()
        : data is Map && data.containsKey('message')
            ? data['message'].toString()
            : 'Request failed with status: ${response.statusCode}';

    throw Exception(errorMessage);
  }

  Future<dynamic> postMultipartBytes(
    String path, {
    required Uint8List bytes,
    required String filename,
    required String field,
    required String mimeType,
    Function(int sent, int total)? onProgress,
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

        final streamedRequest = http.StreamedRequest('POST', _uri(path));
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
    } on TimeoutException {
      throw Exception('File upload took too long due to slow network. Please try again.');
    } on SocketException {
      throw Exception('No internet connection available during upload.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Multipart upload failed: $e');
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
      throw Exception('Upload timed out.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Patch multipart failed: $e');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }
}