import 'package:my_chat_app/core/network/fcm_service.dart';
import 'package:my_chat_app/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:my_chat_app/features/notification/domain/repository/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;
  final FcmService fcmService;

  NotificationRepositoryImpl({
    required this.remoteDataSource,
    required this.fcmService,
  });

  @override
  Future<String?> getFcmToken() => fcmService.getToken();

  @override
  Stream<String> get onTokenRefresh => fcmService.onTokenRefresh;

  @override
  Future<void> syncFcmToken({required String fcmToken}) async {
    await remoteDataSource.sendFcmTokenToServer(fcmToken: fcmToken);
  }
}