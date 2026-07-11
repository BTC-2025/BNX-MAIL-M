import 'attachment_model.dart';

// Sentinel so snoozeUntil can be explicitly set to null via copyWith
const _snoozeAbsent = Object();

class EmailModel {
  final String id;
  final String senderName;
  final String senderEmail;
  final String recipient;
  final String subject;
  final String body;
  final DateTime date;
  final bool isRead;
  final bool isStarred;
  final bool isSnoozed;
  final bool isDraft;
  final bool isTrash;
  final bool isSent;
  final bool isArchive;
  final bool isSpam;
  final bool isScheduled;
  final bool hasAttachment;
  final List<String> labels; // names of labels (e.g., 'Work', 'Personal')
  final String? avatar;
  final List<AttachmentModel> attachments;
  final DateTime? snoozeUntil; // Feature 2: Snooze Scheduler — when to resurface

  const EmailModel({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.recipient,
    required this.subject,
    required this.body,
    required this.date,
    this.isRead = false,
    this.isStarred = false,
    this.isSnoozed = false,
    this.isDraft = false,
    this.isTrash = false,
    this.isSent = false,
    this.isArchive = false,
    this.isSpam = false,
    this.isScheduled = false,
    this.hasAttachment = false,
    this.labels = const [],
    this.avatar,
    this.attachments = const [],
    this.snoozeUntil,
  });

  EmailModel copyWith({
    String? id,
    String? senderName,
    String? senderEmail,
    String? recipient,
    String? subject,
    String? body,
    DateTime? date,
    bool? isRead,
    bool? isStarred,
    bool? isSnoozed,
    bool? isDraft,
    bool? isTrash,
    bool? isSent,
    bool? isArchive,
    bool? isSpam,
    bool? isScheduled,
    bool? hasAttachment,
    List<String>? labels,
    String? avatar,
    List<AttachmentModel>? attachments,
    Object? snoozeUntil = _snoozeAbsent,
  }) {
    return EmailModel(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      recipient: recipient ?? this.recipient,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      isDraft: isDraft ?? this.isDraft,
      isTrash: isTrash ?? this.isTrash,
      isSent: isSent ?? this.isSent,
      isArchive: isArchive ?? this.isArchive,
      isSpam: isSpam ?? this.isSpam,
      isScheduled: isScheduled ?? this.isScheduled,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      labels: labels ?? this.labels,
      avatar: avatar ?? this.avatar,
      attachments: attachments ?? this.attachments,
      snoozeUntil: identical(snoozeUntil, _snoozeAbsent)
          ? this.snoozeUntil
          : snoozeUntil as DateTime?,
    );
  }
}
