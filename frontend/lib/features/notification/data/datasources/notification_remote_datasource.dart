import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/network/api_client.dart';

abstract class NotificationRemoteDataSource {
  Future<void> sendFcmTokenToServer({required String fcmToken});
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient apiClient;

  NotificationRemoteDataSourceImpl({
    required this.apiClient,
  });

  @override
  Future<void> sendFcmTokenToServer({required String fcmToken}) async {
    await apiClient.post(
      ApiEndpoints.sendFcmToken(),
      {'fcmToken': fcmToken},
    );
  }
}