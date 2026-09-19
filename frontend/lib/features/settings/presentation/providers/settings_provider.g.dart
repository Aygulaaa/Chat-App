// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(settingsDatasource)
final settingsDatasourceProvider = SettingsDatasourceProvider._();

final class SettingsDatasourceProvider
    extends
        $FunctionalProvider<
          SettingsRemoteDatasource,
          SettingsRemoteDatasource,
          SettingsRemoteDatasource
        >
    with $Provider<SettingsRemoteDatasource> {
  SettingsDatasourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsDatasourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsDatasourceHash();

  @$internal
  @override
  $ProviderElement<SettingsRemoteDatasource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRemoteDatasource create(Ref ref) {
    return settingsDatasource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRemoteDatasource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRemoteDatasource>(value),
    );
  }
}

String _$settingsDatasourceHash() =>
    r'39e263fc58f17089037dba74d0426326b9f0c47b';

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          SettingsRepository,
          SettingsRepository,
          SettingsRepository
        >
    with $Provider<SettingsRepository> {
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'49a11de139c4848f05e083bdd0394a44ccc4f885';

@ProviderFor(SettingsNotifier)
final settingsProvider = SettingsNotifierProvider._();

final class SettingsNotifierProvider
    extends $AsyncNotifierProvider<SettingsNotifier, UserSettings?> {
  SettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsNotifierHash();

  @$internal
  @override
  SettingsNotifier create() => SettingsNotifier();
}

String _$settingsNotifierHash() => r'37d44abd984f5f8c9092a01459d74ed57fe095cc';

abstract class _$SettingsNotifier extends $AsyncNotifier<UserSettings?> {
  FutureOr<UserSettings?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserSettings?>, UserSettings?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserSettings?>, UserSettings?>,
              AsyncValue<UserSettings?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
