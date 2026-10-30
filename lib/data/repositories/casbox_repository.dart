import 'dart:convert';
import '../../models/attachment_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/token_service.dart';
import '../colab_provider.dart';

class CasboxRepository {
  static List<dynamic>? _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      final listKeys = [
        'emails',
        'messages',
        'threads',
        'items',
        'content',
        'data',
        'list',
        'mailboxes',
        'tickets',
        'conversations',
        'casbox',
        'casboxMessages',
        'results',
        'payload',
        'connections',
        'aliases',
        'blockedContacts',
        'blockedUsers'
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

  static List<CasboxMessage> _parseMessagesFromResponse(dynamic res, [String? currentUserEmail]) {
    final rawList = _extractList(res);
    if (rawList == null) return [];

    final result = <CasboxMessage>[];
    for (final item in rawList) {
      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        final innerMessages = itemMap['messages'] ??
            itemMap['threadMessages'] ??
            itemMap['chatMessages'];
        if (innerMessages is List && innerMessages.isNotEmpty) {
          final contactEmail = itemMap['contactEmail']?.toString() ??
              itemMap['sender']?.toString() ??
              itemMap['email']?.toString() ??
              itemMap['senderEmail']?.toString() ??
              '';
          final status = itemMap['status']?.toString() ?? 'SENT';
          final threadId = itemMap['id']?.toString() ??
              itemMap['threadId']?.toString() ??
              '';

          for (final msg in innerMessages) {
            if (msg is Map) {
              final msgMap = Map<String, dynamic>.from(msg);
              result.add(CasboxMessage.fromJson({
                ...msgMap,
                if (!msgMap.containsKey('contactEmail') &&
                    contactEmail.isNotEmpty)
                  'contactEmail': contactEmail,
                if (!msgMap.containsKey('status')) 'status': status,
                if (!msgMap.containsKey('threadId') && threadId.isNotEmpty)
                  'threadId': threadId,
                if (currentUserEmail != null && currentUserEmail.isNotEmpty)
                  'currentUserEmail': currentUserEmail,
              }, currentUserEmail));
            }
          }
        } else {
          result.add(CasboxMessage.fromJson({
            ...itemMap,
            if (currentUserEmail != null && currentUserEmail.isNotEmpty)
              'currentUserEmail': currentUserEmail,
          }, currentUserEmail));
        }
      }
    }
    return result;
  }

  // ── 1. Core Cashbox Messaging APIs (/api/casbox) ───────────────────────────

  /// API 1: Fetch All Messages: GET /api/casbox
  /// Retrieves incoming and outgoing Cashbox messages for authenticated user.
  static Future<List<CasboxMessage>> fetchCasbox([String? userEmail]) async {
    final curEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim()
        : (await TokenService.getUserEmail() ?? '');

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
      return _parseMessagesFromResponse(res, curEmail);
    }
    return [];
  }

  /// API 2: Fetch Conversation Thread: GET /api/casbox/thread/{contactEmail}
  /// Retrieves historical messages between user and counterpart sorted timestamp ASC.
  static Future<List<CasboxMessage>> fetchThread(String contactEmail, [String? userEmail]) async {
    final cleanContact = contactEmail.trim();
    if (cleanContact.isEmpty) return [];

    final curEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim()
        : (await TokenService.getUserEmail() ?? '');

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
      return _parseMessagesFromResponse(res, curEmail);
    }
    return [];
  }

  /// API 3: Send Message: POST /api/casbox/send
  /// Body: {"receiverEmail":"...","subject":"...","body":"...","attachmentsJson":"..."}
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

  /// API 4: Batch Archive / Unarchive Messages: PATCH /api/casbox/archive
  /// Body: {"messageIds":[1040,1041],"archived":true}
  static Future<void> batchArchiveMessages(
      List<dynamic> messageIds, bool archived) async {
    if (messageIds.isEmpty) return;
    final validIds = messageIds
        .map((id) => int.tryParse(id.toString()))
        .whereType<int>()
        .toList();
    if (validIds.isEmpty) return;

    final body = {
      'messageIds': validIds,
      'archived': archived,
    };
    try {
      await ApiClient.patch('/api/casbox/archive', body: body);
      print('[CASBOX REPO] batchArchiveMessages succeeded via PATCH /api/casbox/archive for ${validIds.length} ids (archived=$archived)');
      return;
    } catch (e) {
      print('[CASBOX REPO WARNING] PATCH /api/casbox/archive failed ($e), trying POST...');
    }

    try {
      await ApiClient.post('/api/casbox/archive', body: body);
      print('[CASBOX REPO] batchArchiveMessages succeeded via POST /api/casbox/archive for ${validIds.length} ids (archived=$archived)');
      return;
    } catch (e2) {
      print('[CASBOX REPO ERROR] batchArchiveMessages failed on both PATCH and POST: $e2');
    }

    // Comprehensive fallback for unarchive: try individual endpoints
    for (final id in validIds) {
      try {
        await archiveMessage(id, archived);
      } catch (_) {}
    }
  }

  /// API 5: Single Message Archive / Unarchive: PATCH /api/casbox/{id}/archive?archived={bool}
  /// Also seamless fallback to API 4: PATCH /api/casbox/archive and explicit unarchive routes
  static Future<void> archiveMessage(dynamic messageId, bool archived) async {
    final parsedId = int.tryParse(messageId.toString());
    if (parsedId == null) {
      print('[CASBOX REPO WARNING] archiveMessage: non-numeric id "$messageId", skipping direct API');
      return;
    }

    // 1. Try batch endpoint (API 4) first as used by web frontend
    try {
      await ApiClient.patch(
        '/api/casbox/archive',
        body: {
          'messageIds': [parsedId],
          'archived': archived,
        },
      );
      print('[CASBOX REPO] archiveMessage succeeded via PATCH /api/casbox/archive for id=$parsedId (archived=$archived)');
      return;
    } catch (e) {
      print('[CASBOX REPO WARNING] PATCH /api/casbox/archive failed ($e), trying single endpoint API 5...');
    }

    // 2. Try single endpoint (API 5) with query parameter
    try {
      await ApiClient.patch(
        '/api/casbox/$parsedId/archive?archived=$archived',
        body: {'archived': archived},
      );
      print('[CASBOX REPO] archiveMessage succeeded via PATCH /api/casbox/$parsedId/archive for id=$parsedId (archived=$archived)');
      return;
    } catch (e2) {
      print('[CASBOX REPO WARNING] PATCH /api/casbox/$parsedId/archive failed: $e2, trying POST...');
    }

    // 3. Try POST fallback for single endpoint
    try {
      await ApiClient.post(
        '/api/casbox/$parsedId/archive?archived=$archived',
        body: {'archived': archived},
      );
      print('[CASBOX REPO] archiveMessage succeeded via POST /api/casbox/$parsedId/archive for id=$parsedId (archived=$archived)');
      return;
    } catch (_) {}

    // 4. If unarchiving, also attempt explicit unarchive endpoints
    if (!archived) {
      try {
        await ApiClient.patch('/api/casbox/$parsedId/unarchive');
        print('[CASBOX REPO] archiveMessage succeeded via PATCH /api/casbox/$parsedId/unarchive');
        return;
      } catch (_) {}
      try {
        await ApiClient.post('/api/casbox/$parsedId/unarchive');
        print('[CASBOX REPO] archiveMessage succeeded via POST /api/casbox/$parsedId/unarchive');
        return;
      } catch (_) {}
      try {
        await ApiClient.patch(
          '/api/casbox/unarchive',
          body: {'messageIds': [parsedId]},
        );
        print('[CASBOX REPO] archiveMessage succeeded via PATCH /api/casbox/unarchive');
        return;
      } catch (_) {}
      try {
        await ApiClient.post(
          '/api/casbox/unarchive',
          body: {'messageIds': [parsedId]},
        );
        print('[CASBOX REPO] archiveMessage succeeded via POST /api/casbox/unarchive');
        return;
      } catch (_) {}
    }
  }

  /// API 6: Update Delivery and Read Status: PATCH /api/casbox/status
  /// Body: {"messageIds":[101,102],"status":"SEEN"}
  static Future<void> updateStatus(dynamic messageId, String status) async {
    final parsedInt = int.tryParse(messageId.toString());
    if (parsedInt == null) return;

    final targetStatus = (status.toUpperCase() == 'READ' ||
            status.toUpperCase() == 'SEEN')
        ? 'SEEN'
        : status.toUpperCase();

    final body = {
      'messageIds': [parsedInt],
      'status': targetStatus,
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

  /// API 6 (Batch): Update multiple message status
  static Future<void> updateMessagesStatus(
      List<dynamic> messageIds, String status) async {
    if (messageIds.isEmpty) return;
    final intIds = messageIds
        .map((id) => int.tryParse(id.toString()))
        .whereType<int>()
        .toList();
    if (intIds.isEmpty) return;

    final targetStatus = (status.toUpperCase() == 'READ' ||
            status.toUpperCase() == 'SEEN')
        ? 'SEEN'
        : status.toUpperCase();

    final body = {
      'messageIds': intIds,
      'status': targetStatus,
    };

    try {
      await ApiClient.patch('/api/casbox/status', body: body);
    } catch (e) {
      try {
        await ApiClient.post('/api/casbox/status', body: body);
      } catch (_) {}
    }
  }

  /// API 7: Mark Unseen Messages as Delivered: POST /api/casbox/delivered
  static Future<void> markAllDelivered() async {
    try {
      await ApiClient.post('/api/casbox/delivered');
      print('[CASBOX REPO] markAllDelivered succeeded: POST /api/casbox/delivered');
    } catch (e) {
      print('[CASBOX REPO ERROR] markAllDelivered: $e');
    }
  }

  /// Mark message(s) delivered. If messageId is omitted, calls POST /api/casbox/delivered (API 7)
  static Future<void> markDelivered([dynamic messageId]) async {
    if (messageId == null) {
      await markAllDelivered();
      return;
    }
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

  /// API 8, 9, 10: Edit Sent Message: PATCH/PUT /api/casbox/{id} or PATCH /api/casbox/{id}/edit
  /// Body: {"body":"New content"}
  static Future<void> editMessage(dynamic messageId, String newBody) async {
    final body = {'body': newBody};
    try {
      await ApiClient.patch('/api/casbox/$messageId', body: body);
      print('[CASBOX REPO] editMessage succeeded with PATCH /api/casbox/$messageId');
      return;
    } catch (e) {
      print('[CASBOX REPO] PATCH /api/casbox/$messageId failed ($e), trying PUT...');
    }

    try {
      await ApiClient.put('/api/casbox/$messageId', body: body);
      print('[CASBOX REPO] editMessage succeeded with PUT /api/casbox/$messageId');
      return;
    } catch (e) {
      print('[CASBOX REPO] PUT /api/casbox/$messageId failed ($e), trying /edit route...');
    }

    try {
      await ApiClient.patch('/api/casbox/$messageId/edit', body: body);
      print('[CASBOX REPO] editMessage succeeded with PATCH /api/casbox/$messageId/edit');
    } catch (e) {
      print('[CASBOX REPO ERROR] editMessage failed on all routes: $e');
      rethrow;
    }
  }

  /// API 11: Delete Conversation: DELETE /api/casbox/conversation/{contactEmail}
  /// Also tries aliases: /api/casbox/messages/{contactEmail}, /api/casbox/{contactEmail}
  static Future<void> deleteConversation(String contactEmail) async {
    final cleanContact = contactEmail.trim();
    if (cleanContact.isEmpty) return;
    final encoded = Uri.encodeComponent(cleanContact);

    final candidateEndpoints = [
      '/api/casbox/conversation/$encoded',
      '/api/casbox/conversation/$cleanContact',
      '/api/casbox/messages/$encoded',
      '/api/casbox/$encoded',
    ];

    for (final path in candidateEndpoints) {
      try {
        await ApiClient.delete(path);
        print('[CASBOX REPO] deleteConversation succeeded via DELETE "$path"');
        return;
      } catch (e) {
        print('[CASBOX REPO] deleteConversation attempt "$path" error: $e');
      }
    }
  }

  // ── 2. Contact & Connection APIs (/api/connections) ─────────────────────────

  /// API 12: Get Accepted Connections: GET /api/connections/accepted
  /// Returns contacts with CONNECTED status; populates Cashbox "Accepted" list.
  static Future<List<Map<String, dynamic>>> getAcceptedConnections() async {
    try {
      final res = await ApiClient.get('/api/connections/accepted');
      final rawList = _extractList(res);
      if (rawList != null) {
        return rawList
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (e) {
      print('[CASBOX REPO ERROR] getAcceptedConnections: $e');
    }
    return [];
  }

  /// API 13: Get All User Connections: GET /api/connections
  /// Returns all connection records (CONNECTED and DISCONNECTED).
  static Future<List<Map<String, dynamic>>> getAllConnections() async {
    try {
      final res = await ApiClient.get('/api/connections');
      final rawList = _extractList(res);
      if (rawList != null) {
        return rawList
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (e) {
      print('[CASBOX REPO ERROR] getAllConnections: $e');
    }
    return [];
  }

  /// API 14: Update Connection Status: PATCH or PUT /api/connections/{connectionId}/status
  /// Body: {"status":"DISCONNECTED" | "CONNECTED"}
  static Future<void> updateConnectionStatus(
      dynamic connectionId, String status) async {
    final parsedId = int.tryParse(connectionId.toString());
    if (parsedId == null) {
      print('[CASBOX REPO WARNING] updateConnectionStatus: "$connectionId" is not a numeric connectionId');
      return;
    }
    final body = {'status': status.toUpperCase()};
    try {
      await ApiClient.patch('/api/connections/$parsedId/status', body: body);
      print('[CASBOX REPO] updateConnectionStatus succeeded via PATCH /api/connections/$parsedId/status');
      return;
    } catch (_) {
      try {
        await ApiClient.put('/api/connections/$parsedId/status', body: body);
        print('[CASBOX REPO] updateConnectionStatus succeeded via PUT /api/connections/$parsedId/status');
      } catch (e) {
        print('[CASBOX REPO ERROR] updateConnectionStatus: $e');
        rethrow;
      }
    }
  }

  // ── 3. Contact Customization / Alias APIs (/api/contact-aliases) ───────────

  /// API 15: Get All Aliases: GET /api/contact-aliases
  /// Returns custom contact names created by the user.
  static Future<Map<String, String>> getContactAliases() async {
    final result = <String, String>{};
    try {
      final res = await ApiClient.get('/api/contact-aliases');
      final rawList = _extractList(res);
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            final id = item['contactUserId']?.toString() ??
                item['email']?.toString() ??
                item['userId']?.toString();
            final name = item['customName']?.toString() ??
                item['alias']?.toString() ??
                item['name']?.toString();
            if (id != null && name != null) {
              result[id] = name;
            }
          }
        }
      } else {
        res.forEach((k, v) {
          result[k.toString()] = v.toString();
        });
      }
    } catch (e) {
      print('[CASBOX REPO ERROR] getContactAliases: $e');
    }
    return result;
  }

  /// API 16: Get Single Alias: GET /api/contact-aliases/{contactUserId}
  static Future<String?> getContactAlias(dynamic contactUserId) async {
    try {
      final res = await ApiClient.get('/api/contact-aliases/$contactUserId');
      return res['customName']?.toString() ??
          res['alias']?.toString() ??
          res['name']?.toString();
    } catch (e) {
      print('[CASBOX REPO ERROR] getContactAlias: $e');
    }
    return null;
  }

  /// API 17: Set/Update Alias: PUT /api/contact-aliases/{contactUserId}
  /// Body: {"customName":"Alice (CEO Office)"}
  static Future<void> setContactAlias(
      dynamic contactUserId, String customName) async {
    try {
      await ApiClient.put(
        '/api/contact-aliases/$contactUserId',
        body: {'customName': customName},
      );
      print('[CASBOX REPO] setContactAlias succeeded for $contactUserId');
    } catch (e) {
      print('[CASBOX REPO ERROR] setContactAlias: $e');
      rethrow;
    }
  }

  /// API 18: Delete Alias: DELETE /api/contact-aliases/{contactUserId}
  static Future<void> deleteContactAlias(dynamic contactUserId) async {
    try {
      await ApiClient.delete('/api/contact-aliases/$contactUserId');
      print('[CASBOX REPO] deleteContactAlias succeeded for $contactUserId');
    } catch (e) {
      print('[CASBOX REPO ERROR] deleteContactAlias: $e');
      rethrow;
    }
  }

  // ── 4. Contact Safety & Block APIs (/api/blocked-contacts) ─────────────────

  /// API 19: Get Blocked Contacts: GET /api/blocked-contacts
  /// Lists email addresses blocked by the user.
  static Future<List<String>> getBlockedContacts() async {
    try {
      final res = await ApiClient.get('/api/blocked-contacts');
      final rawList = _extractList(res);
      if (rawList != null) {
        final emails = <String>[];
        for (final item in rawList) {
          if (item is String) {
            emails.add(item.trim().toLowerCase());
          } else if (item is Map) {
            final email = item['email']?.toString() ??
                item['contactEmail']?.toString() ??
                item['blockedEmail']?.toString();
            if (email != null && email.trim().isNotEmpty) {
              emails.add(email.trim().toLowerCase());
            }
          }
        }
        return emails;
      }
    } catch (e) {
      print('[CASBOX REPO ERROR] getBlockedContacts: $e');
    }
    return [];
  }

  /// API 20: Check Blocked Status: GET /api/blocked-contacts/check?email={email}
  static Future<bool> isBlocked(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final encoded = Uri.encodeComponent(clean);
    try {
      final res =
          await ApiClient.get('/api/blocked-contacts/check?email=$encoded');
      return res['blocked'] == true;
    } catch (e) {
      print('[CASBOX REPO ERROR] isBlocked: $e');
    }
    return false;
  }

  /// API 21: Block Contact: POST /api/blocked-contacts
  /// Body: {"email":"spammer@bnxmail.com","reason":"Spam"}
  static Future<void> blockContact(String email,
      {String reason = 'Spam'}) async {
    final clean = email.trim().toLowerCase();
    try {
      await ApiClient.post(
        '/api/blocked-contacts',
        body: {'email': clean, 'reason': reason},
      );
      print('[CASBOX REPO] blockContact succeeded for $clean');
    } catch (e) {
      print('[CASBOX REPO ERROR] blockContact: $e');
      rethrow;
    }
  }

  /// API 22: Unblock Contact: DELETE /api/blocked-contacts/{email}
  static Future<void> unblockContact(String email) async {
    final clean = email.trim().toLowerCase();
    final encoded = Uri.encodeComponent(clean);
    try {
      await ApiClient.delete('/api/blocked-contacts/$encoded');
      print('[CASBOX REPO] unblockContact succeeded for $clean');
    } catch (e) {
      print('[CASBOX REPO ERROR] unblockContact: $e');
      rethrow;
    }
  }

  // ── 5. Message Requests & Accepted Senders (/api/users/settings) ───────────

  /// API 23: Get User Settings: GET /api/users/settings
  /// Returns casboxAccepted string array of approved senders.
  static Future<List<String>> getAuthorizedContacts() async {
    try {
      final res = await ApiClient.get('/api/users/settings');
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      final accepted = data['casboxAccepted'];
      if (accepted is List) {
        return accepted
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('[CASBOX REPO ERROR] getAuthorizedContacts: $e');
    }
    return [];
  }

  /// API 24: Update Accepted Senders: PATCH /api/users/settings
  /// Body: {"casboxAccepted":["alice@bnxmail.com","bob@bnxmail.com"]}
  static Future<void> updateAuthorizedContacts(List<String> emails) async {
    final cleanEmails = emails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    try {
      await ApiClient.patch('/api/users/settings',
          body: {'casboxAccepted': cleanEmails});
    } catch (_) {
      try {
        await ApiClient.put('/api/users/settings',
            body: {'casboxAccepted': cleanEmails});
      } catch (e) {
        print('[CASBOX REPO ERROR] updateAuthorizedContacts: $e');
      }
    }
  }
}
