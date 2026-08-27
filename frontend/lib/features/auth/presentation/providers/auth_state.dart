import 'package:my_chat_app/core/common/entities/user_entity.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final UserEntity? user;
  final String? token;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.user,
    this.token,
  });

  /// Evaluates true if an error string exists and is non-empty
  bool get hasError => error != null && error!.trim().isNotEmpty;

  /// Evaluates true when both a valid token and user entity are present
  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? token,
    UserEntity? user,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      user: user ?? this.user,
      token: token ?? this.token,
    );
  }
}