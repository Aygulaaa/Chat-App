// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contacts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contactsDatasource)
final contactsDatasourceProvider = ContactsDatasourceProvider._();

final class ContactsDatasourceProvider
    extends
        $FunctionalProvider<
          ContactsRemoteDatasource,
          ContactsRemoteDatasource,
          ContactsRemoteDatasource
        >
    with $Provider<ContactsRemoteDatasource> {
  ContactsDatasourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactsDatasourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactsDatasourceHash();

  @$internal
  @override
  $ProviderElement<ContactsRemoteDatasource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContactsRemoteDatasource create(Ref ref) {
    return contactsDatasource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactsRemoteDatasource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactsRemoteDatasource>(value),
    );
  }
}

String _$contactsDatasourceHash() =>
    r'd361743233f54f959b4c3642d4b8e7be21c19cd0';

@ProviderFor(contactsRepository)
final contactsRepositoryProvider = ContactsRepositoryProvider._();

final class ContactsRepositoryProvider
    extends
        $FunctionalProvider<
          ContactsRepository,
          ContactsRepository,
          ContactsRepository
        >
    with $Provider<ContactsRepository> {
  ContactsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ContactsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContactsRepository create(Ref ref) {
    return contactsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactsRepository>(value),
    );
  }
}

String _$contactsRepositoryHash() =>
    r'd7483abd6c8c6016dc81f34cb2e2b8c70ed03872';

@ProviderFor(ContactsNotifier)
final contactsProvider = ContactsNotifierProvider._();

final class ContactsNotifierProvider
    extends $AsyncNotifierProvider<ContactsNotifier, List<Contact>> {
  ContactsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactsNotifierHash();

  @$internal
  @override
  ContactsNotifier create() => ContactsNotifier();
}

String _$contactsNotifierHash() => r'c76fabb7a61d109365bb986a301f161ea33721fa';

abstract class _$ContactsNotifier extends $AsyncNotifier<List<Contact>> {
  FutureOr<List<Contact>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Contact>>, List<Contact>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Contact>>, List<Contact>>,
              AsyncValue<List<Contact>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(BlockedContactsNotifier)
final blockedContactsProvider = BlockedContactsNotifierProvider._();

final class BlockedContactsNotifierProvider
    extends $AsyncNotifierProvider<BlockedContactsNotifier, List<Contact>> {
  BlockedContactsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blockedContactsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blockedContactsNotifierHash();

  @$internal
  @override
  BlockedContactsNotifier create() => BlockedContactsNotifier();
}

String _$blockedContactsNotifierHash() =>
    r'c91b468cd1397991fd379591d0d7434efa5f10ac';

abstract class _$BlockedContactsNotifier extends $AsyncNotifier<List<Contact>> {
  FutureOr<List<Contact>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Contact>>, List<Contact>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Contact>>, List<Contact>>,
              AsyncValue<List<Contact>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(searchUsers)
final searchUsersProvider = SearchUsersFamily._();

final class SearchUsersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Contact>>,
          List<Contact>,
          FutureOr<List<Contact>>
        >
    with $FutureModifier<List<Contact>>, $FutureProvider<List<Contact>> {
  SearchUsersProvider._({
    required SearchUsersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchUsersProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchUsersHash();

  @override
  String toString() {
    return r'searchUsersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Contact>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Contact>> create(Ref ref) {
    final argument = this.argument as String;
    return searchUsers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchUsersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchUsersHash() => r'6ffe13278ae065f43f16c1ad2fb143a9849b3e76';

final class SearchUsersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Contact>>, String> {
  SearchUsersFamily._()
    : super(
        retry: null,
        name: r'searchUsersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SearchUsersProvider call(String query) =>
      SearchUsersProvider._(argument: query, from: this);

  @override
  String toString() => r'searchUsersProvider';
}
