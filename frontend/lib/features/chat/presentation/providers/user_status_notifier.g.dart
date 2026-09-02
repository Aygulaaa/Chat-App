// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_status_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserStatusNotifier)
final userStatusProvider = UserStatusNotifierProvider._();

final class UserStatusNotifierProvider
    extends $NotifierProvider<UserStatusNotifier, UserStatusState> {
  UserStatusNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userStatusNotifierHash();

  @$internal
  @override
  UserStatusNotifier create() => UserStatusNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserStatusState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserStatusState>(value),
    );
  }
}

String _$userStatusNotifierHash() =>
    r'8434dfeb8ae75c41aad099067527a2192e7dfadd';

abstract class _$UserStatusNotifier extends $Notifier<UserStatusState> {
  UserStatusState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UserStatusState, UserStatusState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserStatusState, UserStatusState>,
              UserStatusState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
