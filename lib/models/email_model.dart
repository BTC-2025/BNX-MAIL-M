import 'attachment_model.dart';

// Sentinel so snoozeUntil can be explicitly set to null via copyWith
const _snoozeAbsent = Object();

/// Strips HTML tags from a string to produce readable plain text.
/// Used when the API returns HTML email content.
String _stripHtml(String html) {
  // Replace block-level elements with newlines for readability
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'&amp;'), '&')
      .replaceAll(RegExp(r'&lt;'), '<')
      .replaceAll(RegExp(r'&gt;'), '>')
      .replaceAll(RegExp(r'&quot;'), '"')
      .replaceAll(RegExp(r'&nbsp;'), ' ')
      .replaceAll(RegExp(r'&#39;'), "'");
  // Collapse excessive blank lines
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return text;
}

bool _looksLikeHtml(String s) => RegExp(
  r'<(html|body|div|p|span|table|br|a|b|i|u|s|strong|em|del|strike|ul|ol|li|h[1-6])\b',
  caseSensitive: false,
).hasMatch(s);

class EmailModel {
  final String id;
  final String senderName;
  final String senderEmail;
  final String recipient;
  final String subject;
  final String body;
  final String htmlBody; // raw HTML for rich rendering
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
  final bool isDateFallback;
  final List<String> labels; // names of labels (e.g., 'Work', 'Personal')
  final String? avatar;
  final List<AttachmentModel> attachments;
  final DateTime?
  snoozeUntil; // Feature 2: Snooze Scheduler — when to resurface
  final String? messageId;

  /// Tracks which API folder endpoints returned this email.
  /// Allows an email to belong to multiple folders simultaneously.
  final Set<String> memberOfFolders;
  final String? ownerEmail;

  const EmailModel({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.recipient,
    required this.subject,
    required this.body,
    this.htmlBody = '',
    required this.date,
    this.messageId,
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
    this.isDateFallback = false,
    this.labels = const [],
    this.avatar,
    this.attachments = const [],
    this.snoozeUntil,
    this.memberOfFolders = const {},
    this.ownerEmail,
  });

  /// Returns a deterministic identity key for mailbox merging across folders.
  String get canonicalKey {
    if (id.startsWith('local_')) return id;
    if (messageId != null && messageId!.trim().isNotEmpty) {
      return messageId!.trim().toLowerCase();
    }
    final cleanSender = senderEmail.trim().toLowerCase();
    final cleanRecipient = recipient.trim().toLowerCase();
    final cleanSubject = subject.trim().toLowerCase();
    final dateSec = date.millisecondsSinceEpoch ~/ 1000;
    if (cleanSender.isNotEmpty && cleanSubject.isNotEmpty && dateSec > 0) {
      return '${cleanSender}_${cleanRecipient}_${cleanSubject}_$dateSec';
    }
    final cleanId = id.replaceAll(RegExp(r'^[a-zA-Z_]+'), '');
    return cleanId.isNotEmpty ? cleanId : id;
  }

  /// Parses an email from the API JSON response.
  /// [folder] is used to tag the boolean flags when they aren't explicit in JSON.
  factory EmailModel.fromJson(
    Map<String, dynamic> json, {
    String folder = 'Inbox',
  }) {
    // Helper regex to extract clean email and name from "Name <email@domain.com>"
    String cleanAddr(String raw) {
      if (raw.contains('<') && raw.contains('>')) {
        final match = RegExp(r'<([^>]+)>').firstMatch(raw);
        if (match != null) return match.group(1)!.trim();
      }
      return raw.replaceAll('"', '').trim();
    }

    String cleanDisplayName(String raw) {
      if (raw.contains('<') && raw.contains('>')) {
        final idx = raw.indexOf('<');
        final namePart = raw.substring(0, idx).replaceAll('"', '').trim();
        if (namePart.isNotEmpty) return namePart;
        final match = RegExp(r'<([^>]+)>').firstMatch(raw);
        if (match != null) return match.group(1)!.split('@').first;
      }
      return raw.replaceAll('"', '').trim();
    }

    // ── Sender ──────────────────────────────────────────────────────────
    final fromObj = json['from'];
    String senderName = '';
    String senderEmail = '';
    if (fromObj is Map<String, dynamic>) {
      senderName =
          fromObj['name']?.toString() ??
          fromObj['displayName']?.toString() ??
          '';
      final rawAddr =
          fromObj['address']?.toString() ?? fromObj['email']?.toString() ?? '';
      senderEmail = cleanAddr(rawAddr);
      if (senderName.isEmpty && rawAddr.isNotEmpty) {
        senderName = cleanDisplayName(rawAddr);
      }
    } else if (fromObj is String) {
      senderEmail = cleanAddr(fromObj);
      senderName = cleanDisplayName(fromObj);
    }

    if (senderName.isEmpty) {
      final rawSender =
          json['senderName']?.toString() ?? json['sender']?.toString() ?? '';
      senderName = cleanDisplayName(rawSender);
    }
    if (senderName.isEmpty && senderEmail.isNotEmpty) {
      final emailPrefix = senderEmail.split('@').first.trim();
      senderName = emailPrefix.isNotEmpty
          ? emailPrefix[0].toUpperCase() + emailPrefix.substring(1)
          : senderEmail;
    }
    if (senderName.isEmpty) {
      senderName = 'BNX Mail';
    }

    // ── Recipient ────────────────────────────────────────────────────────
    final toField = json['to'];
    String recipient = '';
    if (toField is List && toField.isNotEmpty) {
      final first = toField.first;
      if (first is Map<String, dynamic>) {
        final rawTo =
            first['address']?.toString() ?? first['email']?.toString() ?? '';
        recipient = cleanAddr(rawTo);
      } else {
        recipient = cleanAddr(first.toString());
      }
    } else if (toField is String) {
      recipient = cleanAddr(toField);
    }

    // ── Body ─────────────────────────────────────────────────────────────
    final h = json['html']?.toString();
    final c = json['content']?.toString();
    final b = json['body']?.toString();
    final t = json['text']?.toString();

    // Prefer explicit 'html' field if it exists, otherwise fallback to others
    final rawHtml = (h != null && h.isNotEmpty) ? h : (c ?? b ?? t ?? '');
    final htmlBody = rawHtml;

    // For snippets, we want plain text
    final bodyStr = t ?? c ?? b ?? h ?? '';
    final bodyText = _looksLikeHtml(bodyStr) ? _stripHtml(bodyStr) : bodyStr;

    // ── Date ─────────────────────────────────────────────────────────────
    final rawDate =
        json['date'] ??
        json['createdAt'] ??
        json['created_at'] ??
        json['sentDate'] ??
        json['receivedDate'] ??
        json['lastModified'] ??
        json['last_modified'] ??
        json['updatedAt'] ??
        json['updated_at'] ??
        json['internalDate'] ??
        json['deliveryDate'] ??
        json['mailDate'] ??
        json['dateTime'] ??
        json['timestamp'] ??
        json['sentAt'] ??
        json['sent_at'] ??
        json['receivedAt'] ??
        json['received_at'] ??
        json['time'] ??
        json['starredAt'] ??
        json['starred_at'] ??
        (json['headers'] is Map
            ? (json['headers']['date'] ?? json['headers']['Date'])
            : null) ??
        (json['envelope'] is Map ? json['envelope']['date'] : null);

    DateTime date = DateTime.now();
    bool isDateFallback = true;

    if (rawDate != null) {
      if (rawDate is DateTime) {
        date = rawDate.isUtc ? rawDate.toLocal() : rawDate;
        isDateFallback = false;
      } else {
        var str = rawDate.toString().trim();
        final numVal = int.tryParse(str);
        if (numVal != null) {
          if (str.length == 10) {
            date = DateTime.fromMillisecondsSinceEpoch(
              numVal * 1000,
              isUtc: true,
            ).toLocal();
            isDateFallback = false;
          } else if (str.length >= 13) {
            date = DateTime.fromMillisecondsSinceEpoch(
              numVal,
              isUtc: true,
            ).toLocal();
            isDateFallback = false;
          }
        } else {
          // If string looks like ISO/SQL date format (e.g. "2026-07-22 04:07:00" or "2026-07-22T04:07:00")
          // without timezone specifier ('Z' or '+'), append 'Z' so it is correctly parsed as UTC
          if (RegExp(
            r'^\d{4}-\d{2}-\d{2}[\sT]\d{2}:\d{2}(:\d{2}(\.\d+)?)?$',
          ).hasMatch(str)) {
            str = '${str.replaceAll(' ', 'T')}Z';
          }
          final parsedIso = DateTime.tryParse(str);
          if (parsedIso != null) {
            date = parsedIso.toLocal();
            isDateFallback = false;
          } else {
            // Parse RFC 2822 date formats (e.g. "Tue, 21 Jul 2026 11:40:00 +0000")
            try {
              final cleaned = str.replaceFirst(RegExp(r'^[A-Za-z]+,\s*'), '');
              final parts = cleaned.split(RegExp(r'\s+'));
              if (parts.length >= 4) {
                final day = int.tryParse(parts[0]);
                const monthMap = {
                  'jan': 1,
                  'feb': 2,
                  'mar': 3,
                  'apr': 4,
                  'may': 5,
                  'jun': 6,
                  'jul': 7,
                  'aug': 8,
                  'sep': 9,
                  'oct': 10,
                  'nov': 11,
                  'dec': 12,
                };
                final month = monthMap[parts[1].toLowerCase()];
                final year = int.tryParse(parts[2]);
                if (day != null && month != null && year != null) {
                  int hour = 0, min = 0, sec = 0;
                  if (parts[3].contains(':')) {
                    final tParts = parts[3].split(':');
                    hour = int.tryParse(tParts[0]) ?? 0;
                    min = tParts.length > 1
                        ? (int.tryParse(tParts[1]) ?? 0)
                        : 0;
                    sec = tParts.length > 2
                        ? (int.tryParse(tParts[2]) ?? 0)
                        : 0;
                  }
                  date = DateTime.utc(
                    year,
                    month,
                    day,
                    hour,
                    min,
                    sec,
                  ).toLocal();
                  isDateFallback = false;
                }
              }
            } catch (_) {}
          }
        }
      }
    }

    // ── Flags ─────────────────────────────────────────────────────────────
    bool isRead = false;
    bool isStarred = false;
    bool isSnoozed = false;

    final rawFlags = json['flags'];
    if (rawFlags is Map) {
      isRead = rawFlags['seen'] == true || rawFlags['\\Seen'] == true;
      isStarred =
          rawFlags['flagged'] == true ||
          rawFlags['\\Flagged'] == true ||
          rawFlags['starred'] == true;
      isSnoozed = rawFlags['snoozed'] == true;
    } else if (rawFlags is List) {
      for (final f in rawFlags) {
        final str = f.toString().toLowerCase();
        if (str.contains('seen')) isRead = true;
        if (str.contains('flagged') || str.contains('star')) isStarred = true;
        if (str.contains('snooze')) isSnoozed = true;
      }
    }

    if (json['isRead'] is bool) isRead = json['isRead'] as bool;
    if (json['read'] is bool) isRead = json['read'] as bool;
    if (json['isStarred'] is bool) isStarred = json['isStarred'] as bool;
    if (json['starred'] is bool) isStarred = json['starred'] as bool;
    if (folder == 'Starred') isStarred = true;
    if (json['isSnoozed'] is bool) isSnoozed = json['isSnoozed'] as bool;
    if (folder == 'Snoozed') isSnoozed = true;

    // Folder classification: the `folder` parameter from fetchFolder() is the
    // primary classification, but we enforce mutual exclusivity so that trashed
    // emails never remain tagged as active Drafts/Sent/etc.
    final bool isTrash =
        (folder == 'Trash') ||
        (json['isTrash'] == true) ||
        (json['folderName']?.toString().toLowerCase() == 'trash') ||
        (json['folder']?.toString().toLowerCase() == 'trash');

    final bool isArchive =
        !isTrash &&
        ((folder == 'Archive') ||
            (json['isArchive'] == true) ||
            (json['folderName']?.toString().toLowerCase() == 'archive') ||
            (json['folder']?.toString().toLowerCase() == 'archive'));

    final bool isSpam =
        !isTrash &&
        !isArchive &&
        ((folder == 'Spam') ||
            (json['isSpam'] == true) ||
            (json['folderName']?.toString().toLowerCase() == 'spam') ||
            (json['folder']?.toString().toLowerCase() == 'spam'));

    final bool isScheduled =
        !isTrash &&
        ((folder == 'Scheduled') ||
            (json['isScheduled'] == true) ||
            (json['status']?.toString().toUpperCase() == 'SCHEDULED') ||
            (json['folderName']?.toString().toLowerCase() == 'scheduled') ||
            (json['folder']?.toString().toLowerCase() == 'scheduled') ||
            (json['scheduledAt'] != null &&
                json['scheduledAt'].toString().isNotEmpty &&
                folder != 'Sent') ||
            (json['sendAt'] != null &&
                json['sendAt'].toString().isNotEmpty &&
                folder != 'Sent'));

    final bool isSent =
        !isTrash &&
        !isArchive &&
        !isSpam &&
        !isScheduled &&
        (folder != 'Inbox') &&
        ((folder == 'Sent') ||
            (json['status']?.toString().toUpperCase() == 'SENT' &&
                folder == 'Sent') ||
            (json['isSent'] == true && folder != 'Inbox'));

    final bool isDraft =
        !isTrash &&
        !isArchive &&
        !isSpam &&
        !isScheduled &&
        ((folder == 'Draft') ||
            (json['status']?.toString().toUpperCase() == 'DRAFT') ||
            (json['isDraft'] == true) ||
            (json['folderName']?.toString().toLowerCase() == 'draft') ||
            (json['folder']?.toString().toLowerCase() == 'draft'));

    // ── Attachments ───────────────────────────────────────────────────────
    final rawAttachments =
        json['attachments'] as List<dynamic>? ??
        json['attachmentList'] as List<dynamic>? ??
        json['files'] as List<dynamic>? ??
        json['fileList'] as List<dynamic>? ??
        json['attachedFiles'] as List<dynamic>? ??
        json['parts'] as List<dynamic>? ??
        json['media'] as List<dynamic>? ??
        [];

    final List<AttachmentModel> attachments = [];
    for (final item in rawAttachments) {
      if (item is Map<String, dynamic>) {
        attachments.add(AttachmentModel.fromJson(item));
      } else if (item != null) {
        final str = item.toString();
        final name = str.split('/').last.split('\\').last;
        attachments.add(
          AttachmentModel(
            fileName: name.isNotEmpty ? name : 'attachment',
            fileType: name.toLowerCase().endsWith('.pdf')
                ? 'PDF'
                : (name.toLowerCase().contains('.png') ||
                          name.toLowerCase().contains('.jpg') ||
                          name.toLowerCase().contains('.jpeg')
                      ? 'IMG'
                      : 'FILE'),
            fileSize: 'Attachment',
            filePath: str,
          ),
        );
      }
    }

    // ── Labels ────────────────────────────────────────────────────────────
    final rawLabels = json['labels'] as List<dynamic>? ?? [];
    final labels = rawLabels
        .map((l) {
          if (l is Map) return l['name']?.toString() ?? '';
          return l.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList();

    // ── Snooze ────────────────────────────────────────────────────────────
    DateTime? snoozeUntil;
    final rawSnooze = json['snoozeUntil'] ?? json['snoozedUntil'];
    if (rawSnooze != null) {
      snoozeUntil = DateTime.tryParse(rawSnooze.toString());
    }

    // ── ID (must be non-empty & unique across all folders) ────────────────
    final globalMsgId = json['messageId']?.toString();
    final rawUid = json['uid']?.toString() ??
        json['id']?.toString() ??
        json['_id']?.toString();

    // The backend /api/mail/email/{uid} and /api/mail/star/{uid} strictly expect the numeric database UID.
    // RFC 822 Message-ID (e.g. CA+Eqy... or UUIDs) cannot be passed to /api/mail/email/{uid} without causing HTTP 500 NumberFormatException.
    final rawId = (rawUid != null && rawUid.trim().isNotEmpty)
        ? rawUid.trim()
        : (globalMsgId?.trim() ?? '');

    String effectiveId = rawId;
    if (effectiveId.isEmpty) {
      effectiveId = '${senderEmail}_${json['subject']}_$rawDate'.hashCode
          .abs()
          .toString();
    }

    return EmailModel(
      id: effectiveId,
      messageId: globalMsgId,
      senderName: senderName,
      senderEmail: senderEmail,
      recipient: recipient,
      subject: json['subject']?.toString() ?? '(No Subject)',
      body: bodyText,
      htmlBody: htmlBody,
      date: date,
      isRead: (isDraft || folder == 'Draft') ? true : isRead,
      isStarred: isStarred,
      isSnoozed: isSnoozed,
      isDraft: isDraft,
      isTrash: isTrash,
      isSent: isSent,
      isArchive: isArchive,
      isSpam: isSpam,
      isScheduled: isScheduled,
      hasAttachment:
          attachments.isNotEmpty || (json['hasAttachment'] as bool? ?? false),
      isDateFallback: isDateFallback,
      labels: labels,
      avatar: json['avatar']?.toString(),
      attachments: attachments,
      snoozeUntil: snoozeUntil,
      memberOfFolders: {
        folder,
        if (isStarred || folder == 'Starred') 'Starred',
        if (isDraft && !isTrash) 'Draft',
        if (isSent && !isTrash) 'Sent',
        if (isTrash) 'Trash',
        if (isArchive && !isTrash) 'Archive',
        if (isSpam && !isTrash) 'Spam',
      },
      ownerEmail:
          json['ownerEmail']?.toString() ?? json['accountEmail']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': id,
    'messageId': messageId,
    'senderName': senderName,
    'senderEmail': senderEmail,
    'recipient': recipient,
    'subject': subject,
    'body': body,
    'htmlBody': htmlBody,
    'date': date.toIso8601String(),
    'isRead': isRead,
    'isStarred': isStarred,
    'isSnoozed': isSnoozed,
    'isDraft': isDraft,
    'isTrash': isTrash,
    'isSent': isSent,
    'isArchive': isArchive,
    'isSpam': isSpam,
    'isScheduled': isScheduled,
    if (ownerEmail != null) 'ownerEmail': ownerEmail,
  };

  EmailModel copyWith({
    String? id,
    String? messageId,
    String? senderName,
    String? senderEmail,
    String? recipient,
    String? subject,
    String? body,
    String? htmlBody,
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
    bool? isDateFallback,
    List<String>? labels,
    String? avatar,
    List<AttachmentModel>? attachments,
    Object? snoozeUntil = _snoozeAbsent,
    Set<String>? memberOfFolders,
    String? ownerEmail,
  }) {
    return EmailModel(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      recipient: recipient ?? this.recipient,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      htmlBody: htmlBody ?? this.htmlBody,
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
      isDateFallback: isDateFallback ?? this.isDateFallback,
      labels: labels ?? this.labels,
      avatar: avatar ?? this.avatar,
      attachments: attachments ?? this.attachments,
      snoozeUntil: identical(snoozeUntil, _snoozeAbsent)
          ? this.snoozeUntil
          : snoozeUntil as DateTime?,
      memberOfFolders: memberOfFolders ?? this.memberOfFolders,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}
