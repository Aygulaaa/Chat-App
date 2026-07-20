import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static  final baseUrl =  dotenv.env['APICONFIG']!;
}

// http://10.0.2.2:5000/api android emulator'http://localhost:5000'
// http://192.168.1.5:5000/api physical device'http://192.168.0.111:5000';