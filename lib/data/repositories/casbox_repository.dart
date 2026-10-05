import 'dart:convert';
import '../../models/attachment_model.dart';
import '../../core/network/api_client.dart';
import '../colab_provider.dart';

class CasboxRepository {
  static List<dynamic>? _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      final listKeys = [
        'emails', 'messages', 'threads', 'items', 'content', 'data',
        'list', 'mailboxes', 'tickets', 'conversations', 'casbox',
        'casboxMessages', 'results', 'payload'
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

  static List<CasboxMessage> _parseMessagesFromResponse(dynamic res) {
    final rawList = _extractList(res);
    if (rawList == null) return [];

    final result = <CasboxMessage>[];
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        final innerMessages = item['messages'] ?? item['threadMessages'] ?? item['chatMessages'];
        if (innerMessages is List && innerMessages.isNotEmpty) {
          final contactEmail = item['contactEmail']?.toString() ??
              item['sender']?.toString() ??
              item['email']?.toString() ??
              item['senderEmail']?.toString() ??
              '';
          final status = item['status']?.toString() ?? 'SENT';
          final threadId = item['id']?.toString() ?? item['threadId']?.toString() ?? '';

          for (final msg in innerMessages) {
            if (msg is Map<String, dynamic>) {
              result.add(CasboxMessage.fromJson({
                ...msg,
                if (!msg.containsKey('contactEmail') && contactEmail.isNotEmpty)
                  'contactEmail': contactEmail,
                if (!msg.containsKey('status')) 'status': status,
                if (!msg.containsKey('threadId') && threadId.isNotEmpty)
                  'threadId': threadId,
              }));
            }
          }
        } else {
          result.add(CasboxMessage.fromJson(item));
        }
      }
    }
    return result;
  }

  /// 2.3 Get All User Messages: GET /api/casbox
  /// Retrieves all Casbox messages involving authenticated user, sorted timestamp DESC.
  static Future<List<CasboxMessage>> fetchCasbox() async {
    dynamic res;
    final candidateEndpoints = [
      '/api/casbox',
      '/api/casbox/',
      '/api/casbox/threads',
      '/api/casbox/messages',
      '/api/mail/casbox',
    ];
    for (final path in candidateEndpoints) {
      try {
        res = await ApiClient.get(path);
        break;
      } catch (e) {
        print('[CASBOX REPO] GET "$path" attempt error: $e');
      }
    }

    if (res != null) {
      final parsed = _parseMessagesFromResponse(res);
      return parsed;
    }

    return [];
  }

  /// 2.2 Get Conversation Thread: GET /api/casbox/thread/{contactEmail}
  /// Retrieves historical messages between user and counterpart sorted timestamp ASC.
  static Future<List<CasboxMessage>> fetchThread(String contactEmail) async {
    final cleanContact = contactEmail.trim();
    if (cleanContact.isEmpty) return [];

    final encoded = Uri.encodeComponent(cleanContact);
    dynamic res;
    final candidateEndpoints = [
      '/api/casbox/thread/$encoded',
      '/api/casbox/thread/$cleanContact',
      '/api/casbox/$encoded',
      '/api/mail/casbox/thread/$encoded',
    ];
    for (final path in candidateEndpoints) {
      try {
        res = await ApiClient.get(path);
        break;
      } catch (e) {
        print('[CASBOX REPO] GET "$path" attempt error: $e');
      }
    }

    if (res != null) {
      return _parseMessagesFromResponse(res);
    }
    return [];
  }

  /// 2.1 Send Message: POST /api/casbox/send
  /// Request payload (CasboxSendRequest):
  /// { "receiverEmail": "...", "subject": "...", "body": "...", "attachmentsJson": "..." }
  static Future<Map<String, dynamic>> sendCasboxMessage({
    required String contactEmail,
    required String message,
    String? subject,
    List<AttachmentModel> attachments = const [],
  }) async {
    final cleanRecipient = contactEmail.trim();
    final body = <String, dynamic>{
      'receiverEmail': cleanRecipient,
      'body': message,
      if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
    };

    if (attachments.isNotEmpty) {
      final attachList = attachments.map((a) => {
        'fileName': a.fileName,
        'fileSize': a.fileSize,
        if (a.filePath != null && a.filePath!.isNotEmpty) 'url': a.filePath,
      }).toList();
      body['attachmentsJson'] = jsonEncode(attachList);
    }

    try {
      final res = await ApiClient.post('/api/casbox/send', body: body);
      return (res['data'] as Map<String, dynamic>?) ?? res;
    } catch (e) {
      print('[CASBOX REPO WARNING] POST /api/casbox/send failed: $e');
      rethrow;
    }
  }

  /// 2.4 Update Message Status (Receipts): PATCH /api/casbox/status
  /// Request payload (CasboxStatusRequest):
  /// { "messageIds": [98, 101], "status": "SEEN" | "DELIVERED" }
  static Future<void> updateStatus(dynamic messageId, String status) async {
    final parsedInt = int.tryParse(messageId.toString());
    final idVal = parsedInt ?? messageId;
    final targetStatus = (status.toUpperCase() == 'READ' || status.toUpperCase() == 'SEEN')
        ? 'SEEN'
        : status.toUpperCase();

    final body = {
      'messageIds': [idVal],
      'status': targetStatus,
      // Compatibility keys:
      'ids': [idVal],
      'threadId': idVal,
    };

    try {
      await ApiClient.patch('/api/casbox/status', body: body);
    } catch (e) {
      print('[CASBOX REPO WARNING] PATCH /api/casbox/status failed ($e), trying POST...');
      try {
        await ApiClient.post('/api/casbox/status', body: body);
      } catch (_) {}
    }
  }

  /// Batch update status for multiple message IDs
  static Future<void> updateMessagesStatus(List<dynamic> messageIds, String status) async {
    if (messageIds.isEmpty) return;
    final intIds = messageIds.map((id) => int.tryParse(id.toString()) ?? id).toList();
    final targetStatus = (status.toUpperCase() == 'READ' || status.toUpperCase() == 'SEEN')
        ? 'SEEN'
        : status.toUpperCase();

    final body = {
      'messageIds': intIds,
      'status': targetStatus,
      'ids': intIds,
    };

    try {
      await ApiClient.patch('/api/casbox/status', body: body);
    } catch (e) {
      try {
        await ApiClient.post('/api/casbox/status', body: body);
      } catch (_) {}
    }
  }

  /// 2.5 Mark Pending Messages as Delivered: POST /api/casbox/delivered
  /// Marks all incoming messages in 'SENT' state destined for current user as 'DELIVERED'.
  static Future<void> markAllDelivered() async {
    try {
      await ApiClient.post('/api/casbox/delivered');
      print('[CASBOX REPO] markAllDelivered succeeded: POST /api/casbox/delivered');
    } catch (e) {
      print('[CASBOX REPO ERROR] markAllDelivered: $e');
    }
  }

  /// Mark specific message delivered
  static Future<void> markDelivered(dynamic messageId) async {
    try {
      await updateStatus(messageId, 'DELIVERED');
    } catch (_) {
      try {
        await ApiClient.post(
          '/api/casbox/delivered',
          body: {'messageId': messageId},
        );
      } catch (_) {}
    }
  }

  /// 4. Authorized Contacts (casboxAccepted) via GET /api/users/settings
  static Future<List<String>> getAuthorizedContacts() async {
    try {
      final res = await ApiClient.get('/api/users/settings');
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      final accepted = data['casboxAccepted'];
      if (accepted is List) {
        return accepted.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
      }
    } catch (e) {
      print('[CASBOX REPO ERROR] getAuthorizedContacts: $e');
    }
    return [];
  }

  /// 4.2 Update Authorized Contacts via PATCH/PUT /api/users/settings
  static Future<void> updateAuthorizedContacts(List<String> emails) async {
    final cleanEmails = emails.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList();
    try {
      await ApiClient.patch('/api/users/settings', body: {'casboxAccepted': cleanEmails});
    } catch (_) {
      try {
        await ApiClient.put('/api/users/settings', body: {'casboxAccepted': cleanEmails});
      } catch (e) {
        print('[CASBOX REPO ERROR] updateAuthorizedContacts: $e');
      }
    }
  }
}
