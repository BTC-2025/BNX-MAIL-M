import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_model.dart';
import 'notification_service.dart';

/// Integration boundary for receiving notification payloads from the future backend API
/// or triggering sample notifications during development testing.
class NotificationHandler {
  /// Clean integration point for future backend notification API.
  /// When your colleague's API sends a raw JSON payload, pass it to this method.
  static Future<void> onBackendNotificationReceived(
    Map<String, dynamic> rawPayload,
    WidgetRef ref,
  ) async {
    try {
      print('[NOTIFICATION] Backend notification payload received');
      final event = NotificationEvent.fromJson(rawPayload);
      await NotificationService.instance.handleIncomingEvent(event, ref);
    } catch (e) {
      print('[NOTIFICATION] Error processing backend notification payload: $e');
    }
  }

  /// Development-only helper to trigger a sample notification event locally without backend.
  /// Call programmatically during testing. Does not expose any visible UI buttons.
  static Future<void> triggerTestNotification(
    WidgetRef ref, {
    String? accountEmail,
    String? senderName,
    String? senderEmail,
    String? subject,
    String? preview,
    String? emailId,
  }) async {
    final event = NotificationEvent(
      type: 'new_email',
      accountEmail: accountEmail,
      senderName: senderName ?? 'Test Sender',
      senderEmail: senderEmail ?? 'sender@example.com',
      subject: subject ?? 'Test Email Notification',
      preview: preview ?? 'This is a test notification from BNX Mail.',
      emailId: emailId ?? 'test-email-001',
      timestamp: DateTime.now(),
    );

    print('[NOTIFICATION] Triggering development test notification event');
    await NotificationService.instance.handleIncomingEvent(event, ref);
  }
}
