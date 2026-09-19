// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionsNotifier)
final sessionsProvider = SessionsNotifierProvider._();

final class SessionsNotifierProvider
    extends $AsyncNotifierProvider<SessionsNotifier, List<UserSessionEntity>> {
  SessionsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsNotifierHash();

  @$internal
  @override
  SessionsNotifier create() => SessionsNotifier();
}

String _$sessionsNotifierHash() => r'283c72b43bfa1564f8176bd4bd9c890c46d7b4ea';

abstract class _$SessionsNotifier
    extends $AsyncNotifier<List<UserSessionEntity>> {
  FutureOr<List<UserSessionEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<UserSessionEntity>>,
              List<UserSessionEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<UserSessionEntity>>,
                List<UserSessionEntity>
              >,
              AsyncValue<List<UserSessionEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
