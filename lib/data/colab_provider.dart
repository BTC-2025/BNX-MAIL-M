import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attachment_model.dart';

class ColabComment {
  final String sender;
  final String message;
  final DateTime timestamp;

  ColabComment({
    required this.sender,
    required this.message,
    required this.timestamp,
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
  final List<String> members;
  final int activeCount;
  final bool unread;
  final List<ColabBroadcast> broadcasts;
  final List<ColabComment> comments;

  ColabGroup({
    required this.id,
    required this.name,
    required this.desc,
    required this.members,
    this.activeCount = 0,
    this.unread = false,
    this.broadcasts = const [],
    this.comments = const [],
  });

  ColabGroup copyWith({
    String? id,
    String? name,
    String? desc,
    List<String>? members,
    int? activeCount,
    bool? unread,
    List<ColabBroadcast>? broadcasts,
    List<ColabComment>? comments,
  }) {
    return ColabGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      desc: desc ?? this.desc,
      members: members ?? this.members,
      activeCount: activeCount ?? this.activeCount,
      unread: unread ?? this.unread,
      broadcasts: broadcasts ?? this.broadcasts,
      comments: comments ?? this.comments,
    );
  }
}

class ColabListNotifier extends StateNotifier<List<ColabGroup>> {
  ColabListNotifier()
      : super([
          ColabGroup(
            id: '1',
            name: 'Design Overhaul Team',
            desc: 'Collaborating on the new BNXMail High-Fi Proto v3 layout styles.',
            members: ['James', 'Sarah', 'Alex', 'Ravi'],
            activeCount: 4,
            unread: true,
          ),
          ColabGroup(
            id: '2',
            name: 'Flutter Frontend Devs',
            desc: 'Implementing Riverpod notification stores and GoRouter paths.',
            members: ['Alex', 'Ravi'],
            activeCount: 2,
            unread: false,
          ),
          ColabGroup(
            id: '3',
            name: 'Marketing Q3 Launch',
            desc: 'Preparing templates and copy briefs for the upcoming public release.',
            members: ['Sarah', 'Emily', 'Kate'],
            activeCount: 1,
            unread: false,
          ),
        ]);

  ColabGroup addGroup({
    required String name,
    required List<String> members,
    String desc = 'No description provided.',
  }) {
    final newGroup = ColabGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      desc: desc,
      members: members.isEmpty ? ['Ravi'] : (members.contains('Ravi') ? members : [...members, 'Ravi']),
      activeCount: members.length + 1,
      unread: false,
      broadcasts: [],
      comments: [],
    );
    state = [...state, newGroup];
    return newGroup;
  }

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

  void addBroadcast(String groupId, {required String sender, required String subject, required String body, List<AttachmentModel> attachments = const []}) {
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(
          broadcasts: [
            ...group.broadcasts,
            ColabBroadcast(
              sender: sender,
              subject: subject,
              body: body,
              attachments: attachments,
              timestamp: DateTime.now(),
            ),
          ],
        );
      }
      return group;
    }).toList();
  }

  void deleteGroup(String groupId) {
    state = state.where((group) => group.id != groupId).toList();
  }

  void updateGroupMembers(String groupId, List<String> members) {
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(members: members);
      }
      return group;
    }).toList();
  }

  void markAsRead(String groupId) {
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(unread: false);
      }
      return group;
    }).toList();
  }
}

final colabListProvider = StateNotifierProvider<ColabListNotifier, List<ColabGroup>>((ref) {
  return ColabListNotifier();
});

final selectedColabIdProvider = StateProvider<String?>((ref) => null);
