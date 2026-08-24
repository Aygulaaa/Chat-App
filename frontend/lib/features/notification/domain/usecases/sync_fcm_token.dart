import 'package:flutter/foundation.dart';
import 'package:my_chat_app/features/notification/domain/repository/notification_repository.dart';

class SyncFcmToken {
  final NotificationRepository repository;

  SyncFcmToken(this.repository);

  Future<void> call() async {
    try {
      // 1. Fetch and sync the current token right away if available
      final token = await repository.getFcmToken();
      if (token != null && token.isNotEmpty) {
        await repository.syncFcmToken(fcmToken: token);
        debugPrint('FCM Token successfully synced on startup.');
      } else {
        debugPrint('FCM Token is null or empty on startup.');
      }
    } catch (e, stackTrace) {
      // Log or handle initial sync failure
      debugPrint('Error syncing FCM token on startup: $e');
      debugPrint('$stackTrace');
    }

    // 2. Listen for future token refreshes (e.g., app reinstall, cache clear, etc.)
    repository.onTokenRefresh.listen(
      (newToken) async {
        try {
          if (newToken.isNotEmpty) {
            await repository.syncFcmToken(fcmToken: newToken);
            debugPrint('Refreshed FCM Token successfully synced.');
          }
        } catch (e, stackTrace) {
          // Log or handle stream sync failure without crashing the listener stream
          debugPrint('Error syncing refreshed FCM token: $e');
          debugPrint('$stackTrace');
        }
      },
      onError: (error, stackTrace) {
        // Handle potential stream errors
        debugPrint('FCM token refresh stream error: $error');
        debugPrint('$stackTrace');
      },
    );
  }
}