import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attachment_model.dart';
import '../models/email_model.dart';
import 'repositories/casbox_repository.dart';
import 'repositories/group_repository.dart';
import '../core/network/token_service.dart';
import '../core/network/api_client.dart';

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
  final bool isArchived;
  final bool isStarred;

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
    this.isArchived = false,
    this.isStarred = false,
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
    bool? isArchived,
    bool? isStarred,
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
      isArchived: isArchived ?? this.isArchived,
      isStarred: isStarred ?? this.isStarred,
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

  Set<String> _archivedGroupIds = {};
  Set<String> _starredGroupIds = {};

  /// Fetch all groups from GET /api/chat/user/{email}
  Future<void> loadGroups([String? userEmail]) async {
    if (_loading) return;
    _loading = true;
    print('[COLLAB PROVIDER] Loading groups from backend...');
    try {
      final email = (userEmail != null && userEmail.trim().isNotEmpty)
          ? userEmail.trim()
          : (await TokenService.getUserEmail() ?? '');
      _archivedGroupIds = await TokenService.getArchivedColabGroupIds(email);
      _starredGroupIds = await TokenService.getStarredColabGroupIds(email);
      final fetchedGroups = await GroupRepository.fetchGroups(email);

      // Preserve existing comments & broadcasts for groups already in state to avoid message reset glitches
      final Map<String, ColabGroup> existingMap = {
        for (final g in state) g.id: g
      };

      final updatedGroups = fetchedGroups.map((newG) {
        final existing = existingMap[newG.id];
        final isArchived = _archivedGroupIds.contains(newG.id);
        final isStarred = _starredGroupIds.contains(newG.id);
        if (existing != null) {
          return newG.copyWith(
            comments: existing.comments.isNotEmpty ? existing.comments : newG.comments,
            broadcasts: existing.broadcasts.isNotEmpty ? existing.broadcasts : newG.broadcasts,
            members: newG.members.isNotEmpty ? newG.members : existing.members,
            isArchived: isArchived,
            isStarred: isStarred,
          );
        }
        return newG.copyWith(isArchived: isArchived, isStarred: isStarred);
      }).toList();

      state = updatedGroups;
      print('[COLLAB PROVIDER] Groups loaded. Count: ${updatedGroups.length}');
    } catch (e) {
      print('[COLLAB ERROR] Failed to load groups: $e');
    } finally {
      _loading = false;
    }
  }

  /// Toggle archive status for a Colab group
  Future<void> toggleArchiveGroup(String groupId) async {
    final currentGroup = state.firstWhere(
      (g) => g.id == groupId,
      orElse: () => ColabGroup(id: groupId, name: '', members: const []),
    );
    final willArchive = !currentGroup.isArchived;
    if (willArchive) {
      _archivedGroupIds.add(groupId);
    } else {
      _archivedGroupIds.remove(groupId);
    }
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isArchived: willArchive);
      }
      return g;
    }).toList();
    final userEmail = await TokenService.getUserEmail() ?? '';
    await TokenService.saveArchivedColabGroupIds(_archivedGroupIds, userEmail);
    print('[COLAB ARCHIVE] Toggled archive for group $groupId, willArchive=$willArchive. Total archived groups: ${_archivedGroupIds.length}');
  }

  /// Toggle star status for a Colab group
  Future<void> toggleStarGroup(String groupId) async {
    final currentGroup = state.firstWhere(
      (g) => g.id == groupId,
      orElse: () => ColabGroup(id: groupId, name: '', members: const []),
    );
    final willStar = !currentGroup.isStarred;
    if (willStar) {
      _starredGroupIds.add(groupId);
    } else {
      _starredGroupIds.remove(groupId);
    }
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isStarred: willStar);
      }
      return g;
    }).toList();
    final userEmail = await TokenService.getUserEmail() ?? '';
    await TokenService.saveStarredColabGroupIds(_starredGroupIds, userEmail);

    // Call Star APIs for backend sync
    print('[COLAB STAR] Toggling star for group $groupId, willStar=$willStar');
    try {
      await ApiClient.patch('/api/casbox/$groupId/star', body: {'starred': willStar});
    } catch (_) {
      try {
        await ApiClient.post('/api/casbox/$groupId/star', body: {'starred': willStar});
      } catch (_) {
        try {
          await ApiClient.patch('/api/chat/$groupId/star', body: {'starred': willStar});
          print('[COLAB STAR] PATCH /api/chat/$groupId/star succeeded');
        } catch (e) {
          print('[COLAB STAR] PATCH /api/chat/$groupId/star failed: $e, trying POST...');
          try {
            await ApiClient.post('/api/chat/$groupId/star', body: {'starred': willStar});
            print('[COLAB STAR] POST /api/chat/$groupId/star succeeded');
          } catch (e2) {
            print('[COLAB STAR] POST also failed: $e2, relying on local persistence');
          }
        }
      }
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
  final bool isArchived;
  final bool isEdited;
  final String? contactDisplayName;
  final String? contactUsername;

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
    this.isArchived = false,
    this.isEdited = false,
    this.contactDisplayName,
    this.contactUsername,
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
    bool? isArchived,
    bool? isEdited,
    String? contactDisplayName,
    String? contactUsername,
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
      isArchived: isArchived ?? this.isArchived,
      isEdited: isEdited ?? this.isEdited,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      contactUsername: contactUsername ?? this.contactUsername,
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

  factory CasboxMessage.fromJson(Map<String, dynamic> json, [String? currentUserEmail]) {
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

    bool toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1';
    }

    final rawStatus = (json['status']?.toString() ?? 'SENT').trim().toUpperCase();
    final isReadMsg = toBool(json['isRead']) ||
        rawStatus == 'SEEN' ||
        rawStatus == 'READ' ||
        rawStatus == 'ACCEPTED';

    final sEmail = _parseEmailString(json['senderEmail'] ?? json['sender'] ?? json['contactEmail'] ?? json['from'] ?? json['userEmail'])?.toLowerCase().trim() ?? '';
    final rEmail = _parseEmailString(json['receiverEmail'] ?? json['to'] ?? json['recipient'] ?? json['contactEmail'])?.toLowerCase().trim() ?? '';
    final curEmail = (currentUserEmail ?? json['currentUserEmail'] ?? json['currentEmail'])?.toString().toLowerCase().trim() ?? '';

    final sHandle = sEmail.contains('@') ? sEmail.split('@').first : sEmail;
    final rHandle = rEmail.contains('@') ? rEmail.split('@').first : rEmail;
    final curHandle = curEmail.contains('@') ? curEmail.split('@').first : curEmail;

    final isSender = curEmail.isNotEmpty && (curEmail == sEmail || (curHandle.isNotEmpty && curHandle == sHandle));
    final isReceiver = curEmail.isNotEmpty && (curEmail == rEmail || (curHandle.isNotEmpty && curHandle == rHandle));

    final senderArchivedVal = json['senderArchived'] ?? json['sender_archived'];
    final receiverArchivedVal = json['receiverArchived'] ?? json['receiver_archived'];
    final hasSenderArchived = senderArchivedVal != null;
    final hasReceiverArchived = receiverArchivedVal != null;

    final bool isArchivedMsg;
    if (isSender && hasSenderArchived) {
      isArchivedMsg = toBool(senderArchivedVal);
    } else if (isReceiver && hasReceiverArchived) {
      isArchivedMsg = toBool(receiverArchivedVal);
    } else if (curEmail.isNotEmpty && (hasSenderArchived || hasReceiverArchived)) {
      if (json.containsKey('isArchived') && json['isArchived'] != null) {
        isArchivedMsg = toBool(json['isArchived']);
      } else if (json.containsKey('is_archived') && json['is_archived'] != null) {
        isArchivedMsg = toBool(json['is_archived']);
      } else {
        isArchivedMsg = toBool(senderArchivedVal) || toBool(receiverArchivedVal);
      }
    } else if (hasSenderArchived && hasReceiverArchived) {
      if (toBool(senderArchivedVal) && toBool(receiverArchivedVal)) {
        isArchivedMsg = true;
      } else if (json.containsKey('isArchived') && json['isArchived'] != null) {
        isArchivedMsg = toBool(json['isArchived']);
      } else if (json.containsKey('is_archived') && json['is_archived'] != null) {
        isArchivedMsg = toBool(json['is_archived']);
      } else {
        isArchivedMsg = toBool(senderArchivedVal) || toBool(receiverArchivedVal);
      }
    } else if (json.containsKey('isArchived') && json['isArchived'] != null) {
      isArchivedMsg = toBool(json['isArchived']);
    } else if (json.containsKey('is_archived') && json['is_archived'] != null) {
      isArchivedMsg = toBool(json['is_archived']);
    } else if (json.containsKey('archived') && json['archived'] != null) {
      isArchivedMsg = toBool(json['archived']);
    } else {
      isArchivedMsg = false;
    }

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
      isStarred: toBool(json['isStarred']),
      isRead: isReadMsg,
      status: rawStatus,
      attachments: attachments,
      isArchived: isArchivedMsg,
      isEdited: toBool(json['isEdited']) || toBool(json['edited']),
      contactDisplayName: json['contactDisplayName']?.toString() ??
          json['customName']?.toString() ??
          json['senderDisplayName']?.toString() ??
          json['receiverDisplayName']?.toString(),
      contactUsername: json['contactUsername']?.toString() ??
          json['senderUsername']?.toString() ??
          json['receiverUsername']?.toString(),
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
  final Set<String> _explicitlyArchivedIds = {};
  final Set<String> _explicitlyUnarchivedIds = {};
  final Map<String, List<CasboxMessage>> _accountCaches = {};
  String _currentAccountId = 'default';

  void clear() {
    state = const [];
    _readIds.clear();
    _explicitlyArchivedIds.clear();
    _explicitlyUnarchivedIds.clear();
    _accountCaches.clear();
  }

  Future<void> switchAccountContext(String accountId) async {
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
    }
    _currentAccountId = accountId;
    _explicitlyArchivedIds.clear();
    _explicitlyUnarchivedIds.clear();
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
    final userEmail = await TokenService.getUserEmail() ?? '';
    final acceptedIds = await TokenService.getAcceptedCasboxIds();
    final rejectedIds = await TokenService.getRejectedCasboxIds();
    final acceptedSenders = await TokenService.getAcceptedCasboxSenders();
    final rejectedSenders = await TokenService.getRejectedCasboxSenders();
    final readIds = await TokenService.getReadCasboxIds();
    final persistentArchivedIds = await TokenService.getArchivedCasboxIds(userEmail);
    final persistentUnarchivedIds = await TokenService.getUnarchivedCasboxIds(userEmail);

    final fetched = await CasboxRepository.fetchCasbox(userEmail);
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

          bool isArchived = m.isArchived;
          if (_explicitlyUnarchivedIds.contains(m.id) || persistentUnarchivedIds.contains(m.id)) {
            isArchived = false;
          } else if (_explicitlyArchivedIds.contains(m.id) || persistentArchivedIds.contains(m.id)) {
            isArchived = true;
          }

          return m.copyWith(isRead: isRead, isArchived: isArchived);
        })
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    print('[DIAGNOSTIC] fetchMessages() updated state. Total stored messages: ${state.length}');
    isLoading = false;
  }

  Future<void> fetchThreadMessages(String contactEmail) async {
    final userEmail = await TokenService.getUserEmail() ?? '';
    final threadMsgs = await CasboxRepository.fetchThread(contactEmail, userEmail);
    final persistentArchived = await TokenService.getArchivedCasboxIds(userEmail);
    final persistentUnarchived = await TokenService.getUnarchivedCasboxIds(userEmail);
    print('[DIAGNOSTIC] fetchThreadMessages($contactEmail) retrieved ${threadMsgs.length} messages.');
    
    final merged = <String, CasboxMessage>{};
    for (final m in state) {
      merged[m.id] = m;
    }
    
    for (final rawM in threadMsgs) {
      final matchedLocal = state.firstWhere(
        (local) => local.id.startsWith('local_') && 
                   local.body == rawM.body && 
                   local.to.toLowerCase().trim() == rawM.to.toLowerCase().trim(),
        orElse: () => rawM,
      );
      if (matchedLocal.id.startsWith('local_')) {
        merged.remove(matchedLocal.id);
      }

      bool isArchived = rawM.isArchived;
      if (_explicitlyUnarchivedIds.contains(rawM.id) || persistentUnarchived.contains(rawM.id)) {
        isArchived = false;
      } else if (_explicitlyArchivedIds.contains(rawM.id) || persistentArchived.contains(rawM.id) || (merged[rawM.id]?.isArchived ?? false)) {
        isArchived = true;
      }
      final m = rawM.copyWith(isArchived: isArchived);
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

  Future<void> archiveMessage(dynamic messageId, [bool archived = true]) async {
    final strId = messageId.toString();
    final userEmail = await TokenService.getUserEmail() ?? '';
    if (archived) {
      _explicitlyArchivedIds.add(strId);
      _explicitlyUnarchivedIds.remove(strId);
      await TokenService.saveArchivedCasboxId(strId, userEmail);
    } else {
      _explicitlyUnarchivedIds.add(strId);
      _explicitlyArchivedIds.remove(strId);
      await TokenService.removeArchivedCasboxId(strId, userEmail);
    }

    // 1. Optimistic update
    state = state.map((m) {
      if (m.id == strId) {
        return m.copyWith(isArchived: archived);
      }
      return m;
    }).toList();

    // 2. Seamlessly call backend API
    try {
      await CasboxRepository.archiveMessage(messageId, archived);
      print('[CASBOX NOTIFIER] archiveMessage backend call completed for $messageId (archived=$archived)');
    } catch (e) {
      print('[CASBOX NOTIFIER ERROR] archiveMessage backend call failed: $e');
    }

    // 3. Immediately retrieve fresh state from the backend API each time
    await fetchMessages();
  }

  Future<void> batchArchiveMessages(List<dynamic> messageIds, [bool archived = true]) async {
    if (messageIds.isEmpty) return;
    final strIds = messageIds.map((id) => id.toString()).toSet();
    final userEmail = await TokenService.getUserEmail() ?? '';
    if (archived) {
      _explicitlyArchivedIds.addAll(strIds);
      _explicitlyUnarchivedIds.removeAll(strIds);
      for (final id in strIds) {
        await TokenService.saveArchivedCasboxId(id, userEmail);
      }
    } else {
      _explicitlyUnarchivedIds.addAll(strIds);
      _explicitlyArchivedIds.removeAll(strIds);
      for (final id in strIds) {
        await TokenService.removeArchivedCasboxId(id, userEmail);
      }
    }

    // 1. Optimistic update
    state = state.map((m) {
      if (strIds.contains(m.id)) {
        return m.copyWith(isArchived: archived);
      }
      return m;
    }).toList();

    // 2. Seamlessly call backend API
    try {
      await CasboxRepository.batchArchiveMessages(messageIds, archived);
      print('[CASBOX NOTIFIER] batchArchiveMessages backend call completed for ${messageIds.length} msgs (archived=$archived)');
    } catch (e) {
      print('[CASBOX NOTIFIER ERROR] batchArchiveMessages backend call failed: $e');
    }

    // 3. Immediately retrieve fresh state from the backend API each time
    await fetchMessages();
  }

  Future<void> deleteConversation(String contactEmail) async {
    final clean = contactEmail.trim().toLowerCase();
    state = state.where((m) =>
      m.sender.trim().toLowerCase() != clean &&
      m.to.trim().toLowerCase() != clean
    ).toList();
    try {
      await CasboxRepository.deleteConversation(contactEmail);
    } catch (e) {
      print('[CASBOX WARNING] deleteConversation failed: $e');
    }
  }

  Future<void> editMessage(dynamic messageId, String newBody) async {
    final strId = messageId.toString();
    state = state.map((m) {
      if (m.id == strId) {
        return m.copyWith(body: newBody);
      }
      return m;
    }).toList();
    try {
      await CasboxRepository.editMessage(messageId, newBody);
    } catch (e) {
      print('[CASBOX WARNING] editMessage failed: $e');
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

// ── Contact Safety & Blocked Contacts Provider ────────────────────────────

class CasboxBlockedContactsNotifier extends StateNotifier<List<String>> {
  CasboxBlockedContactsNotifier() : super(const []) {
    fetchBlockedContacts();
  }

  bool isLoading = false;

  Future<void> fetchBlockedContacts() async {
    isLoading = true;
    try {
      final contacts = await CasboxRepository.getBlockedContacts();
      if (mounted) {
        state = {...state, ...contacts}.toList();
      }
    } catch (e) {
      print('[BLOCKED CONTACTS] fetch error: $e');
    } finally {
      isLoading = false;
    }
  }

  Future<void> loadBlockedContacts() => fetchBlockedContacts();

  Future<void> blockContact(String email, {String reason = 'Spam'}) async {
    final clean = email.trim().toLowerCase();
    if (!state.contains(clean)) {
      state = [...state, clean];
    }
    try {
      await CasboxRepository.blockContact(clean, reason: reason);
    } catch (e) {
      print('[BLOCKED CONTACTS] block error: $e');
    }
  }

  Future<void> unblockContact(String email) async {
    final clean = email.trim().toLowerCase();
    state = state.where((e) => e != clean).toList();
    try {
      await CasboxRepository.unblockContact(clean);
    } catch (e) {
      print('[BLOCKED CONTACTS] unblock error: $e');
    }
  }
}

final casboxBlockedContactsProvider =
    StateNotifierProvider<CasboxBlockedContactsNotifier, List<String>>((ref) {
  return CasboxBlockedContactsNotifier();
});

// ── Connections Provider ──────────────────────────────────────────────────

class CasboxConnectionsNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  CasboxConnectionsNotifier() : super(const []) {
    fetchConnections();
  }

  bool isLoading = false;

  Future<void> fetchConnections([String? userEmail]) async {
    isLoading = true;
    try {
      final myEmail = (userEmail ?? await TokenService.getUserEmail() ?? '')
          .trim()
          .toLowerCase();
      final myHandle = myEmail.contains('@') ? myEmail.split('@').first.toLowerCase() : myEmail;

      // API 12: GET /api/connections/accepted - exactly matching web Casbox.jsx
      final accepted = await CasboxRepository.getAcceptedConnections();
      final savedAccounts = await TokenService.getSavedAccountsFromRegistry();
      final merged = <String, Map<String, dynamic>>{};

      for (final c in accepted) {
        final uEmail = (c['userEmail'] ?? c['senderEmail'] ?? '').toString().trim().toLowerCase();
        final cEmail = (c['connectedUserEmail'] ?? c['receiverEmail'] ?? c['contactEmail'] ?? c['email'] ?? '').toString().trim().toLowerCase();
        final uHandle = uEmail.contains('@') ? uEmail.split('@').first.toLowerCase() : uEmail;
        final cHandle = cEmail.contains('@') ? cEmail.split('@').first.toLowerCase() : cEmail;

        String peerEmail = '';
        String peerName = '';
        dynamic peerUserId;
        bool isSender = false;

        if (myEmail.isNotEmpty && (uEmail == myEmail || uHandle == myHandle)) {
          isSender = true;
          peerEmail = cEmail;
          peerName = (c['connectedUserName'] ?? c['receiverName'] ?? c['name'] ?? '').toString();
          peerUserId = c['connectedUserId'];
        } else if (myEmail.isNotEmpty && (cEmail == myEmail || cHandle == myHandle)) {
          isSender = false;
          peerEmail = uEmail;
          peerName = (c['userName'] ?? c['senderName'] ?? c['name'] ?? '').toString();
          peerUserId = c['userId'];
        } else {
          peerEmail = cEmail.isNotEmpty ? cEmail : uEmail;
          peerName = (c['connectedUserName'] ?? c['userName'] ?? c['name'] ?? '').toString();
          peerUserId = c['connectedUserId'] ?? c['userId'];
        }

        if (peerEmail.isEmpty) continue;

        final rawHandle = peerEmail.contains('@') ? peerEmail.split('@').first : peerEmail;
        final normHandle = rawHandle.toLowerCase();

        // Never list the authenticated user as a contact to themselves!
        if (myHandle.isNotEmpty && normHandle == myHandle) continue;
        if (myEmail.isNotEmpty && peerEmail == myEmail) continue;

        final rawStatus = c['status']?.toString().toUpperCase() ?? 'CONNECTED';
        final displayName = (c['customName'] ?? peerName).toString().trim();

        // Check avatar from connection record
        String? avatarUrl;
        final rawAvatar = (isSender
                ? (c['connectedUserProfilePictureUrl'] ??
                    c['connectedUserProfilePicture'] ??
                    c['connectedUserAvatarUrl'] ??
                    c['connectedUserAvatar'] ??
                    c['receiverProfilePictureUrl'] ??
                    c['receiverAvatarUrl'])
                : (c['userProfilePictureUrl'] ??
                    c['userProfilePicture'] ??
                    c['userAvatarUrl'] ??
                    c['userAvatar'] ??
                    c['senderProfilePictureUrl'] ??
                    c['senderAvatarUrl'])) ??
            c['avatarUrl'] ??
            c['avatar'] ??
            c['profilePictureUrl'] ??
            c['profilePicture'] ??
            c['photoUrl'];

        if (rawAvatar != null &&
            rawAvatar.toString().trim().isNotEmpty &&
            rawAvatar.toString() != 'null') {
          avatarUrl = rawAvatar.toString().trim();
        }

        // Check locally saved user avatar
        if (avatarUrl == null || avatarUrl.isEmpty) {
          final localAvatar = await TokenService.getUserAvatar(peerEmail) ??
              await TokenService.getUserAvatar(normHandle);
          if (localAvatar != null &&
              localAvatar.trim().isNotEmpty &&
              localAvatar.trim() != 'null') {
            avatarUrl = localAvatar.trim();
          }
        }

        // Check saved accounts registry
        if (avatarUrl == null || avatarUrl.isEmpty) {
          for (final acc in savedAccounts) {
            final accEmail =
                (acc['email'] ?? '').toString().trim().toLowerCase();
            final accHandle =
                accEmail.contains('@') ? accEmail.split('@').first : accEmail;
            if (accEmail == peerEmail || accHandle == normHandle) {
              final av =
                  (acc['avatarUrl'] ?? acc['avatar'] ?? '').toString().trim();
              if (av.isNotEmpty && av != 'null') {
                avatarUrl = av;
                break;
              }
            }
          }
        }

        // Fallback to server user profile picture endpoint
        avatarUrl ??= '/api/users/profile-picture/$normHandle';

        // Key by normHandle so chandran123 and chandran123@bnxmail.com NEVER produce duplicates!
        final existing = merged[normHandle];
        merged[normHandle] = {
          'id': c['id'] ?? existing?['id'],
          'connectionId': c['id'] ?? existing?['connectionId'],
          'email': peerEmail,
          'contactEmail': peerEmail,
          'name': displayName.isNotEmpty ? displayName : (existing?['name'] ?? rawHandle),
          'handle': '@$rawHandle',
          'letter': rawHandle.isNotEmpty ? rawHandle[0].toUpperCase() : 'U',
          'status': rawStatus,
          'contactUserId': peerUserId ?? existing?['contactUserId'],
          'avatarUrl': avatarUrl,
          'isPhoto': avatarUrl.isNotEmpty,
        };
      }

      // If accepted connections returned empty, fallback to authorized contacts
      if (merged.isEmpty) {
        final authorized = await CasboxRepository.getAuthorizedContacts();
        for (final authEmail in authorized) {
          final clean = authEmail.trim().toLowerCase();
          if (clean.isEmpty) continue;
          final rawHandle = clean.contains('@') ? clean.split('@').first : clean;
          final normHandle = rawHandle.toLowerCase();
          if (myHandle.isNotEmpty && normHandle == myHandle) continue;
          if (myEmail.isNotEmpty && clean == myEmail) continue;

          String? avatarUrl = await TokenService.getUserAvatar(clean) ??
              await TokenService.getUserAvatar(normHandle);
          if (avatarUrl == null || avatarUrl.isEmpty) {
            for (final acc in savedAccounts) {
              final accEmail =
                  (acc['email'] ?? '').toString().trim().toLowerCase();
              final accHandle =
                  accEmail.contains('@') ? accEmail.split('@').first : accEmail;
              if (accEmail == clean || accHandle == normHandle) {
                final av =
                    (acc['avatarUrl'] ?? acc['avatar'] ?? '').toString().trim();
                if (av.isNotEmpty && av != 'null') {
                  avatarUrl = av;
                  break;
                }
              }
            }
          }
          avatarUrl ??= '/api/users/profile-picture/$normHandle';

          merged[normHandle] = {
            'id': null,
            'connectionId': null,
            'email': clean,
            'contactEmail': clean,
            'name': rawHandle,
            'handle': '@$rawHandle',
            'letter': rawHandle.isNotEmpty ? rawHandle[0].toUpperCase() : 'U',
            'status': 'CONNECTED',
            'avatarUrl': avatarUrl,
            'isPhoto': avatarUrl.isNotEmpty,
          };
        }
      }

      if (mounted) {
        state = merged.values.toList();
        print('[CASBOX CONNECTIONS] fetchConnections loaded ${state.length} unique connections (no duplicates)');
      }
    } catch (e) {
      print('[CASBOX CONNECTIONS] fetch error: $e');
    } finally {
      if (mounted) isLoading = false;
    }
  }

  Future<void> updateConnectionStatus(
      dynamic connectionIdOrEmail, String status) async {
    final strTarget = connectionIdOrEmail.toString().trim().toLowerCase();
    final newStatus = status.toUpperCase();
    dynamic numericId;
    String? contactEmail;

    state = state.map((c) {
      final cId = c['id']?.toString() ?? c['connectionId']?.toString();
      final cEmail = c['email']?.toString().toLowerCase().trim() ?? '';
      final matchesId = cId != null && cId == strTarget;
      final matchesEmail = cEmail.isNotEmpty &&
          (cEmail == strTarget ||
              (strTarget.contains('@') && cEmail == strTarget.split('@').first) ||
              (!strTarget.contains('@') && cEmail.startsWith('$strTarget@')));

      if (matchesId || matchesEmail) {
        numericId = c['id'] ?? c['connectionId'];
        contactEmail = cEmail;
        return {...c, 'status': newStatus};
      }
      return c;
    }).toList();

    if (numericId == null && int.tryParse(strTarget) != null) {
      numericId = int.parse(strTarget);
    }
    contactEmail ??= strTarget;

    if (numericId != null && int.tryParse(numericId.toString()) != null) {
      try {
        await CasboxRepository.updateConnectionStatus(numericId, newStatus);
      } catch (e) {
        print('[CASBOX CONNECTIONS] update error: $e');
      }
    }

    try {
      final currentAuth = await CasboxRepository.getAuthorizedContacts();
      final clean = contactEmail!.toLowerCase().trim();
      final updated = List<String>.from(currentAuth);
      if (newStatus == 'CONNECTED') {
        if (!updated.contains(clean)) {
          updated.add(clean);
        }
      } else {
        updated.remove(clean);
        if (clean.contains('@')) {
          updated.remove(clean.split('@').first);
        }
      }
      await CasboxRepository.updateAuthorizedContacts(updated);
    } catch (e) {
      print('[CASBOX CONNECTIONS] authorized contacts update error: $e');
    }
  }
}

final casboxConnectionsProvider =
    StateNotifierProvider<CasboxConnectionsNotifier, List<Map<String, dynamic>>>((ref) {
  return CasboxConnectionsNotifier();
});

// ── Contact Aliases Provider ──────────────────────────────────────────────

class CasboxAliasesNotifier extends StateNotifier<Map<String, String>> {
  CasboxAliasesNotifier() : super(const {}) {
    fetchAliases();
  }

  Future<void> fetchAliases() async {
    try {
      final aliases = await CasboxRepository.getContactAliases();
      if (mounted) {
        state = {...state, ...aliases};
      }
    } catch (e) {
      print('[CASBOX ALIASES] fetch error: $e');
    }
  }

  Future<void> setAlias(dynamic contactUserId, String customName) async {
    final key = contactUserId.toString();
    state = {...state, key: customName};
    try {
      await CasboxRepository.setContactAlias(contactUserId, customName);
    } catch (e) {
      print('[CASBOX ALIASES] set error: $e');
    }
  }

  Future<void> deleteAlias(dynamic contactUserId) async {
    final key = contactUserId.toString();
    final updated = Map<String, String>.from(state)..remove(key);
    state = updated;
    try {
      await CasboxRepository.deleteContactAlias(contactUserId);
    } catch (e) {
      print('[CASBOX ALIASES] delete error: $e');
    }
  }
}

final casboxAliasesProvider =
    StateNotifierProvider<CasboxAliasesNotifier, Map<String, String>>((ref) {
  return CasboxAliasesNotifier();
});
