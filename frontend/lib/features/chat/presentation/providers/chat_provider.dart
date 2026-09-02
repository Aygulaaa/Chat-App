import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_chat_app/core/di/global_provider.dart';

import 'package:my_chat_app/features/chat/data/datasources/chat_remote_datatsources.dart';
import 'package:my_chat_app/features/chat/data/datasources/chat_socket_datasource.dart';
import 'package:my_chat_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:my_chat_app/features/chat/data/repositories/chat_socket_datasourceImpl.dart';

import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:my_chat_app/features/chat/domain/usecases/create_chat.dart';
import 'package:my_chat_app/features/chat/domain/usecases/get_chat.dart';
import 'package:my_chat_app/features/chat/domain/usecases/get_chats.dart';
import 'package:my_chat_app/features/chat/domain/usecases/get_messages.dart';
import 'package:my_chat_app/features/chat/domain/usecases/send_message.dart';

part 'chat_provider.g.dart';

// -----------------------------------------------------------------------------
// Data Layer
// -----------------------------------------------------------------------------

/// HTTP data source — singleton, never auto-disposed.
@Riverpod(keepAlive: true)
ChatRemoteDatatsources chatRemoteDataSource(Ref ref) {
  return ChatRemoteDatatsources(ref.watch(apiClientProvider));
}

/// Socket data source — singleton.  The same instance is shared across
/// all providers (chatNotifier, messageNotifier, userStatusNotifier).
@Riverpod(keepAlive: true)
ChatSocketDatasource chatSocketDataSource(Ref ref) {
  return ChatSocketDatasourceImpl();
}

// -----------------------------------------------------------------------------
// Domain Layer — Repository
// -----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  return ChatRepositoryImpl(
    remote: ref.watch(chatRemoteDataSourceProvider),
    socket: ref.watch(chatSocketDataSourceProvider),
  );
}

// -----------------------------------------------------------------------------
// Domain Layer — Use Cases
// -----------------------------------------------------------------------------

@Riverpod(keepAlive: true)
GetChats getChats(Ref ref) => GetChats(ref.watch(chatRepositoryProvider));

@Riverpod(keepAlive: true)
GetChat getChat(Ref ref) => GetChat(ref.watch(chatRepositoryProvider));

@Riverpod(keepAlive: true)
GetMessages getMessages(Ref ref) => GetMessages(ref.watch(chatRepositoryProvider));

@Riverpod(keepAlive: true)
SendMessage sendMessage(Ref ref) => SendMessage(ref.watch(chatRepositoryProvider));

@Riverpod(keepAlive: true)
CreateChat createChat(Ref ref) => CreateChat(ref.watch(chatRepositoryProvider));
