import 'package:my_chat_app/core/common/entities/user_entity.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final UserEntity? user;
  final String? token;

  /// Seconds the server asked us to wait before trying again (brute-force
  /// lockout / throttling). Null when no lockout is in effect.
  final int? retryAfterSeconds;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.user,
    this.token,
    this.retryAfterSeconds,
  });

  /// Evaluates true if an error string exists and is non-empty
  bool get hasError => error != null && error!.trim().isNotEmpty;

  /// Evaluates true when both a valid token and user entity are present
  bool get isAuthenticated => token != null && user != null;

  bool get isLockedOut => retryAfterSeconds != null && retryAfterSeconds! > 0;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? token,
    UserEntity? user,
    bool clearError = false,
    int? retryAfterSeconds,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      user: user ?? this.user,
      token: token ?? this.token,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
    );
  }
}