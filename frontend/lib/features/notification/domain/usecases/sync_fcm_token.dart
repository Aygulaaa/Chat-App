import 'package:my_chat_app/features/notification/domain/repository/notification_repository.dart';


class SyncFcmToken {
  final NotificationRepository repository;

  SyncFcmToken(this.repository);

  Future<void> call() async {
    final token = await repository.getFcmToken();
    if (token != null) {
      await repository.syncFcmToken(fcmToken: token);
    }

    // Keep listening for automatic token refreshes from Firebase
    repository.onTokenRefresh.listen((newToken) async {
      await repository.syncFcmToken(fcmToken: newToken);
    });
  }
}