import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static late final String baseUrl;
  static late final String socketUrl;

  // ✅ Вызывай ЭТОТ метод после загрузки .env
  static void init() {
    baseUrl = dotenv.env['APICONFIG'] ?? 'http://localhost:5000/api';
    socketUrl = dotenv.env['SOCKET_URL'] ?? 'http://localhost:5000';

    print('✅ ApiConfig initialized!');
    print('🔗 API URL: $baseUrl');
    print('🔗 Socket URL: $socketUrl');
  }
}

// http://10.0.2.2:5000/api android emulator'http://localhost:5000'
// http://192.168.1.5:5000/api physical device'http://192.168.0.111:5000';
