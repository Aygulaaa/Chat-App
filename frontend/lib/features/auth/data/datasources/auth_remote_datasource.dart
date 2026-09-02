import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/features/auth/data/models/user_session_model.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDatasource {
  Future<Map<String, dynamic>> login(String username, String password);
  Future<Map<String, dynamic>> register(String username, String password);
  Future<UserModel?> getCurrentUser();
  Future<void> logout();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<bool> verifyPassword(String currentPassword);
  Future<List<UserSessionModel>> getSessions();
  Future<void> revokeSession(int sessionId);
  Future<void> terminateOtherSessions();
}



class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final ApiClient api;

  const AuthRemoteDatasourceImpl(this.api);

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await api.post(
      ApiEndpoints.login,
      {'username': username, 'password': password},
    );

    if (response == null || !response.containsKey('token') || !response.containsKey('user')) {
      throw Exception('Invalid response format from server');
    }

    return {
      'token': response['token'] as String,
      'user': UserModel.fromJson(response['user'] as Map<String, dynamic>),
    };
  }

  @override
  Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    final response = await api.post(
      ApiEndpoints.register,
      {'username': username, 'password': password},
    );

    if (response == null || !response.containsKey('token') || !response.containsKey('user')) {
      throw Exception('Invalid response format from server');
    }

    return {
      'token': response['token'] as String,
      'user': UserModel.fromJson(response['user'] as Map<String, dynamic>),
    };
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final response = await api.get(ApiEndpoints.currentUser);
    if (response == null) return null;

    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    // Correct: Header contains the token; body can safely be empty.
    await api.post(ApiEndpoints.logout, {});
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await api.patch(
      ApiEndpoints.changePassword,
      {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  @override
  Future<bool> verifyPassword(String currentPassword) async {
    final response = await api.post(
      ApiEndpoints.verifyPassword,
      {'currentPassword': currentPassword},
    );

    return response['valid'] as bool? ?? false;
  }

  @override
  Future<List<UserSessionModel>> getSessions() async {
    final response = await api.get(ApiEndpoints.getSessions);
    final list = response['sessions'] as List<dynamic>;

    return list
        .map((json) => UserSessionModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> revokeSession(int sessionId) async {
    await api.delete(ApiEndpoints.revokeSession(sessionId));
  }

  @override
  Future<void> terminateOtherSessions() async {
    await api.delete(ApiEndpoints.terminateOtherSessions);
  }
}