import 'package:flutter/foundation.dart';
import 'package:my_chat_app/features/notification/domain/repository/notification_repository.dart';

class SyncFcmToken {
  final NotificationRepository _repository;

  SyncFcmToken(this._repository);

  /// Synchronizes a given FCM token with the backend database.
  Future<void> call(String fcmToken) async {
    if (fcmToken.trim().isEmpty) {
      debugPrint('⚠️ FCM Token is empty, skipping network sync.');
      return;
    }

    try {
      await _repository.syncFcmToken(fcmToken: fcmToken);
      debugPrint('✅ FCM Token successfully synced to backend.');
    } catch (e, stackTrace) {
      debugPrint('❌ Error syncing FCM token: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }
}