// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// HTTP data source — singleton, never auto-disposed.

@ProviderFor(chatRemoteDataSource)
final chatRemoteDataSourceProvider = ChatRemoteDataSourceProvider._();

/// HTTP data source — singleton, never auto-disposed.

final class ChatRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          ChatRemoteDatatsources,
          ChatRemoteDatatsources,
          ChatRemoteDatatsources
        >
    with $Provider<ChatRemoteDatatsources> {
  /// HTTP data source — singleton, never auto-disposed.
  ChatRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<ChatRemoteDatatsources> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChatRemoteDatatsources create(Ref ref) {
    return chatRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRemoteDatatsources value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRemoteDatatsources>(value),
    );
  }
}

String _$chatRemoteDataSourceHash() =>
    r'9b9f982c4348b91ad84a5a3fafe01b6476e9e479';

/// Socket data source — singleton.  The same instance is shared across
/// all providers (chatNotifier, messageNotifier, userStatusNotifier).

@ProviderFor(chatSocketDataSource)
final chatSocketDataSourceProvider = ChatSocketDataSourceProvider._();

/// Socket data source — singleton.  The same instance is shared across
/// all providers (chatNotifier, messageNotifier, userStatusNotifier).

final class ChatSocketDataSourceProvider
    extends
        $FunctionalProvider<
          ChatSocketDatasource,
          ChatSocketDatasource,
          ChatSocketDatasource
        >
    with $Provider<ChatSocketDatasource> {
  /// Socket data source — singleton.  The same instance is shared across
  /// all providers (chatNotifier, messageNotifier, userStatusNotifier).
  ChatSocketDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatSocketDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatSocketDataSourceHash();

  @$internal
  @override
  $ProviderElement<ChatSocketDatasource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChatSocketDatasource create(Ref ref) {
    return chatSocketDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatSocketDatasource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatSocketDatasource>(value),
    );
  }
}

String _$chatSocketDataSourceHash() =>
    r'054ec23ab16dd6df32e13eca8ed268f0bee21d6a';

@ProviderFor(chatRepository)
final chatRepositoryProvider = ChatRepositoryProvider._();

final class ChatRepositoryProvider
    extends $FunctionalProvider<ChatRepository, ChatRepository, ChatRepository>
    with $Provider<ChatRepository> {
  ChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChatRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatRepository create(Ref ref) {
    return chatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepository>(value),
    );
  }
}

String _$chatRepositoryHash() => r'2092b6a10a38e7d45b6cc27bcc9597aed3407c05';

@ProviderFor(getChats)
final getChatsProvider = GetChatsProvider._();

final class GetChatsProvider
    extends $FunctionalProvider<GetChats, GetChats, GetChats>
    with $Provider<GetChats> {
  GetChatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getChatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getChatsHash();

  @$internal
  @override
  $ProviderElement<GetChats> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetChats create(Ref ref) {
    return getChats(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetChats value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetChats>(value),
    );
  }
}

String _$getChatsHash() => r'3c15abd40ef9ca74611d8b81b11f4f8d644c0316';

@ProviderFor(getChat)
final getChatProvider = GetChatProvider._();

final class GetChatProvider
    extends $FunctionalProvider<GetChat, GetChat, GetChat>
    with $Provider<GetChat> {
  GetChatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getChatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getChatHash();

  @$internal
  @override
  $ProviderElement<GetChat> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetChat create(Ref ref) {
    return getChat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetChat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetChat>(value),
    );
  }
}

String _$getChatHash() => r'0b16d603a3a220878634aab03bced9368196a7c4';

@ProviderFor(getMessages)
final getMessagesProvider = GetMessagesProvider._();

final class GetMessagesProvider
    extends $FunctionalProvider<GetMessages, GetMessages, GetMessages>
    with $Provider<GetMessages> {
  GetMessagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getMessagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getMessagesHash();

  @$internal
  @override
  $ProviderElement<GetMessages> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetMessages create(Ref ref) {
    return getMessages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetMessages value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetMessages>(value),
    );
  }
}

String _$getMessagesHash() => r'a3d187bc772fcdc168ff0fc424fa824cfb9304d5';

@ProviderFor(sendMessage)
final sendMessageProvider = SendMessageProvider._();

final class SendMessageProvider
    extends $FunctionalProvider<SendMessage, SendMessage, SendMessage>
    with $Provider<SendMessage> {
  SendMessageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sendMessageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sendMessageHash();

  @$internal
  @override
  $ProviderElement<SendMessage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SendMessage create(Ref ref) {
    return sendMessage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SendMessage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SendMessage>(value),
    );
  }
}

String _$sendMessageHash() => r'f542065dd8300289e010712dca50d1b8cd5adcad';

@ProviderFor(createChat)
final createChatProvider = CreateChatProvider._();

final class CreateChatProvider
    extends $FunctionalProvider<CreateChat, CreateChat, CreateChat>
    with $Provider<CreateChat> {
  CreateChatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'createChatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$createChatHash();

  @$internal
  @override
  $ProviderElement<CreateChat> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CreateChat create(Ref ref) {
    return createChat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreateChat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreateChat>(value),
    );
  }
}

String _$createChatHash() => r'21cbd350acd20b6ffdf7e6d763676ebc9abf3471';
