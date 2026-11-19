import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../client/api_exceptions.dart';
import '../../config/api_config.dart';
import 'notification_model.dart';

/// Dedicated service responsible for notification API interactions.
///
/// Base URL: `https://api.bit-tool.com/api` (configurable).
class NotificationsApiService {
  final BitToolApiClient _client;
  final BitToolApiConfig _config;

  NotificationsApiService({
    required BitToolApiClient client,
    BitToolApiConfig config = const BitToolApiConfig(),
  })  : _client = client,
        _config = config;

  /// Retrieves notifications for the currently authenticated user via GET /notifications.
  Future<List<NotificationModel>> getNotifications() async {
    final uri = _config.notificationsUri;

    try {
      final dynamic raw = await _client.get(uri);
      List<NotificationModel> notifications = [];

      if (raw is List) {
        notifications = raw
            .whereType<Map>()
            .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } else if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        var listData = map['data'] ??
            map['notifications'] ??
            map['results'] ??
            map['items'];

        if (listData is Map) {
          final nested = Map<String, dynamic>.from(listData);
          listData = nested['notifications'] ??
              nested['items'] ??
              nested['results'] ??
              nested['data'];
        }

        if (listData is List) {
          notifications = listData
              .whereType<Map>()
              .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }

      return notifications;
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationsAPI] getNotifications error: $e');
      rethrow;
    }
  }

  /// Marks a single notification as read via PUT /notifications/:id/read.
  Future<bool> markOneAsRead(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw const BitToolApiException('Notification ID cannot be empty.');
    }

    final uri = _config.notificationReadUri(cleanId);

    try {
      await _client.put(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationsAPI] markOneAsRead error: $e');
      rethrow;
    }
  }

  /// Marks all notifications as read via PUT /notifications/read-all.
  Future<bool> markAllAsRead() async {
    final uri = _config.notificationsReadAllUri;

    try {
      await _client.put(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationsAPI] markAllAsRead error: $e');
      rethrow;
    }
  }
}

