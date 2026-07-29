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
              '';
          final status = item['status']?.toString() ?? 'PENDING';
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

  /// Fetch all Casbox threads/messages from backend API: GET /api/casbox
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
        print('[DIAGNOSTIC] fetchCasbox() succeeded with path "$path"');
        break;
      } catch (e) {
        print('[DIAGNOSTIC WARNING] GET "$path" error: $e');
      }
    }

    if (res != null) {
      final parsed = _parseMessagesFromResponse(res);
      print('[DIAGNOSTIC] fetchCasbox() parsed ${parsed.length} items.');
      return parsed;
    }

    return [];
  }

  /// Fetch single thread by contact email: GET /api/casbox/thread/{contactEmail}
  static Future<List<CasboxMessage>> fetchThread(String contactEmail) async {
    if (contactEmail.trim().isEmpty) return [];
    dynamic res;
    final candidateEndpoints = [
      '/api/casbox/thread/$contactEmail',
      '/api/casbox/thread/$contactEmail/',
      '/api/casbox/$contactEmail',
      '/api/mail/casbox/thread/$contactEmail',
    ];
    for (final path in candidateEndpoints) {
      try {
        res = await ApiClient.get(path);
        print('[DIAGNOSTIC] fetchThread($contactEmail) succeeded with path "$path"');
        break;
      } catch (e) {
        print('[DIAGNOSTIC WARNING] GET "$path" error: $e');
      }
    }

    if (res != null) {
      return _parseMessagesFromResponse(res);
    }
    return [];
  }

  /// Send Casbox message: POST /api/casbox/send
  /// Body: { "contactEmail": "...", "message": "..." }
  static Future<Map<String, dynamic>> sendCasboxMessage({
    required String contactEmail,
    required String message,
    String? subject,
    List<AttachmentModel> attachments = const [],
  }) async {
    final body = {
      'contactEmail': contactEmail,
      'message': message,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
    };
    try {
      return await ApiClient.post('/api/casbox/send', body: body);
    } catch (e) {
      print('[DIAGNOSTIC WARNING] POST /api/casbox/send primary failed ($e), trying fallback...');
      final fallbackBody = {
        'receiverEmail': contactEmail,
        'body': message,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      };
      return await ApiClient.post('/api/casbox/send', body: fallbackBody);
    }
  }

  /// Update Casbox status: PATCH /api/casbox/status
  static Future<void> updateStatus(dynamic threadId, String status) async {
    final parsedInt = int.tryParse(threadId.toString());
    final idVal = parsedInt ?? threadId;
    final body = {
      'ids': [idVal],
      'threadId': idVal,
      'status': status,
    };
    try {
      await ApiClient.patch('/api/casbox/status', body: body);
    } catch (e) {
      print('[DIAGNOSTIC WARNING] PATCH /api/casbox/status failed ($e), trying POST fallback...');
      try {
        await ApiClient.post('/api/casbox/status', body: body);
      } catch (_) {}
    }
  }

  /// Mark message delivered: POST /api/casbox/delivered
  static Future<void> markDelivered(dynamic messageId) async {
    try {
      await ApiClient.post(
        '/api/casbox/delivered',
        body: {'messageId': messageId},
      );
    } catch (e) {
      print('[CASBOX REPO ERROR] markDelivered: $e');
    }
  }
}
