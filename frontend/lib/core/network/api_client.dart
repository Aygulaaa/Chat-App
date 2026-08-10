import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_chat_app/core/constants/api_config.dart';
import 'package:http_parser/http_parser.dart';

class ApiClient {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Uri _uri(String path) {
    return Uri.parse('${ApiConfig.baseUrl}$path');
  }

  // ✅ УБРАЛИ apikey! Только для вашего бэкенда
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ✅ Для публичных запросов (регистрация, логин) - БЕЗ токена!
  Map<String, String> get _publicHeaders => {
    'Content-Type': 'application/json',
  };

  // ✅ Публичный POST (для регистрации и логина)
  Future<dynamic> postPublic(String path, Map<String, dynamic>? body) async {
    final response = await http.post(
      _uri(path),
      headers: _publicHeaders, // ← БЕЗ токена!
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  // ✅ Защищенный POST (с токеном)
  Future<dynamic> post(String path, Map<String, dynamic>? body) async {
    final response = await http.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> get(String path) async {
    print('🌐 GET ${ApiConfig.baseUrl}$path');
    print('🔑 Token: $_token');
    final response = await http.get(_uri(path), headers: _headers);

    print('📬 Status: ${response.statusCode}');
    print('📬 Body: ${response.body}');
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic>? body) async {
    final response = await http.patch(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers);
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic>? body) async {
    final response = await http.put(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📡 URL: ${response.request?.url}');
    print('📬 Status: ${response.statusCode}');
    print('📋 Headers: ${response.headers}');
    print('📦 Body: ${response.body}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    final contentType = response.headers['content-type'] ?? '';

    if (!contentType.contains('application/json')) {
      throw Exception(
        'Server returned non-JSON response (status ${response.statusCode}). '
        'Check that the endpoint exists and returns JSON.',
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
  }) async {
    print('🌐 POST multipart: ${ApiConfig.baseUrl}$path');
    print('📁 file: $filename | mime: $mimeType | size: ${bytes.length}');

    final request = http.MultipartRequest('POST', _uri(path));

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('📬 status: ${response.statusCode}');
    print('📬 body: ${response.body}');

    return _handleResponse(response);
  }
}