import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../models/email_model.dart';
import '../../models/attachment_model.dart';

/// Maps sidebar folder names to API endpoint paths.
const Map<String, String> _folderPaths = {
  'Inbox': '/api/mail/inbox',
  'Sent': '/api/mail/sent',
  'Draft': '/api/mail/drafts',
  'Starred': '/api/mail/starred',
  'Trash': '/api/mail/trash',
  'Spam': '/api/mail/spam',
  'Snoozed': '/api/mail/snoozed',
  'Archive': '/api/mail/archive',
  'Scheduled': '/api/mail/scheduled',
  'All Mail': '/api/mail/inbox',
  'Unread': '/api/mail/unread',
  'Important': '/api/mail/important',
};

/// Handles all email-related API calls.
class MailRepository {
  static final Map<String, int> serverFolderCounts = {};

  static const Set<String> nonMailFolders = {
    'Storage',
    'Casbox',
    'Chat',
    'Colab',
    'Settings',
    'Help',
    'Templates',
    'Subscriptions',
  };
  static String cleanUid(String uid) {
    if (uid.startsWith('local_')) return uid;
    if (uid.contains('_')) {
      final parts = uid.split('_');
      if (parts.length >= 2 &&
          const [
            'Draft',
            'Sent',
            'Trash',
            'Archive',
            'Spam',
            'Inbox',
            'Starred',
            'Snoozed',
            'Scheduled',
            'Unread',
            'Important',
          ].contains(parts[0])) {
        return parts.sublist(1).join('_');
      }
    }
    return uid;
  }

  // ── Fetch Folder ─────────────────────────────────────────────────────────

  static final Map<String, Future<List<EmailModel>>> _inFlightFetches = {};

  static List<dynamic>? _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      final listKeys = [
        'emails',
        'messages',
        'items',
        'content',
        'data',
        'list',
        'mailboxes',
        'drafts',
      ];
      for (final key in listKeys) {
        if (json.containsKey(key)) {
          final val = json[key];
          if (val is List) return val;
          if (val is Map) {
            final nested = _extractList(val);
            if (nested is List) return nested;
          }
        }
      }
      for (final val in json.values) {
        if (val is List) return val;
        if (val is Map) {
          final nested = _extractList(val);
          if (nested is List) return nested;
        }
      }
    }
    return null;
  }

  /// Fetches emails for a given [folder]. Defaults to 50 items.
  static Future<List<EmailModel>> fetchFolder(
    String folder, {
    int limit = 50,
  }) async {
    if (nonMailFolders.contains(folder)) {
      return [];
    }
    final key = '$folder-$limit';
    if (_inFlightFetches.containsKey(key)) {
      print('[STAGE 1: DEDUP] Reusing in-flight request for $key');
      return _inFlightFetches[key]!;
    }
    final future = _fetchFolderInternal(folder, limit: limit);
    _inFlightFetches[key] = future;
    try {
      return await future;
    } finally {
      _inFlightFetches.remove(key);
    }
  }

  static Future<List<EmailModel>> _fetchFolderInternal(
    String folder, {
    int limit = 50,
  }) async {
    final path = _folderPaths[folder] ?? '/api/mail/inbox';
    dynamic res;

    final candidates = <Map<String, dynamic>>[
      {
        'path': path,
        'queryParams': {'limit': '$limit'},
      },
      {'path': path, 'queryParams': null},
    ];

    if (folder == 'Draft') {
      candidates.add({
        'path': '/api/mail/draft',
        'queryParams': {'limit': '$limit'},
      });
      candidates.add({'path': '/api/mail/draft', 'queryParams': null});
    } else if (folder == 'Scheduled') {
      candidates.add({
        'path': '/api/mail/schedule',
        'queryParams': {'limit': '$limit'},
      });
      candidates.add({'path': '/api/mail/schedule', 'queryParams': null});
      candidates.add({
        'path': '/api/mail/scheduled-emails',
        'queryParams': null,
      });
    } else if (folder == 'Archive') {
      candidates.add({
        'path': '/api/mail/archived',
        'queryParams': {'limit': '$limit'},
      });
      candidates.add({'path': '/api/mail/archived', 'queryParams': null});
    }

    for (final candidate in candidates) {
      try {
        final candPath = candidate['path'] as String;
        final candParams = candidate['queryParams'] as Map<String, String>?;
        res = await ApiClient.get(candPath, queryParams: candParams);
        final list = _extractList(res);
        if (list != null) {
          print(
            '[DIAGNOSTIC] fetchFolder($folder) succeeded with path "$candPath"',
          );
          break;
        }
      } catch (e) {
        print(
          '[DIAGNOSTIC WARNING] Folder "$folder" candidate path "${candidate['path']}" failed: $e',
        );
      }
    }

    if (res == null) {
      return [];
    }

    if (res is Map) {
      final dataObj = res['data'];
      if (dataObj is Map && dataObj['totalCount'] != null) {
        final tc = int.tryParse(dataObj['totalCount'].toString());
        if (tc != null) {
          serverFolderCounts[folder] = tc;
        }
      } else if (res['totalCount'] != null) {
        final tc = int.tryParse(res['totalCount'].toString());
        if (tc != null) {
          serverFolderCounts[folder] = tc;
        }
      }
    }

    var rawList = _extractList(res);
    if (rawList == null) {
      return [];
    }

    final rawCount = rawList.length;
    print(
      '[STAGE 1: BACKEND API] Endpoint "$path" for folder "$folder" returned $rawCount raw items.',
    );

    final parsedEmails = <EmailModel>[];
    for (final item in rawList) {
      if (item is Map) {
        try {
          final jsonMap = Map<String, dynamic>.from(item);
          final email = EmailModel.fromJson(jsonMap, folder: folder);
          if (folder != 'Inbox' ||
              !email.labels.any((l) => l.toLowerCase() == 'casbox')) {
            parsedEmails.add(email);
          }
        } catch (e) {
          print('[PARSE WARNING] Folder "$folder" failed to parse item: $e');
        }
      }
    }

    print(
      '[STAGE 3: REPOSITORY RESULT] Folder "$folder" parsed ${parsedEmails.length} items (after excluding Casbox).',
    );
    return parsedEmails;
  }

  /// Fetches emails for a given [folder] using an explicit [accessToken] for All Inboxes workflow.
  static Future<List<EmailModel>> fetchFolderWithToken(
    String accessToken,
    String folder, {
    int limit = 50,
    String? ownerEmail,
  }) async {
    if (nonMailFolders.contains(folder)) {
      return [];
    }
    final path = _folderPaths[folder] ?? '/api/mail/inbox';
    dynamic res;
    final candidates = <Map<String, dynamic>>[
      {
        'path': path,
        'queryParams': {'limit': '$limit'},
      },
      {'path': path, 'queryParams': null},
    ];

    for (final candidate in candidates) {
      try {
        final candPath = candidate['path'] as String;
        final candParams = candidate['queryParams'] as Map<String, String>?;
        res = await ApiClient.get(
          candPath,
          queryParams: candParams,
          tempToken: accessToken,
        );
        final list = _extractList(res);
        if (list != null) break;
      } catch (e) {
        print(
          '[ALL INBOXES FETCH WARNING] Candidate "${candidate['path']}" failed: $e',
        );
      }
    }

    if (res == null) return [];
    var rawList = _extractList(res);
    if (rawList == null) return [];

    final list = <EmailModel>[];
    for (final item in rawList) {
      if (item is Map) {
        try {
          final jsonMap = Map<String, dynamic>.from(item);
          final model = EmailModel.fromJson(jsonMap, folder: folder);
          final finalModel = ownerEmail != null && ownerEmail.isNotEmpty
              ? model.copyWith(ownerEmail: ownerEmail)
              : model;
          if (folder != 'Inbox' ||
              !finalModel.labels.any((l) => l.toLowerCase() == 'casbox')) {
            list.add(finalModel);
          }
        } catch (_) {}
      }
    }
    return list;
  }

  // ── Fetch Single Email ────────────────────────────────────────────────────

  static Future<EmailModel?> fetchEmail(
    String uid, {
    String folder = 'Inbox',
    String? tempToken,
  }) async {
    final cleanId = cleanUid(uid);
    // If cleanId is an RFC 822 Message-ID (contains '@' or non-numeric header), avoid calling
    // /api/mail/email/$cleanId which expects a numeric database UID and returns HTTP 500.
    if (cleanId.contains('@') ||
        (cleanId.length > 20 && int.tryParse(cleanId) == null)) {
      print(
        '[FETCH EMAIL WARNING] Skipping /api/mail/email/$cleanId because ID is not numeric: $cleanId',
      );
      return null;
    }
    try {
      dynamic res;
      try {
        res = await ApiClient.get(
          '/api/mail/email/$cleanId',
          queryParams: {'folder': folder},
          tempToken: tempToken,
        );
      } catch (_) {
        res = await ApiClient.get(
          '/api/mail/email/$cleanId',
          tempToken: tempToken,
        );
      }
      final data = res is Map<String, dynamic>
          ? (res['data'] as Map<String, dynamic>? ?? res)
          : <String, dynamic>{};
      print('[FETCH EMAIL SUCCESS] $cleanId returned keys: ${data.keys.toList()}');
      return EmailModel.fromJson(data, folder: folder);
    } catch (e) {
      print('[FETCH EMAIL ERROR] /api/mail/email/$cleanId failed: $e');
      return null;
    }
  }

  // ── Send Email ────────────────────────────────────────────────────────────

  static Future<void> sendEmail({
    required String to,
    String? cc,
    String? bcc,
    required String subject,
    required String content,
    bool isHtml = false,
    List<AttachmentModel> attachments = const [],
  }) async {
    final hasLocalFiles = attachments.any((a) => a.filePath != null);

    if (hasLocalFiles) {
      // 1. Create draft
      final body = <String, dynamic>{
        'to': to,
        'subject': subject,
        'content': content,
        'body': content,
        'isHtml': isHtml,
        'attachments': const [],
      };
      if (cc != null && cc.isNotEmpty) body['cc'] = cc;
      if (bcc != null && bcc.isNotEmpty) body['bcc'] = bcc;

      final res = await ApiClient.post('/api/mail/drafts', body: body);
      final draftId =
          (res['uid'] ?? res['id'] ?? res['data']?['id'] ?? res['data']?['uid'])
              ?.toString();
      if (draftId == null) {
        throw const ApiException(
          statusCode: 500,
          message: 'Could not create draft for attachment upload',
        );
      }

      // 2. Upload each local file
      for (final file in attachments) {
        if (file.filePath != null) {
          await ApiClient.uploadAttachment(draftId, file.filePath!);
        }
      }

      // 3. Send the draft
      await ApiClient.post('/api/mail/drafts/$draftId/send');
    } else {
      // Direct send
      final body = <String, dynamic>{
        'to': to,
        'subject': subject,
        'content': content,
        'body': content,
        'isHtml': isHtml,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };
      if (cc != null && cc.isNotEmpty) body['cc'] = cc;
      if (bcc != null && bcc.isNotEmpty) body['bcc'] = bcc;

      await ApiClient.post('/api/mail/send', body: body);
    }
  }

  // ── Save Draft ────────────────────────────────────────────────────────────

  static Future<void> saveDraft({
    required String to,
    required String subject,
    required String content,
    String? cc,
    String? bcc,
  }) async {
    final body = <String, dynamic>{
      'to': to,
      'subject': subject,
      'content': content,
      'body': content, // Send both body and content
    };
    if (cc != null && cc.isNotEmpty) body['cc'] = cc;
    if (bcc != null && bcc.isNotEmpty) body['bcc'] = bcc;

    await ApiClient.post('/api/mail/drafts', body: body);
  }

  static Future<void> sendDraft(String draftId) async {
    final cleanId = cleanUid(draftId);
    await ApiClient.post('/api/mail/drafts/$cleanId/send');
  }

  static Future<void> uploadDraftAttachment(
    String draftId,
    String filePath,
  ) async {
    final cleanId = cleanUid(draftId);
    await ApiClient.uploadAttachment(cleanId, filePath);
  }

  static Future<void> removeDraftAttachment(
    String draftId,
    String fileName,
  ) async {
    final cleanId = cleanUid(draftId);
    await ApiClient.delete('/api/mail/drafts/$cleanId/attachments/$fileName');
  }

  // ── Mark Read / Unread ────────────────────────────────────────────────────

  static Future<void> markRead(
    String uid,
    String folder, {
    String? tempToken,
  }) async {
    final cleanId = cleanUid(uid);
    try {
      await ApiClient.post('/api/mail/read/$cleanId', tempToken: tempToken);
    } catch (e) {
      print('[MARK READ WARNING] Failed to mark email $cleanId as read: $e');
    }
  }

  static Future<void> markUnread(
    String uid,
    String folder, {
    String? tempToken,
  }) async {
    final cleanId = cleanUid(uid);
    try {
      await ApiClient.post('/api/mail/unread/$cleanId', tempToken: tempToken);
    } catch (e) {
      print('[MARK UNREAD WARNING] Failed to mark email $cleanId as unread: $e');
    }
  }

  // ── Star / Unstar ─────────────────────────────────────────────────────────

  static Future<void> toggleStar(String uid, String folder) async {
    final cleanId = cleanUid(uid);
    await ApiClient.post(
      '/api/mail/star/$cleanId',
      queryParams: {'folder': folder},
    );
  }

  // ── Trash / Restore ───────────────────────────────────────────────────────

  static Future<void> trashEmail(String uid, String folder) async {
    final cleanId = cleanUid(uid);
    if (folder == 'Draft' || folder.toLowerCase() == 'draft') {
      print('[TRASH DRAFT] Executing draft deletion for ID: $cleanId');
      try {
        await ApiClient.delete('/api/mail/drafts/$cleanId');
      } catch (e) {
        print(
          '[TRASH DRAFT WARNING] DELETE /api/mail/drafts/$cleanId failed: $e',
        );
      }
      try {
        await ApiClient.post(
          '/api/mail/trash/$cleanId',
          queryParams: {'folder': 'Draft'},
        );
      } catch (_) {}
    } else {
      await ApiClient.post(
        '/api/mail/trash/$cleanId',
        queryParams: {'folder': folder},
      );
    }
  }

  static Future<void> restoreFromTrash(String uid) async {
    final cleanId = cleanUid(uid);
    try {
      await ApiClient.post('/api/mail/restore/$cleanId');
    } catch (_) {
      try {
        await ApiClient.post('/api/mail/unarchive/$cleanId');
      } catch (_) {}
    }
  }

  static Future<void> permanentDelete(
    String uid, {
    String folder = 'Trash',
  }) async {
    await permanentlyDeleteEmail(uid, folder: folder);
  }

  static Future<void> permanentlyDeleteEmail(
    String uid, {
    String folder = 'Trash',
  }) async {
    final cleanId = cleanUid(uid);

    if (folder == 'Draft' || folder.toLowerCase() == 'draft') {
      try {
        await ApiClient.delete('/api/mail/drafts/$cleanId');
        print(
          '[PERMANENT DELETE SUCCESS] Draft deleted: DELETE /api/mail/drafts/$cleanId',
        );
        return;
      } catch (e) {
        print(
          '[PERMANENT DELETE DRAFT FAILED] DELETE /api/mail/drafts/$cleanId failed: $e',
        );
      }
    }

    // Attempt 1: DELETE with ?folder=Trash (or specified folder)
    try {
      await ApiClient.delete(
        '/api/mail/permanent/$cleanId',
        queryParams: {'folder': folder},
      );
      print(
        '[PERMANENT DELETE SUCCESS] Candidate 1: DELETE /api/mail/permanent/$cleanId?folder=$folder',
      );
      return;
    } catch (e1) {
      print('[PERMANENT DELETE CANDIDATE 1 FAILED] $e1');
    }

    // Attempt 2: DELETE with ?folder=Trash explicitly
    if (folder != 'Trash') {
      try {
        await ApiClient.delete(
          '/api/mail/permanent/$cleanId',
          queryParams: {'folder': 'Trash'},
        );
        print(
          '[PERMANENT DELETE SUCCESS] Candidate 2: DELETE /api/mail/permanent/$cleanId?folder=Trash',
        );
        return;
      } catch (e2) {
        print('[PERMANENT DELETE CANDIDATE 2 FAILED] $e2');
      }
    }

    // Attempt 3: DELETE /api/mail/permanent/{cleanId} without params
    try {
      await ApiClient.delete('/api/mail/permanent/$cleanId');
      print(
        '[PERMANENT DELETE SUCCESS] Candidate 3: DELETE /api/mail/permanent/$cleanId',
      );
      return;
    } catch (e3) {
      print('[PERMANENT DELETE CANDIDATE 3 FAILED] $e3');
    }

    // Attempt 4: POST /api/mail/permanent/{cleanId}
    try {
      await ApiClient.post(
        '/api/mail/permanent/$cleanId',
        queryParams: {'folder': folder},
      );
      print(
        '[PERMANENT DELETE SUCCESS] Candidate 4: POST /api/mail/permanent/$cleanId?folder=$folder',
      );
      return;
    } catch (e4) {
      print('[PERMANENT DELETE CANDIDATE 4 FAILED] $e4');
    }
  }

  // ── Archive ───────────────────────────────────────────────────────────────

  static Future<void> archiveEmail(String uid, String folder) async {
    final cleanId = cleanUid(uid);
    await ApiClient.post(
      '/api/mail/archive/$cleanId',
      queryParams: {'folder': folder},
    );
  }

  static Future<void> unarchiveEmail(String uid) async {
    final cleanId = cleanUid(uid);
    try {
      await ApiClient.post('/api/mail/unarchive/$cleanId');
    } catch (e) {
      print('[ARCHIVE ERROR] unarchiveEmail failed for $cleanId: $e');
      try {
        await ApiClient.post('/api/mail/restore/$cleanId');
      } catch (_) {}
    }
  }

  // ── Spam ─────────────────────────────────────────────────────────────────

  static Future<void> markSpam(String uid, String folder) async {
    final cleanId = cleanUid(uid);
    await ApiClient.post(
      '/api/mail/spam/$cleanId',
      queryParams: {'folder': folder},
    );
  }

  static Future<void> restoreFromSpam(String uid) async {
    final cleanId = cleanUid(uid);
    await ApiClient.post('/api/mail/restore-spam/$cleanId');
  }

  // ── Snooze ────────────────────────────────────────────────────────────────

  static Future<void> snoozeEmail(
    String uid,
    DateTime wakeUpAt,
    String folder,
  ) async {
    final cleanId = cleanUid(uid);
    await ApiClient.post(
      '/api/mail/snooze/$cleanId',
      queryParams: {'wakeUpAt': wakeUpAt.toIso8601String()},
    );
  }

  static Future<void> unsnoozeEmail(String uid) async {
    final cleanId = cleanUid(uid);
    await ApiClient.post('/api/mail/unsnooze/$cleanId');
  }

  // ── Labels ────────────────────────────────────────────────────────────────

  static Future<void> applyLabel(
    String uid,
    String labelId,
    String folder,
  ) async {
    final cleanId = cleanUid(uid);
    await ApiClient.post(
      '/api/mail/labels/apply/$cleanId',
      queryParams: {'labelId': labelId, 'folder': folder},
    );
  }

  static Future<void> removeLabel(
    String uid,
    String labelId,
    String folder,
  ) async {
    final cleanId = cleanUid(uid);
    await ApiClient.delete(
      '/api/mail/labels/remove/$cleanId',
      queryParams: {'labelId': labelId, 'folder': folder},
    );
  }

  static Future<void> scheduleEmail({
    required String to,
    required String subject,
    required String content,
    required DateTime scheduledAt,
    String? cc,
    String? bcc,
    List<AttachmentModel> attachments = const [],
  }) async {
    final body = <String, dynamic>{
      'to': to,
      'subject': subject,
      'content': content,
      'body': content,
      'sendAt': scheduledAt.toIso8601String(),
      'scheduledAt': scheduledAt.toIso8601String(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
    if (cc != null && cc.isNotEmpty) body['cc'] = cc;
    if (bcc != null && bcc.isNotEmpty) body['bcc'] = bcc;

    try {
      await ApiClient.post(
        '/api/mail/schedule',
        queryParams: {'sendAt': scheduledAt.toIso8601String()},
        body: body,
      );
    } catch (e) {
      try {
        await ApiClient.post(
          '/api/mail/scheduled',
          queryParams: {'sendAt': scheduledAt.toIso8601String()},
          body: body,
        );
      } catch (_) {}
    }
  }

  /// Fetches mail analytics metrics from GET /api/mail/analytics?timezone={timezone}
  static Future<Map<String, dynamic>?> fetchAnalytics() async {
    try {
      final tz = Uri.encodeComponent(
        DateTime.now().timeZoneName.isNotEmpty
            ? DateTime.now().timeZoneName
            : 'UTC',
      );
      final res = await ApiClient.get(
        '/api/mail/analytics',
        queryParams: {'timezone': tz},
      );
      final data = res['data'] as Map<String, dynamic>? ?? res;
      return data;
    } catch (e) {
      print('[ANALYTICS API WARNING] GET /api/mail/analytics failed: $e');
      return null;
    }
  }
}
