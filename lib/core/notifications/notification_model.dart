import 'package:flutter/foundation.dart';

/// Frontend notification model representing a notification event.
/// Tolerates missing/null fields and flexible key naming from future backend APIs.
@immutable
class NotificationEvent {
  final String? type;
  final String? notificationId;
  final String? accountEmail;
  final String? accountId;
  final String? emailId;
  final String? uid;
  final String? messageId;
  final String? senderName;
  final String? senderEmail;
  final String? subject;
  final String? preview;
  final DateTime? timestamp;

  const NotificationEvent({
    this.type = 'new_email',
    this.notificationId,
    this.accountEmail,
    this.accountId,
    this.emailId,
    this.uid,
    this.messageId,
    this.senderName,
    this.senderEmail,
    this.subject,
    this.preview,
    this.timestamp,
  });

  /// Factory constructor with clean parsing layer for future backend API integration.
  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parsedTimestamp;
    final rawTime = json['timestamp'] ?? json['time'] ?? json['created_at'];
    if (rawTime is String) {
      parsedTimestamp = DateTime.tryParse(rawTime);
    } else if (rawTime is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is DateTime) {
      parsedTimestamp = rawTime;
    }

    return NotificationEvent(
      type: (json['type'] ?? json['eventType'] ?? json['event_type'] ?? 'new_email')?.toString(),
      notificationId: (json['notificationId'] ?? json['notification_id'] ?? json['id'])?.toString(),
      accountEmail: (json['accountEmail'] ?? json['account_email'] ?? json['email'] ?? json['account'])?.toString(),
      accountId: (json['accountId'] ?? json['account_id'])?.toString(),
      emailId: (json['emailId'] ?? json['email_id'])?.toString(),
      uid: json['uid']?.toString(),
      messageId: (json['messageId'] ?? json['message_id'])?.toString(),
      senderName: (json['senderName'] ?? json['sender_name'] ?? json['sender'])?.toString(),
      senderEmail: (json['senderEmail'] ?? json['sender_email'] ?? json['from'])?.toString(),
      subject: (json['subject'] ?? json['title'])?.toString(),
      preview: (json['preview'] ?? json['body'] ?? json['snippet'])?.toString(),
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'notificationId': notificationId,
      'accountEmail': accountEmail,
      'accountId': accountId,
      'emailId': emailId,
      'uid': uid,
      'messageId': messageId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'subject': subject,
      'preview': preview,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  /// Helper to derive the best available email identifier.
  String? get effectiveEmailId {
    if (emailId != null && emailId!.trim().isNotEmpty) return emailId!.trim();
    if (messageId != null && messageId!.trim().isNotEmpty) return messageId!.trim();
    if (uid != null && uid!.trim().isNotEmpty) return uid!.trim();
    return null;
  }

  /// Helper to derive the target account email/id.
  String? get effectiveAccountIdentifier {
    if (accountEmail != null && accountEmail!.trim().isNotEmpty) return accountEmail!.trim();
    if (accountId != null && accountId!.trim().isNotEmpty) return accountId!.trim();
    return null;
  }

  /// Helper to format sender name or fallback to email or app name.
  String get formattedSender {
    if (senderName != null && senderName!.trim().isNotEmpty) {
      return senderName!.trim();
    }
    if (senderEmail != null && senderEmail!.trim().isNotEmpty) {
      return senderEmail!.trim();
    }
    return 'BNX Mail';
  }

  /// Helper to format subject or fallback.
  String get formattedSubject {
    if (subject != null && subject!.trim().isNotEmpty) {
      return subject!.trim();
    }
    return 'New email';
  }

  /// Helper to format preview with length limit or fallback.
  String get formattedPreview {
    if (preview != null && preview!.trim().isNotEmpty) {
      final clean = preview!.trim();
      return clean.length > 100 ? '${clean.substring(0, 100)}...' : clean;
    }
    return 'You have received a new email.';
  }

  /// Generates a deterministic notification integer ID to prevent duplicate system notifications for the same email.
  int get deterministicNotificationId {
    final key = effectiveEmailId ?? notificationId ?? subject ?? 'default_notif';
    return (key.hashCode & 0x7FFFFFFF);
  }
}
