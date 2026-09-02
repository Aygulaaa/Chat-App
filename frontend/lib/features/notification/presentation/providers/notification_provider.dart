import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/di/global_provider.dart';
import 'package:my_chat_app/core/network/fcm_service.dart';
import 'package:my_chat_app/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:my_chat_app/features/notification/data/repositories/notification_repository.dart';

import 'package:my_chat_app/features/notification/domain/repository/notification_repository.dart';
import 'package:my_chat_app/features/notification/domain/usecases/sync_fcm_token.dart';

/// Pure FCM Service provider
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

/// Remote Data Source for Notification API calls
final notificationRemoteDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRemoteDataSourceImpl(apiClient: apiClient);
});

/// Repository Provider (typed to abstract domain interface)
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final remoteDataSource = ref.watch(notificationRemoteDataSourceProvider);
  final fcmService = ref.watch(fcmServiceProvider);
  
  return NotificationRepositoryImpl(
    remoteDataSource: remoteDataSource,
    fcmService: fcmService,
  );
});

/// Use Case for syncing FCM token to server
final syncFcmTokenUseCaseProvider = Provider<SyncFcmToken>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return SyncFcmToken(repository);
});