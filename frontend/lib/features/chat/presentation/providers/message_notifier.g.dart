// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MessageNotifier)
final messageProvider = MessageNotifierFamily._();

final class MessageNotifierProvider
    extends $NotifierProvider<MessageNotifier, MessageState> {
  MessageNotifierProvider._({
    required MessageNotifierFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'messageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$messageNotifierHash();

  @override
  String toString() {
    return r'messageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MessageNotifier create() => MessageNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MessageNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$messageNotifierHash() => r'd74cd616c3cb87d792b7e78e4ac31986fd0380ce';

final class MessageNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          MessageNotifier,
          MessageState,
          MessageState,
          MessageState,
          int
        > {
  MessageNotifierFamily._()
    : super(
        retry: null,
        name: r'messageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MessageNotifierProvider call(int chatId) =>
      MessageNotifierProvider._(argument: chatId, from: this);

  @override
  String toString() => r'messageProvider';
}

abstract class _$MessageNotifier extends $Notifier<MessageState> {
  late final _$args = ref.$arg as int;
  int get chatId => _$args;

  MessageState build(int chatId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MessageState, MessageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MessageState, MessageState>,
              MessageState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
