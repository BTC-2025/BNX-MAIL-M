import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attachment_model.dart';
import '../models/email_model.dart';
import 'repositories/casbox_repository.dart';
import 'repositories/group_repository.dart';
import '../core/network/token_service.dart';

// ── Collab Models ─────────────────────────────────────────────────────────

class ColabComment {
  final String sender;
  final String message;
  final DateTime timestamp;
  final List<AttachmentModel> attachments;

  ColabComment({
    required this.sender,
    required this.message,
    required this.timestamp,
    this.attachments = const [],
  });
}

class ColabBroadcast {
  final String sender;
  final String subject;
  final String body;
  final DateTime timestamp;
  final List<AttachmentModel> attachments;

  ColabBroadcast({
    required this.sender,
    required this.subject,
    required this.body,
    required this.timestamp,
    this.attachments = const [],
  });
}

class ColabGroup {
  final String id;
  final String name;
  final String desc;
  final String type;
  final List<String> members;
  final int activeCount;
  final bool unread;
  final int unreadCount;
  final String lastMessage;
  final String lastMessageTime;
  final String creatorEmail;
  final List<ColabBroadcast> broadcasts;
  final List<ColabComment> comments;

  ColabGroup({
    required this.id,
    required this.name,
    this.desc = '',
    this.type = 'GROUP',
    required this.members,
    this.activeCount = 0,
    this.unread = false,
    this.unreadCount = 0,
    this.lastMessage = '',
    this.lastMessageTime = '',
    this.creatorEmail = '',
    this.broadcasts = const [],
    this.comments = const [],
  });

  ColabGroup copyWith({
    String? id,
    String? name,
    String? desc,
    String? type,
    List<String>? members,
    int? activeCount,
    bool? unread,
    int? unreadCount,
    String? lastMessage,
    String? lastMessageTime,
    String? creatorEmail,
    List<ColabBroadcast>? broadcasts,
    List<ColabComment>? comments,
  }) {
    return ColabGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      desc: desc ?? this.desc,
      type: type ?? this.type,
      members: members ?? this.members,
      activeCount: activeCount ?? this.activeCount,
      unread: unread ?? this.unread,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      broadcasts: broadcasts ?? this.broadcasts,
      comments: comments ?? this.comments,
    );
  }
}

// ── Collab Invitation Model ───────────────────────────────────────────────

class ColabInvitation {
  final String id;
  final String groupName;
  final String invitedBy;
  final DateTime timestamp;

  ColabInvitation({
    required this.id,
    required this.groupName,
    required this.invitedBy,
    required this.timestamp,
  });
}

// ── Groups Provider ───────────────────────────────────────────────────────

/// Tracks group IDs whose broadcasts have been fetched at least once (top-level for easy UI access)
final Set<String> broadcastsLoadedIds = {};
/// Tracks group IDs whose messages have been fetched at least once (top-level for easy UI access)
final Set<String> messagesLoadedIds = {};

class ColabListNotifier extends StateNotifier<List<ColabGroup>> {
  ColabListNotifier() : super([]) {
    loadGroups();
  }

  bool _loading = false;
  final Set<String> _fetchingMessages = {};
  final Set<String> _fetchingBroadcasts = {};
  final Map<String, List<ColabGroup>> _accountCaches = {};
  String _currentAccountId = 'default';

  void clear() {
    state = [];
    broadcastsLoadedIds.clear();
    messagesLoadedIds.clear();
    _fetchingMessages.clear();
    _fetchingBroadcasts.clear();
    _accountCaches.clear();
  }

  Future<void> switchAccountContext(String accountId) async {
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
    }
    _currentAccountId = accountId;
    if (_accountCaches.containsKey(accountId)) {
      state = _accountCaches[accountId]!;
      loadGroups(); // Background fetch
    } else {
      state = [];
      loadGroups();
    }
  }

  /// Fetch all groups from GET /api/chat/user/{email}
  Future<void> loadGroups([String? userEmail]) async {
    if (_loading) return;
    _loading = true;
    print('[COLLAB PROVIDER] Loading groups from backend...');
    try {
      final fetchedGroups = await GroupRepository.fetchGroups(userEmail);

      // Preserve existing comments & broadcasts for groups already in state to avoid message reset glitches
      final Map<String, ColabGroup> existingMap = {
        for (final g in state) g.id: g
      };

      final updatedGroups = fetchedGroups.map((newG) {
        final existing = existingMap[newG.id];
        if (existing != null) {
          return newG.copyWith(
            comments: existing.comments.isNotEmpty ? existing.comments : newG.comments,
            broadcasts: existing.broadcasts.isNotEmpty ? existing.broadcasts : newG.broadcasts,
            members: newG.members.isNotEmpty ? newG.members : existing.members,
          );
        }
        return newG;
      }).toList();

      state = updatedGroups;
      print('[COLLAB PROVIDER] Groups loaded. Count: ${updatedGroups.length}');
    } catch (e) {
      print('[COLLAB ERROR] Failed to load groups: $e');
    } finally {
      _loading = false;
    }
  }

  /// Create a group via POST /api/chat/group
  Future<ColabGroup> addGroup({
    required String name,
    String desc = '',
    List<String> members = const [],
  }) async {
    final cleanMembers = members.map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
    print('[COLLAB PROVIDER] Creating group: name="$name", members=$cleanMembers');
    final createdGroup = await GroupRepository.createGroup(name, cleanMembers);
    print('[COLLAB PROVIDER] Group created with server id=${createdGroup.id}');

    state = [...state, createdGroup];
    return createdGroup;
  }

  /// Fetch members for a group via GET /api/chat/{id}/members
  Future<void> fetchMembersForGroup(String groupId) async {
    print('[COLLAB PROVIDER] Fetching members for group $groupId');
    try {
      final memberEmails = await GroupRepository.fetchGroupMembers(groupId);
      state = state.map((g) {
        if (g.id == groupId) {
          return g.copyWith(members: memberEmails, activeCount: memberEmails.length);
        }
        return g;
      }).toList();
      print('[COLLAB PROVIDER] Members updated for group $groupId: ${memberEmails.length}');
    } catch (e) {
      print('[COLLAB ERROR] Error fetching members for $groupId: $e');
    }
  }

  /// Add members via POST /api/chat/{id}/members
  Future<void> addMembers(String groupId, List<String> newMembers) async {
    final clean = newMembers.map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
    if (clean.isEmpty) return;

    print('[COLLAB PROVIDER] Adding members to group $groupId: $clean');
    await GroupRepository.addMembers(groupId, clean);
    await fetchMembersForGroup(groupId);
  }

  /// Fetch broadcasts for a group via GET /api/chat/{id}/broadcasts
  Future<void> fetchBroadcastsForGroup(String groupId) async {
    if (_fetchingBroadcasts.contains(groupId)) return;
    _fetchingBroadcasts.add(groupId);
    print('[COLLAB PROVIDER] Fetching broadcasts for group $groupId');
    try {
      final broadcasts = await GroupRepository.fetchBroadcasts(groupId);
      state = state.map((g) {
        if (g.id == groupId) {
          if (g.broadcasts.length == broadcasts.length &&
              g.broadcasts.isNotEmpty &&
              g.broadcasts.last.subject == broadcasts.last.subject) {
            return g;
          }
          return g.copyWith(broadcasts: broadcasts);
        }
        return g;
      }).toList();
      broadcastsLoadedIds.add(groupId);
      print('[COLLAB PROVIDER] Loaded ${broadcasts.length} broadcasts for group $groupId');
    } catch (e) {
      broadcastsLoadedIds.add(groupId); // Mark as loaded even on error to stop spinner
      print('[COLLAB ERROR] Error fetching broadcasts for $groupId: $e');
    } finally {
      _fetchingBroadcasts.remove(groupId);
    }
  }

  /// Send broadcast via POST /api/chat/{id}/broadcast
  Future<void> addBroadcast(
    String groupId, {
    required String sender,
    required String subject,
    required String body,
    List<AttachmentModel> attachments = const [],
  }) async {
    print('[COLLAB PROVIDER] Sending broadcast to group $groupId | subject="$subject"');
    await GroupRepository.sendBroadcast(groupId, subject, body);
    print('[COLLAB PROVIDER] Broadcast sent successfully.');
    await fetchBroadcastsForGroup(groupId);
  }

  /// Leave group via POST /api/chat/{chatId}/leave
  /// On success, removes group from state. Throws on failure.
  Future<void> leaveGroup(String groupId) async {
    print('[COLLAB PROVIDER] Leaving group $groupId');
    // Call backend — throws on failure
    await GroupRepository.leaveGroup(groupId);
    state = state.where((group) => group.id != groupId).toList();
    print('[COLLAB PROVIDER] Left group $groupId');
  }

  /// Delete group via DELETE /api/chat/{chatId}
  /// On success, removes group from state. Throws on failure.
  Future<void> deleteGroup(String groupId) async {
    print('[COLLAB PROVIDER] Deleting group $groupId');
    // Call backend — throws on failure
    await GroupRepository.deleteGroup(groupId);
    state = state.where((group) => group.id != groupId).toList();
    print('[COLLAB PROVIDER] Deleted group $groupId');
  }

  /// Rename group via PATCH /api/chat/{chatId}/name
  /// On success, updates group name in state. Throws on failure.
  Future<void> renameGroup(String groupId, String newName) async {
    print('[COLLAB PROVIDER] Renaming group $groupId to "$newName"');
    // Call backend — throws on failure
    await GroupRepository.renameGroup(groupId, newName);
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(name: newName);
      }
      return group;
    }).toList();
    print('[COLLAB PROVIDER] Renamed group $groupId');
  }

  /// Fetch chat messages/comments for a group via GET /api/chat/{id}/messages
  Future<void> fetchMessagesForGroup(String groupId) async {
    if (_fetchingMessages.contains(groupId)) return;
    _fetchingMessages.add(groupId);
    print('[COLLAB PROVIDER] Fetching messages for group $groupId');
    try {
      final rawList = await GroupRepository.fetchMessageHistory(groupId);
      final comments = rawList.map((raw) {
        final sender = raw['sender']?.toString() ?? raw['from']?.toString() ?? 'Unknown';
        final message = raw['content']?.toString() ?? raw['message']?.toString() ?? '';
        final timestampStr = raw['timestamp']?.toString() ?? raw['createdAt']?.toString() ?? '';
        final timestamp = DateTime.tryParse(timestampStr) ?? DateTime.now();
        final rawAtt = raw['attachmentsJson'] ?? raw['attachments'];
        final attachments = GroupRepository.parseAttachments(rawAtt);
        return ColabComment(
          sender: sender,
          message: message,
          timestamp: timestamp,
          attachments: attachments,
        );
      }).toList();

      state = state.map((g) {
        if (g.id == groupId) {
          // If length and last message match, don't re-emit state unnecessarily to avoid glitching
          if (g.comments.length == comments.length &&
              g.comments.isNotEmpty &&
              g.comments.last.message == comments.last.message &&
              g.comments.last.sender == comments.last.sender &&
              g.comments.last.attachments.length == comments.last.attachments.length) {
            return g;
          }
          return g.copyWith(comments: comments);
        }
        return g;
      }).toList();
      messagesLoadedIds.add(groupId);
      print('[COLLAB PROVIDER] Loaded ${comments.length} messages for group $groupId');
    } catch (e) {
      messagesLoadedIds.add(groupId); // Mark as loaded even on error to stop spinner
      print('[COLLAB ERROR] Error fetching messages for $groupId: $e');
    } finally {
      _fetchingMessages.remove(groupId);
    }
  }

  /// Send chat message to group via POST /api/chat/message
  Future<void> sendChatMessage(
    String groupId,
    String senderEmail,
    String text, {
    List<AttachmentModel> attachments = const [],
  }) async {
    print('[COLLAB PROVIDER] Sending chat message to group $groupId | sender=$senderEmail | attachments=${attachments.length}');
    try {
      final jsonStr = jsonEncode(attachments.map((a) => a.toJson()).toList());
      await GroupRepository.sendChatMessage(
        chatId: groupId,
        sender: senderEmail,
        message: text,
        attachmentsJson: jsonStr,
      );
      // Refresh message history from server after sending
      await fetchMessagesForGroup(groupId);
    } catch (e) {
      print('[COLLAB ERROR] Failed to send message to $groupId: $e');
      addComment(groupId, senderEmail, text);
      rethrow;
    }
  }

  /// Local-only: mark group as read (no backend call needed)
  void markAsRead(String groupId) {
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(unread: false);
      }
      return group;
    }).toList();
  }

  /// Local-only: add comment (no backend endpoint for comments)
  void addComment(String groupId, String sender, String message) {
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(
          comments: [
            ...group.comments,
            ColabComment(
              sender: sender,
              message: message,
              timestamp: DateTime.now(),
            ),
          ],
        );
      }
      return group;
    }).toList();
  }
}

// ── Invitations Provider ──────────────────────────────────────────────────

class ColabInvitationsNotifier extends StateNotifier<List<ColabInvitation>> {
  ColabInvitationsNotifier() : super([]) {
    loadInvitations();
  }

  bool _loading = false;
  final Map<String, List<ColabInvitation>> _accountCaches = {};
  String _currentAccountId = 'default';

  void clear() {
    state = [];
    _accountCaches.clear();
  }

  Future<void> switchAccountContext(String accountId) async {
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
    }
    _currentAccountId = accountId;
    if (_accountCaches.containsKey(accountId)) {
      state = _accountCaches[accountId]!;
      loadInvitations(); // Background fetch
    } else {
      state = [];
      loadInvitations();
    }
  }

  /// Fetch invitations from GET /api/chat/invitations
  Future<void> loadInvitations() async {
    if (_loading) return;
    _loading = true;
    print('[COLLAB PROVIDER] Loading invitations...');
    try {
      final invitations = await GroupRepository.fetchInvitations();
      state = invitations;
      print('[COLLAB PROVIDER] Invitations loaded. Count: ${invitations.length}');
    } catch (e) {
      print('[COLLAB ERROR] Failed to load invitations: $e');
    } finally {
      _loading = false;
    }
  }

  /// Accept invitation via POST /api/chat/invitations/{id}/accept
  /// On success, refreshes invitations. Throws on failure.
  Future<void> acceptInvitation(String invitationId) async {
    print('[COLLAB PROVIDER] Accepting invitation $invitationId');
    // Call backend — throws on failure
    await GroupRepository.acceptInvitation(invitationId);
    print('[COLLAB PROVIDER] Invitation $invitationId accepted.');
    // Refresh invitations from server
    await loadInvitations();
  }

  /// Reject invitation via POST /api/chat/invitations/{id}/reject
  /// On success, refreshes invitations. Throws on failure.
  Future<void> rejectInvitation(String invitationId) async {
    print('[COLLAB PROVIDER] Rejecting invitation $invitationId');
    // Call backend — throws on failure
    await GroupRepository.rejectInvitation(invitationId);
    print('[COLLAB PROVIDER] Invitation $invitationId rejected.');
    // Refresh invitations from server
    await loadInvitations();
  }
}

// ── Provider Declarations ─────────────────────────────────────────────────

final colabListProvider =
    StateNotifierProvider<ColabListNotifier, List<ColabGroup>>((ref) {
      return ColabListNotifier();
    });

final selectedColabIdProvider = StateProvider<String?>((ref) => null);
final selectedCasboxThreadProvider = StateProvider<String?>((ref) => null);

final colabInvitationsProvider =
    StateNotifierProvider<ColabInvitationsNotifier, List<ColabInvitation>>((ref) {
      return ColabInvitationsNotifier();
    });


// ── Casbox Message Models & Notifiers (UNTOUCHED) ──────────────────────────

class CasboxMessage {
  final String id;
  final String sender;
  final String to;
  final String subject;
  final String body;
  final DateTime timestamp;
  final bool isStarred;
  final bool isRead;
  final String status;
  final List<AttachmentModel> attachments;

  CasboxMessage({
    required this.id,
    required this.sender,
    required this.to,
    required this.subject,
    required this.body,
    required this.timestamp,
    this.isStarred = false,
    this.isRead = false,
    this.status = 'PENDING',
    this.attachments = const [],
  });

  CasboxMessage copyWith({
    String? id,
    String? sender,
    String? to,
    String? subject,
    String? body,
    DateTime? timestamp,
    bool? isStarred,
    bool? isRead,
    String? status,
    List<AttachmentModel>? attachments,
  }) {
    return CasboxMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      to: to ?? this.to,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isStarred: isStarred ?? this.isStarred,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
    );
  }

  static String? _parseEmailString(dynamic val) {
    if (val == null) return null;
    if (val is Map) {
      return val['email']?.toString() ?? val['username']?.toString() ?? val['name']?.toString() ?? val.toString();
    }
    if (val is List && val.isNotEmpty) {
      return _parseEmailString(val.first);
    }
    return val.toString();
  }

  static DateTime _parseTimestamp(dynamic rawDate) {
    if (rawDate == null) return DateTime.now();

    if (rawDate is num) {
      final int val = rawDate.toInt();
      if (val > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true).toLocal();
      } else if (val > 100000000) {
        return DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true).toLocal();
      }
    }

    String str = rawDate.toString().trim();
    if (str.isEmpty) return DateTime.now();

    final numVal = num.tryParse(str);
    if (numVal != null) {
      final int val = numVal.toInt();
      if (val > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true).toLocal();
      } else if (val > 100000000) {
        return DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true).toLocal();
      }
    }

    if (str.contains(' ') && !str.contains('T')) {
      str = str.replaceAll(' ', 'T');
    }

    if (!str.endsWith('Z') && !str.contains('+') && !RegExp(r'-\d{2}:?\d{2}$').hasMatch(str)) {
      str = '${str}Z';
    }

    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return parsed.toLocal();
    }

    final fallback = DateTime.tryParse(rawDate.toString().trim());
    if (fallback != null) {
      return fallback.toLocal();
    }

    return DateTime.now();
  }

  factory CasboxMessage.fromJson(Map<String, dynamic> json) {
    final rawDate = json['timestamp'] ??
        json['createdAt'] ??
        json['createdDate'] ??
        json['date'] ??
        json['sentAt'] ??
        json['sentDate'] ??
        json['time'] ??
        json['updatedAt'];
    final date = _parseTimestamp(rawDate);

    List<AttachmentModel> attachments = [];
    if (json['attachmentsJson'] != null) {
      final rawAttachJson = json['attachmentsJson'].toString().trim();
      if (rawAttachJson.isNotEmpty && rawAttachJson != 'null') {
        try {
          final decoded = jsonDecode(rawAttachJson);
          if (decoded is List) {
            attachments = decoded
                .whereType<Map>()
                .map((a) =>
                    AttachmentModel.fromJson(Map<String, dynamic>.from(a)))
                .toList();
          }
        } catch (_) {}
      }
    }
    if (attachments.isEmpty) {
      final rawAttachments = json['attachments'] as List<dynamic>? ?? [];
      attachments = rawAttachments
          .whereType<Map>()
          .map((a) =>
              AttachmentModel.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    }

    final rawStatus = (json['status']?.toString() ?? 'SENT').trim().toUpperCase();
    final isReadMsg = (json['isRead'] as bool? ?? false) ||
        rawStatus == 'SEEN' ||
        rawStatus == 'READ' ||
        rawStatus == 'ACCEPTED';

    return CasboxMessage(
      id:
          json['id']?.toString() ??
          json['threadId']?.toString() ??
          json['_id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      sender:
          _parseEmailString(json['senderEmail'] ?? json['sender'] ?? json['contactEmail'] ?? json['from'] ?? json['userEmail']) ??
          'Support',
      to: _parseEmailString(json['receiverEmail'] ?? json['to'] ?? json['recipient'] ?? json['contactEmail']) ?? '',
      subject: json['subject']?.toString() ?? '(No Subject)',
      body:
          json['body']?.toString() ??
          json['message']?.toString() ??
          json['content']?.toString() ??
          json['text']?.toString() ??
          '',
      timestamp: date,
      isStarred: json['isStarred'] as bool? ?? false,
      isRead: isReadMsg,
      status: rawStatus,
      attachments: attachments,
    );
  }

  factory CasboxMessage.fromEmailModel(EmailModel e) {
    return CasboxMessage(
      id: e.id,
      sender: e.senderEmail.isNotEmpty ? e.senderEmail : e.senderName,
      to: e.recipient,
      subject: e.subject.isEmpty ? '(No Subject)' : e.subject,
      body: e.body,
      timestamp: e.date,
      isStarred: e.isStarred,
      isRead: e.isRead,
      status: e.isSent ? 'SENT' : 'RESOLVED',
      attachments: e.attachments,
    );
  }
}

class CasboxMessagesNotifier extends StateNotifier<List<CasboxMessage>> {
  CasboxMessagesNotifier() : super(const []) {
    fetchMessages();
  }

  bool isLoading = false;
  final Set<String> _readIds = {};
  final Map<String, List<CasboxMessage>> _accountCaches = {};
  String _currentAccountId = 'default';

  void clear() {
    state = const [];
    _readIds.clear();
    _accountCaches.clear();
  }

  Future<void> switchAccountContext(String accountId) async {
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
    }
    _currentAccountId = accountId;
    if (_accountCaches.containsKey(accountId)) {
      state = _accountCaches[accountId]!;
      fetchMessages(); // Background fetch
    } else {
      state = const [];
      fetchMessages();
    }
  }

  bool _isAcceptedStatus(String status) {
    final s = status.trim().toUpperCase();
    if (s == 'PENDING' || s == 'REQUEST' || s == 'REJECTED') return false;
    return true;
  }

  Future<void> fetchMessages([List<EmailModel>? mailboxEmails]) async {
    isLoading = true;
    CasboxRepository.markAllDelivered();
    final acceptedIds = await TokenService.getAcceptedCasboxIds();
    final rejectedIds = await TokenService.getRejectedCasboxIds();
    final acceptedSenders = await TokenService.getAcceptedCasboxSenders();
    final rejectedSenders = await TokenService.getRejectedCasboxSenders();
    final readIds = await TokenService.getReadCasboxIds();

    final fetched = await CasboxRepository.fetchCasbox();
    print('[DIAGNOSTIC] fetchMessages() retrieved ${fetched.length} messages from server.');

    final Set<String> allAcceptedSenders = {...acceptedSenders};
    final Set<String> allRejectedSenders = {...rejectedSenders};

    for (final rawMsg in fetched) {
      final senderEmail = rawMsg.sender.trim().toLowerCase();
      if (_isAcceptedStatus(rawMsg.status) || acceptedIds.contains(rawMsg.id)) {
        if (senderEmail.isNotEmpty) {
          allAcceptedSenders.add(senderEmail);
        }
      } else if (rawMsg.status.toUpperCase() == 'REJECTED' || rejectedIds.contains(rawMsg.id)) {
        if (senderEmail.isNotEmpty) {
          allRejectedSenders.add(senderEmail);
        }
      }
    }

    final merged = <String, CasboxMessage>{};

    for (final rawMsg in fetched) {
      final senderEmail = rawMsg.sender.trim().toLowerCase();
      if (allRejectedSenders.contains(senderEmail) || rejectedIds.contains(rawMsg.id)) {
        continue;
      }

      var m = rawMsg;

      final isAcceptedContact = allAcceptedSenders.contains(senderEmail) ||
          acceptedIds.contains(m.id) ||
          _isAcceptedStatus(m.status);

      if (isAcceptedContact) {
        if (m.status.toUpperCase() == 'PENDING' || m.status.toUpperCase() == 'REQUEST') {
          m = m.copyWith(status: 'ACCEPTED');
        }
      } else {
        m = m.copyWith(status: 'PENDING');
      }

      merged[m.id] = m;
    }

    if (merged.isEmpty && mailboxEmails != null && mailboxEmails.isNotEmpty) {
      final casboxTaggedEmails = mailboxEmails.where((e) {
        final sub = e.subject.toLowerCase();
        return e.labels.any((l) => l.toLowerCase() == 'casbox') ||
            e.memberOfFolders.contains('Casbox') ||
            sub.contains('casbox');
      }).toList();

      for (final e in casboxTaggedEmails) {
        final msgSender = e.senderEmail.trim().toLowerCase();
        if (allRejectedSenders.contains(msgSender) || rejectedIds.contains(e.id)) continue;
        var msg = CasboxMessage.fromEmailModel(e);

        final isAcceptedContact = allAcceptedSenders.contains(msgSender) ||
            acceptedIds.contains(msg.id) ||
            _isAcceptedStatus(msg.status);

        if (isAcceptedContact) {
          if (msg.status.toUpperCase() == 'PENDING' || msg.status.toUpperCase() == 'REQUEST') {
            msg = msg.copyWith(status: 'ACCEPTED');
          }
        } else {
          msg = msg.copyWith(status: 'PENDING');
        }
        merged[msg.id] = msg;
      }
    }

    state = merged.values
        .where((m) =>
            !allRejectedSenders.contains(m.sender.trim().toLowerCase()) &&
            !rejectedIds.contains(m.id) &&
            m.status.toUpperCase() != 'REJECTED')
        .map((m) {
          final isRead = m.isRead ||
              m.status.toUpperCase() == 'READ' ||
              m.status.toUpperCase() == 'SEEN' ||
              readIds.contains(m.id) ||
              _readIds.contains(m.id);
          return m.copyWith(isRead: isRead);
        })
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    print('[DIAGNOSTIC] fetchMessages() updated state. Total stored messages: ${state.length}');
    isLoading = false;
  }

  Future<void> fetchThreadMessages(String contactEmail) async {
    final threadMsgs = await CasboxRepository.fetchThread(contactEmail);
    print('[DIAGNOSTIC] fetchThreadMessages($contactEmail) retrieved ${threadMsgs.length} messages.');
    
    final merged = <String, CasboxMessage>{};
    for (final m in state) {
      merged[m.id] = m;
    }
    
    for (final m in threadMsgs) {
      final matchedLocal = state.firstWhere(
        (local) => local.id.startsWith('local_') && 
                   local.body == m.body && 
                   local.to.toLowerCase().trim() == m.to.toLowerCase().trim(),
        orElse: () => m,
      );
      if (matchedLocal.id.startsWith('local_')) {
        merged.remove(matchedLocal.id);
      }
      merged[m.id] = m;
    }
    
    state = merged.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    print('[DIAGNOSTIC] fetchThreadMessages($contactEmail) updated state. Total stored messages: ${state.length}');
  }

  Future<void> addMessage({
    required String to,
    required String subject,
    required String body,
    List<AttachmentModel> attachments = const [],
  }) async {
    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final userName = await TokenService.getUserName() ?? 'Me';
    final userEmail = await TokenService.getUserEmail() ?? '';

    final localMsg = CasboxMessage(
      id: tempId,
      sender: userEmail.isNotEmpty ? userEmail : userName,
      to: to,
      subject: subject.isEmpty ? '(No Subject)' : subject,
      body: body,
      timestamp: DateTime.now(),
      attachments: attachments,
      status: 'PENDING',
    );

    state = [localMsg, ...state];

    try {
      final res = await CasboxRepository.sendCasboxMessage(
        contactEmail: to,
        message: body,
        subject: subject,
        attachments: attachments,
      );
      final serverId = res['id']?.toString() ?? res['messageId']?.toString() ?? res['data']?['id']?.toString();
      state = state.map((m) {
        if (m.id == tempId) {
          return CasboxMessage(
            id: serverId ?? m.id,
            sender: m.sender,
            to: m.to,
            subject: m.subject,
            body: m.body,
            timestamp: m.timestamp,
            isStarred: m.isStarred,
            isRead: m.isRead,
            status: 'SENT',
            attachments: m.attachments,
          );
        }
        return m;
      }).toList();
      
      await fetchMessages();
      await fetchThreadMessages(to);
    } catch (e) {
      print('[CASBOX ERROR] Failed to send via backend API: $e');
      state = state.map((m) {
        if (m.id == tempId) {
          return CasboxMessage(
            id: m.id,
            sender: m.sender,
            to: m.to,
            subject: m.subject,
            body: m.body,
            timestamp: m.timestamp,
            isStarred: m.isStarred,
            isRead: m.isRead,
            status: 'FAILED',
            attachments: m.attachments,
          );
        }
        return m;
      }).toList();
      rethrow;
    }
  }

  Future<void> updateStatus(dynamic threadId, String status) async {
    state = state.map((m) {
      if (m.id == threadId.toString()) {
        return m.copyWith(status: status);
      }
      return m;
    }).toList();
    try {
      await CasboxRepository.updateStatus(threadId, status);
    } catch (e) {
      print('[CASBOX WARNING] updateStatus failed: $e');
    }
  }

  Future<void> acceptRequest(dynamic threadId) async {
    final strId = threadId.toString();
    await TokenService.saveAcceptedCasboxId(strId);

    CasboxMessage? target;
    for (final m in state) {
      if (m.id == strId) {
        target = m;
        break;
      }
    }

    final senderEmail = target?.sender.trim().toLowerCase() ?? '';
    if (senderEmail.isNotEmpty) {
      await TokenService.saveAcceptedCasboxSender(senderEmail);
      try {
        final currentAccepted = await CasboxRepository.getAuthorizedContacts();
        if (!currentAccepted.contains(senderEmail)) {
          await CasboxRepository.updateAuthorizedContacts([...currentAccepted, senderEmail]);
        }
      } catch (_) {}
    }

    final idsToAccept = <dynamic>[];
    state = state.map((m) {
      final mSender = m.sender.trim().toLowerCase();
      if (m.id == strId || (senderEmail.isNotEmpty && mSender == senderEmail)) {
        idsToAccept.add(m.id);
        return m.copyWith(status: 'ACCEPTED');
      }
      return m;
    }).toList();

    for (final id in idsToAccept) {
      try {
        await CasboxRepository.updateStatus(id, 'ACCEPTED');
      } catch (e) {
        print('[CASBOX WARNING] acceptRequest failed for $id: $e');
      }
    }
  }

  Future<void> rejectRequest(dynamic threadId) async {
    final strId = threadId.toString();
    await TokenService.saveRejectedCasboxId(strId);

    CasboxMessage? target;
    for (final m in state) {
      if (m.id == strId) {
        target = m;
        break;
      }
    }

    final senderEmail = target?.sender.trim().toLowerCase() ?? '';
    if (senderEmail.isNotEmpty) {
      await TokenService.saveRejectedCasboxSender(senderEmail);
      try {
        final currentAccepted = await CasboxRepository.getAuthorizedContacts();
        if (currentAccepted.contains(senderEmail)) {
          final updated = currentAccepted.where((e) => e != senderEmail).toList();
          await CasboxRepository.updateAuthorizedContacts(updated);
        }
      } catch (_) {}
    }

    final idsToReject = <dynamic>[];
    state = state.where((m) {
      final mSender = m.sender.trim().toLowerCase();
      if (m.id == strId || (senderEmail.isNotEmpty && mSender == senderEmail)) {
        idsToReject.add(m.id);
        return false;
      }
      return true;
    }).toList();

    for (final id in idsToReject) {
      try {
        await CasboxRepository.updateStatus(id, 'REJECTED');
      } catch (e) {
        print('[CASBOX WARNING] rejectRequest failed for $id: $e');
      }
    }
  }

  Future<void> markDelivered(dynamic messageId) async {
    await CasboxRepository.markDelivered(messageId);
  }

  void deleteMessage(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void markAsRead(dynamic messageId) {
    final strId = messageId.toString();
    _readIds.add(strId);
    TokenService.markCasboxRead(strId);
    state = state.map((m) {
      if (m.id == strId) {
        return m.copyWith(isRead: true, status: 'SEEN');
      }
      return m;
    }).toList();
    try {
      CasboxRepository.updateStatus(strId, 'SEEN');
    } catch (e) {
      print('[CASBOX WARNING] markAsRead failed: $e');
    }
  }

  void markThreadAsSeen(String contactEmail) {
    final cleanContact = contactEmail.trim().toLowerCase();
    final idsToMark = <dynamic>[];
    state = state.map((m) {
      final isFromContact = m.sender.trim().toLowerCase() == cleanContact;
      if (isFromContact && (!m.isRead || m.status.toUpperCase() != 'SEEN')) {
        idsToMark.add(m.id);
        _readIds.add(m.id);
        TokenService.markCasboxRead(m.id);
        return m.copyWith(isRead: true, status: 'SEEN');
      }
      return m;
    }).toList();

    if (idsToMark.isNotEmpty) {
      try {
        CasboxRepository.updateMessagesStatus(idsToMark, 'SEEN');
      } catch (e) {
        print('[CASBOX WARNING] markThreadAsSeen failed: $e');
      }
    }
  }

  void toggleStar(String id) {
    state = state.map((m) {
      if (m.id == id) {
        return CasboxMessage(
          id: m.id,
          sender: m.sender,
          to: m.to,
          subject: m.subject,
          body: m.body,
          timestamp: m.timestamp,
          isStarred: !m.isStarred,
          isRead: m.isRead,
          status: m.status,
          attachments: m.attachments,
        );
      }
      return m;
    }).toList();
  }
}

final casboxMessagesProvider =
    StateNotifierProvider<CasboxMessagesNotifier, List<CasboxMessage>>((ref) {
      return CasboxMessagesNotifier();
    });
