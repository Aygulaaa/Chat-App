import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_chat_app/core/di/global_provider.dart';
import 'package:my_chat_app/core/network/fcm_service.dart';
import 'package:my_chat_app/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:my_chat_app/features/notification/data/repositories/notification_repository.dart';

import 'package:my_chat_app/features/notification/domain/repository/notification_repository.dart';
import 'package:my_chat_app/features/notification/domain/usecases/sync_fcm_token.dart';

part 'notification_provider.g.dart';

@Riverpod(keepAlive: true)
FcmService fcmService(Ref ref) {
  return FcmService();
}

@Riverpod(keepAlive: true)
NotificationRemoteDataSource notificationRemoteDataSource(Ref ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRemoteDataSourceImpl(apiClient: apiClient);
}

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  final remoteDataSource = ref.watch(notificationRemoteDataSourceProvider);
  final fcmService = ref.watch(fcmServiceProvider);
  
  return NotificationRepositoryImpl(
    remoteDataSource: remoteDataSource,
    fcmService: fcmService,
  );
}

@Riverpod(keepAlive: true)
SyncFcmToken syncFcmTokenUseCase(Ref ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return SyncFcmToken(repository);
}