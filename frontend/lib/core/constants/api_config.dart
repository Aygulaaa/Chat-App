import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiConfig {
  static late final String baseUrl;
  static late final String socketUrl;

  /// Your live Render backend URL as the primary production/cloud target
  static const String _liveBackendUrl = 'https://chat-backend-gzci.onrender.com';

  /// Bulletproof initialization
  static Future<void> init() async {
    final envApi = dotenv.env['APICONFIG']?.trim();
    final envSocket = dotenv.env['SOCKET_URL']?.trim();

    // 1. If explicitly defined in .env (e.g. during custom local testing), use .env
    if (envApi != null && envApi.isNotEmpty && envSocket != null && envSocket.isNotEmpty) {
      baseUrl = _cleanUrl(envApi);
      socketUrl = _cleanUrl(envSocket);
    } else {
      // 2. Otherwise, check platform target
      final host = await _resolveHost();
      baseUrl = '${_cleanUrl(host)}/api';
      socketUrl = _cleanUrl(host);
    }

    print('✅ ApiConfig initialized successfully!');
    print('🔗 API URL: $baseUrl');
    print('🔗 Socket URL: $socketUrl');
  }

  /// Resolves target host dynamically
  static Future<String> _resolveHost() async {
    // If you want simulators to test locally, keep localhost/10.0.2.2 logic.
    // BUT if you want everything (Simulator + Physical Phone) to connect to Render,
    // simply return _liveBackendUrl here!
    
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        if (!iosInfo.isPhysicalDevice) {
          // Change to 'http://localhost:5000' if running local node server on Mac
          return _liveBackendUrl; 
        }
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        if (!androidInfo.isPhysicalDevice) {
          // Change to 'http://10.0.2.2:5000' if running local node server on Mac
          return _liveBackendUrl;
        }
      }
    } catch (e) {
      print('⚠️ Device info lookup failed ($e), falling back to live server.');
    }

    return _liveBackendUrl;
  }

  /// Trims trailing slashes
  static String _cleanUrl(String url) {
    var cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}