import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/network/fcm_service.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:my_chat_app/features/notification/data/repositories/notificstion_repository.dart';
import 'package:my_chat_app/features/notification/domain/usecases/sync_fcm_token.dart';

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

final notificationRemoteDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSourceImpl(
    apiClient: ref.read(apiClientProvider),
  );
});

final notificationRepositoryProvider = Provider((ref) {
  return NotificationRepositoryImpl(
    remoteDataSource: ref.read(notificationRemoteDataSourceProvider),
    fcmService: ref.read(fcmServiceProvider),
  );
});

final syncFcmTokenProvider = Provider((ref) {
  return SyncFcmToken(ref.read(notificationRepositoryProvider));
});
