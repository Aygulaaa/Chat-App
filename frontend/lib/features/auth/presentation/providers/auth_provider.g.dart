// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authRemoteDatasource)
final authRemoteDatasourceProvider = AuthRemoteDatasourceProvider._();

final class AuthRemoteDatasourceProvider
    extends
        $FunctionalProvider<
          AuthRemoteDatasource,
          AuthRemoteDatasource,
          AuthRemoteDatasource
        >
    with $Provider<AuthRemoteDatasource> {
  AuthRemoteDatasourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRemoteDatasourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRemoteDatasourceHash();

  @$internal
  @override
  $ProviderElement<AuthRemoteDatasource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthRemoteDatasource create(Ref ref) {
    return authRemoteDatasource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRemoteDatasource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRemoteDatasource>(value),
    );
  }
}

String _$authRemoteDatasourceHash() =>
    r'2ac94f4ed8729cc59a957e79adabb424a1c64dc9';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'703a3cb0bd16ca0e06be612a04b308f8542d65c3';

@ProviderFor(loginUser)
final loginUserProvider = LoginUserProvider._();

final class LoginUserProvider
    extends $FunctionalProvider<LoginUser, LoginUser, LoginUser>
    with $Provider<LoginUser> {
  LoginUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginUserHash();

  @$internal
  @override
  $ProviderElement<LoginUser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoginUser create(Ref ref) {
    return loginUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoginUser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoginUser>(value),
    );
  }
}

String _$loginUserHash() => r'17dd53c60be3f4beefaa62699627f581fe6c1ea2';

@ProviderFor(registerUser)
final registerUserProvider = RegisterUserProvider._();

final class RegisterUserProvider
    extends $FunctionalProvider<RegisterUser, RegisterUser, RegisterUser>
    with $Provider<RegisterUser> {
  RegisterUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'registerUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$registerUserHash();

  @$internal
  @override
  $ProviderElement<RegisterUser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RegisterUser create(Ref ref) {
    return registerUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RegisterUser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RegisterUser>(value),
    );
  }
}

String _$registerUserHash() => r'51ac1ab1866705df310b30bdb02661de682a5ead';

@ProviderFor(logoutUser)
final logoutUserProvider = LogoutUserProvider._();

final class LogoutUserProvider
    extends $FunctionalProvider<LogoutUser, LogoutUser, LogoutUser>
    with $Provider<LogoutUser> {
  LogoutUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logoutUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logoutUserHash();

  @$internal
  @override
  $ProviderElement<LogoutUser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LogoutUser create(Ref ref) {
    return logoutUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogoutUser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogoutUser>(value),
    );
  }
}

String _$logoutUserHash() => r'1d9025548f2ebaf54575a5e74fd7fa3f20189460';

@ProviderFor(getCurrentUser)
final getCurrentUserProvider = GetCurrentUserProvider._();

final class GetCurrentUserProvider
    extends $FunctionalProvider<GetCurrentUser, GetCurrentUser, GetCurrentUser>
    with $Provider<GetCurrentUser> {
  GetCurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getCurrentUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getCurrentUserHash();

  @$internal
  @override
  $ProviderElement<GetCurrentUser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetCurrentUser create(Ref ref) {
    return getCurrentUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetCurrentUser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetCurrentUser>(value),
    );
  }
}

String _$getCurrentUserHash() => r'ea4e58d408e68f8c9b2a6fed3acc3ffe16e8d3f8';

@ProviderFor(AuthNotifier)
final authProvider = AuthNotifierProvider._();

final class AuthNotifierProvider
    extends $NotifierProvider<AuthNotifier, AuthState> {
  AuthNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authNotifierHash();

  @$internal
  @override
  AuthNotifier create() => AuthNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authNotifierHash() => r'895cb3bf06dc7553d1cafd3cfaca44c2fe4e8760';

abstract class _$AuthNotifier extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
