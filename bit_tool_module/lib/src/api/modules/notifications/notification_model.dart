import 'package:flutter/foundation.dart';

/// Strongly typed model representing a notification item.
@immutable
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? type;
  final Map<String, dynamic>? metadata;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.isRead = false,
    this.createdAt,
    this.type,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'] ?? json['notificationId'];
    final id = rawId?.toString() ?? '';

    final title = json['title']?.toString() ??
        json['subject']?.toString() ??
        json['heading']?.toString() ??
        '';

    final message = json['message']?.toString() ??
        json['body']?.toString() ??
        json['content']?.toString() ??
        '';

    final rawIsRead = json['isRead'] ?? json['read'] ?? json['is_read'];
    final isRead = rawIsRead is bool
        ? rawIsRead
        : (rawIsRead == 1 ||
            rawIsRead?.toString().toLowerCase() == 'true' ||
            json['status']?.toString().toLowerCase() == 'read');

    DateTime? createdAt;
    final rawTime = json['createdAt'] ??
        json['created_at'] ??
        json['timestamp'] ??
        json['date'];
    if (rawTime is String) {
      createdAt = DateTime.tryParse(rawTime);
    } else if (rawTime is num) {
      final intTime = rawTime.toInt();
      createdAt = intTime > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(intTime)
          : DateTime.fromMillisecondsSinceEpoch(intTime * 1000);
    }

    final type = json['type']?.toString() ?? json['category']?.toString();

    Map<String, dynamic>? metadata;
    if (json['metadata'] is Map<String, dynamic>) {
      metadata = json['metadata'] as Map<String, dynamic>;
    } else if (json['metadata'] is Map) {
      metadata = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    return NotificationModel(
      id: id,
      title: title,
      message: message,
      isRead: isRead,
      createdAt: createdAt,
      type: type,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'isRead': isRead,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (type != null) 'type': type,
    if (metadata != null) 'metadata': metadata,
  };
}

