import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/network/token_service.dart';
import '../../models/attachment_model.dart';
import '../colab_provider.dart';

/// Repository for all Group/Chat (Colab) backend API calls.
/// 
/// Strictly maps to official endpoints:
/// 1.1 POST   /api/chat/group
/// 1.2 GET    /api/chat/user/{email}
/// 1.3 GET    /api/chat/{chatId}/messages
/// 1.4 POST   /api/chat/message
/// 1.5 POST   /api/chat/{chatId}/members
/// 1.6 GET    /api/chat/{chatId}/members
/// 1.7 GET    /api/chat/invitations
///     POST   /api/chat/invitations/{id}/accept
///     POST   /api/chat/invitations/{id}/reject
/// 1.8 POST   /api/chat/{chatId}/broadcast
///     GET    /api/chat/{chatId}/broadcasts
/// 1.9 POST   /api/chat/{id}/leave
///     DELETE /api/chat/{id}
///     PATCH  /api/chat/{id}/name
class GroupRepository {
  /// Safely parses attachments JSON or List into AttachmentModel list
  static List<AttachmentModel> parseAttachments(dynamic rawJson) {
    if (rawJson == null) return [];
    try {
      final List<dynamic> list;
      if (rawJson is List) {
        list = rawJson;
      } else if (rawJson is String && rawJson.trim().isNotEmpty) {
        list = jsonDecode(rawJson) as List;
      } else {
        list = [];
      }
      return list.map((item) {
        if (item is Map<String, dynamic>) return AttachmentModel.fromJson(item);
        if (item is Map) return AttachmentModel.fromJson(item.cast<String, dynamic>());
        return AttachmentModel(
          fileName: item.toString(),
          fileType: 'FILE',
          fileSize: '',
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
  // ── Helper ─────────────────────────────────────────────────────────────────

  static List<dynamic> _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      final listKeys = [
        'emails', 'messages', 'threads', 'items', 'content', 'data',
        'list', 'mailboxes', 'tickets', 'conversations', 'chats', 'invitations',
        'broadcasts', 'members', 'results', 'payload'
      ];
      for (final key in listKeys) {
        if (json.containsKey(key)) {
          final val = json[key];
          if (val is List) return val;
          if (val is Map) {
            final nested = _extractList(val);
            if (nested.isNotEmpty) return nested;
          }
        }
      }
      for (final val in json.values) {
        if (val is List) return val;
        if (val is Map) {
          final nested = _extractList(val);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return [];
  }

  // ── 1.2 Get User Conversations List ────────────────────────────────────────

  /// GET /api/chat/user/{email}
  static Future<List<ColabGroup>> fetchGroups([String? userEmail]) async {
    final email = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim()
        : (await TokenService.getUserEmail() ?? '');

    if (email.isEmpty) {
      print('[GROUP FETCH] Error: User email is empty. Returning empty list.');
      return [];
    }

    final encodedEmail = Uri.encodeComponent(email);
    print('[GROUP FETCH] GET /api/chat/user/$encodedEmail');

    try {
      final dynamic res = await ApiClient.get('/api/chat/user/$encodedEmail');
      print('[GROUP FETCH] Response: $res');

      final rawList = _extractList(res);
      final List<ColabGroup> groups = [];
      for (final raw in rawList) {
        if (raw is Map<String, dynamic>) {
          groups.add(_parseGroup(raw));
        }
      }
      print('[GROUP FETCH] Parsed ${groups.length} groups.');
      return groups;
    } catch (e) {
      print('[GROUP FETCH ERROR] GET /api/chat/user/$encodedEmail failed: $e');
      return [];
    }
  }

  // ── 1.1 Create Group Chat ──────────────────────────────────────────────────

  /// POST /api/chat/group
  /// Body: { "name": "...", "members": ["email1", "email2"] }
  static Future<ColabGroup> createGroup(String name, [List<String> members = const []]) async {
    final cleanMembers = members.map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
    print('[GROUP CREATE] POST /api/chat/group | name="$name", members=$cleanMembers');

    final body = {
      'name': name,
      'members': cleanMembers,
    };

    final dynamic res = await ApiClient.post('/api/chat/group', body: body);
    print('[GROUP CREATE] Response: $res');

    final Map<String, dynamic> data = (res is Map<String, dynamic> && res.containsKey('data') && res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : (res is Map<String, dynamic> ? res : {});

    return _parseGroup(data);
  }

  // ── 1.3 Get Chat Message History ──────────────────────────────────────────

  /// GET /api/chat/{chatId}/messages
  static Future<List<Map<String, dynamic>>> fetchMessageHistory(dynamic chatId) async {
    print('[GROUP MESSAGES] GET /api/chat/$chatId/messages');
    try {
      final dynamic res = await ApiClient.get('/api/chat/$chatId/messages');
      print('[GROUP MESSAGES] Response: $res');

      final rawList = _extractList(res);
      return rawList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      print('[GROUP MESSAGES ERROR] GET /api/chat/$chatId/messages failed: $e');
      return [];
    }
  }

  // ── 1.4 Send Message via HTTP REST ─────────────────────────────────────────

  /// POST /api/chat/message
  /// Body: { "chatId": 12, "sender": "...", "message": "...", "attachmentsJson": "[]" }
  static Future<Map<String, dynamic>> sendChatMessage({
    required dynamic chatId,
    required String sender,
    required String message,
    String attachmentsJson = '[]',
  }) async {
    final parsedChatId = int.tryParse(chatId.toString()) ?? chatId;
    final body = {
      'chatId': parsedChatId,
      'sender': sender,
      'message': message,
      'attachmentsJson': attachmentsJson,
    };

    print('[GROUP SEND MESSAGE] POST /api/chat/message | body=$body');
    final dynamic res = await ApiClient.post('/api/chat/message', body: body);
    print('[GROUP SEND MESSAGE] Response: $res');
    return (res is Map<String, dynamic>) ? res : {};
  }

  // ── 1.5 Add Members to Group Chat ──────────────────────────────────────────

  /// POST /api/chat/{chatId}/members
  /// Body: { "emails": ["newjoiner@bnxmail.com"] }
  static Future<void> addMembers(dynamic chatId, List<String> emails) async {
    final cleanEmails = emails.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    print('[GROUP ADD MEMBERS] POST /api/chat/$chatId/members | emails=$cleanEmails');

    final body = {'emails': cleanEmails};
    final dynamic res = await ApiClient.post('/api/chat/$chatId/members', body: body);
    print('[GROUP ADD MEMBERS] Response: $res');
  }

  // ── 1.6 List Group Members ─────────────────────────────────────────────────

  /// GET /api/chat/{chatId}/members
  static Future<List<String>> fetchGroupMembers(dynamic chatId) async {
    print('[GROUP MEMBERS] GET /api/chat/$chatId/members');
    try {
      final dynamic res = await ApiClient.get('/api/chat/$chatId/members');
      print('[GROUP MEMBERS] Response: $res');

      final rawList = _extractList(res);
      return rawList.map((item) {
        if (item is Map) {
          return item['email']?.toString() ?? item['username']?.toString() ?? item.toString();
        }
        return item.toString();
      }).toList();
    } catch (e) {
      print('[GROUP MEMBERS ERROR] GET /api/chat/$chatId/members failed: $e');
      return [];
    }
  }

  // ── 1.7 Manage Pending Invitations ─────────────────────────────────────────

  /// GET /api/chat/invitations
  static Future<List<ColabInvitation>> fetchInvitations() async {
    print('[GROUP INVITATIONS] GET /api/chat/invitations');
    try {
      final dynamic res = await ApiClient.get('/api/chat/invitations');
      print('[GROUP INVITATIONS] Response: $res');

      final rawList = _extractList(res);
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((raw) => ColabInvitation(
                id: raw['id']?.toString() ?? '',
                groupName: raw['chatName']?.toString() ??
                    raw['groupName']?.toString() ??
                    raw['name']?.toString() ??
                    'Unknown Group',
                invitedBy: raw['inviterEmail']?.toString() ??
                    raw['invitedBy']?.toString() ??
                    raw['from']?.toString() ??
                    raw['sender']?.toString() ??
                    '',
                timestamp: DateTime.tryParse(
                        raw['createdAt']?.toString() ?? raw['timestamp']?.toString() ?? '') ??
                    DateTime.now(),
              ))
          .where((inv) => inv.id.isNotEmpty)
          .toList();
    } catch (e) {
      print('[GROUP INVITATIONS ERROR] GET /api/chat/invitations failed: $e');
      return [];
    }
  }

  /// POST /api/chat/invitations/{id}/accept
  static Future<void> acceptInvitation(dynamic id) async {
    print('[GROUP INVITATION ACCEPT] POST /api/chat/invitations/$id/accept');
    final dynamic res = await ApiClient.post('/api/chat/invitations/$id/accept');
    print('[GROUP INVITATION ACCEPT] Response: $res');
  }

  /// POST /api/chat/invitations/{id}/reject
  static Future<void> rejectInvitation(dynamic id) async {
    print('[GROUP INVITATION REJECT] POST /api/chat/invitations/$id/reject');
    final dynamic res = await ApiClient.post('/api/chat/invitations/$id/reject');
    print('[GROUP INVITATION REJECT] Response: $res');
  }

  // ── 1.8 Send / Get Broadcasts ──────────────────────────────────────────────

  /// POST /api/chat/{chatId}/broadcast
  /// Body: { "subject": "...", "body": "...", "attachmentsJson": "[]" }
  static Future<void> sendBroadcast(
    dynamic chatId,
    String subject,
    String bodyContent, {
    String attachmentsJson = '[]',
  }) async {
    print('[GROUP BROADCAST SEND] POST /api/chat/$chatId/broadcast | subject="$subject"');
    final body = {
      'subject': subject,
      'body': bodyContent,
      'attachmentsJson': attachmentsJson,
    };
    final dynamic res = await ApiClient.post('/api/chat/$chatId/broadcast', body: body);
    print('[GROUP BROADCAST SEND] Response: $res');
  }

  /// GET /api/chat/{chatId}/broadcasts
  static Future<List<ColabBroadcast>> fetchBroadcasts(dynamic chatId) async {
    print('[GROUP BROADCASTS] GET /api/chat/$chatId/broadcasts');
    try {
      final dynamic res = await ApiClient.get('/api/chat/$chatId/broadcasts');
      print('[GROUP BROADCASTS] Response: $res');

      final rawList = _extractList(res);
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((raw) => ColabBroadcast(
                sender: raw['from']?.toString() ?? raw['sender']?.toString() ?? '',
                subject: raw['subject']?.toString() ?? '(No Subject)',
                body: raw['body']?.toString() ?? raw['content']?.toString() ?? '',
                timestamp: DateTime.tryParse(
                        raw['sentDate']?.toString() ?? raw['timestamp']?.toString() ?? '') ??
                    DateTime.now(),
                attachments: parseAttachments(raw['attachmentsJson'] ?? raw['attachments']),
              ))
          .toList();
    } catch (e) {
      print('[GROUP BROADCASTS ERROR] GET /api/chat/$chatId/broadcasts failed: $e');
      return [];
    }
  }

  // ── 1.9 Manage Group Settings ──────────────────────────────────────────────

  /// POST /api/chat/{id}/leave
  static Future<void> leaveGroup(dynamic chatId) async {
    print('[GROUP LEAVE] POST /api/chat/$chatId/leave');
    final dynamic res = await ApiClient.post('/api/chat/$chatId/leave');
    print('[GROUP LEAVE] Response: $res');
  }

  /// DELETE /api/chat/{id}
  static Future<void> deleteGroup(dynamic chatId) async {
    print('[GROUP DELETE] DELETE /api/chat/$chatId');
    final dynamic res = await ApiClient.delete('/api/chat/$chatId');
    print('[GROUP DELETE] Response: $res');
  }

  /// PATCH /api/chat/{id}/name
  /// Body: { "name": "New Name" }
  static Future<void> renameGroup(dynamic chatId, String newName) async {
    print('[GROUP RENAME] PATCH /api/chat/$chatId/name | name="$newName"');
    final dynamic res = await ApiClient.patch('/api/chat/$chatId/name', body: {'name': newName});
    print('[GROUP RENAME] Response: $res');
  }

  // ── Parsing Helper ─────────────────────────────────────────────────────────

  static ColabGroup _parseGroup(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? raw['chatId']?.toString() ?? raw['_id']?.toString() ?? '';
    final name = raw['name']?.toString() ?? raw['groupName']?.toString() ?? 'Unnamed Group';
    final type = raw['type']?.toString() ?? raw['chatType']?.toString() ?? 'GROUP';
    final creatorEmail = raw['creatorEmail']?.toString() ?? raw['inviterEmail']?.toString() ?? '';
    final lastMessage = raw['lastMessage']?.toString() ?? '';
    final lastMessageTime = raw['lastMessageTime']?.toString() ?? '';
    final unreadCount = (raw['unreadCount'] is num) ? (raw['unreadCount'] as num).toInt() : 0;

    List<String> memberEmails = [];
    if (raw['memberEmails'] is List) {
      memberEmails = (raw['memberEmails'] as List).map((e) => e.toString()).toList();
    } else if (raw['members'] is List) {
      memberEmails = (raw['members'] as List).map((e) {
        if (e is Map) return e['email']?.toString() ?? e.toString();
        return e.toString();
      }).toList();
    }

    return ColabGroup(
      id: id,
      name: name,
      desc: raw['description']?.toString() ?? '',
      type: type,
      members: memberEmails,
      activeCount: memberEmails.length,
      unread: unreadCount > 0,
      unreadCount: unreadCount,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      creatorEmail: creatorEmail,
    );
  }
}
