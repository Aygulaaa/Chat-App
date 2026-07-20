import 'package:my_chat_app/core/common/entities/user_entity.dart';

class AuthState{
  final bool isLoading;
  final String? error;
  final UserEntity? user;
  final String? token;

  AuthState({
    this.isLoading = true,
    this.error,
    this.user,
    this.token
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? token,
    UserEntity? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      user: user ?? this.user,
      token: token ?? this.token
    );
  }
}