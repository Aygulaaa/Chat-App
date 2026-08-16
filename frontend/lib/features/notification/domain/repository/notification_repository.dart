abstract class NotificationRepository {
  Future<String?> getFcmToken();
  Stream<String> get onTokenRefresh;
  Future<void> syncFcmToken({required String fcmToken});
}