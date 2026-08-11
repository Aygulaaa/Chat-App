import 'package:my_chat_app/core/storage/secure_storage.dart';

import '../models/user_model.dart';
import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/network/api_client.dart';

class AuthRemoteDatasource {
  final ApiClient api;
  final SecureStorage storage;

  AuthRemoteDatasource(this.api, this.storage);

  Future<UserModel> login(String username, String password) async {
    final response = await api.post(ApiEndpoints.login, {
      'username': username,
      'password': password,
    });
    final token = response['token'];
    await storage.saveToken(token);
    api.setToken(token);

    return UserModel.fromJson(response['user']);
  }

  Future<UserModel> register( String username, String password) async {
    final response = await api.post(ApiEndpoints.register, {
      'username': username,
      'password': password,
    });
    final token = response['token'];

    await storage.saveToken(token); 
    api.setToken(token); 

    return UserModel.fromJson(response['user']);
  }

  Future<void> logout() async {
    await storage.deleteToken();
    api.setToken('');
    await api.delete(ApiEndpoints.logout);
  }

  Future<void> loadToken() async {
    final token = await storage.getToken();
    if (token != null) {
      api.setToken(token);
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final response = await api.get(ApiEndpoints.currentUser);

    return UserModel.fromJson(response);
  }
}
