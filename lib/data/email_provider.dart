import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/email_model.dart';
import '../models/attachment_model.dart';
import '../dummy/dummy_data.dart';

class EmailNotifier extends StateNotifier<List<EmailModel>> {
  EmailNotifier() : super(BNXDummyData.generateEmails());

  void toggleStar(String emailId) {
    state = state.map((email) {
      if (email.id == emailId) {
        return email.copyWith(isStarred: !email.isStarred);
      }
      return email;
    }).toList();
  }

  void toggleRead(String emailId, {bool? forceValue}) {
    state = state.map((email) {
      if (email.id == emailId) {
        return email.copyWith(isRead: forceValue ?? !email.isRead);
      }
      return email;
    }).toList();
  }

  void deleteEmail(String emailId) {
    state = state.map((email) {
      if (email.id == emailId) {
        return email.copyWith(isTrash: true);
      }
      return email;
    }).toList();
  }

  void restoreEmail(String emailId) {
    state = state.map((email) {
      if (email.id == emailId) {
        return email.copyWith(isTrash: false);
      }
      return email;
    }).toList();
  }

  void archiveEmail(String emailId) {
    state = state.map((email) {
      if (email.id == emailId) {
        return email.copyWith(isArchive: true);
      }
      return email;
    }).toList();
  }

  void toggleSnooze(String emailId, {bool? forceValue}) {
    state = state.map((email) {
      if (email.id == emailId) {
        return email.copyWith(isSnoozed: forceValue ?? !email.isSnoozed);
      }
      return email;
    }).toList();
  }

  // Feature 2: Snooze Scheduler — snooze with a specific DateTime
  void snoozeEmail(String emailId, DateTime until) {
    state = state.map((email) {
      if (email.id == emailId) {
        return email.copyWith(
          isSnoozed: true,
          snoozeUntil: until,
        );
      }
      return email;
    }).toList();
  }

  void composeEmail({
    required String to,
    required String subject,
    required String body,
    List<String> labels = const [],
    bool isDraft = false,
    List<AttachmentModel> attachments = const [],
  }) {
    final newEmail = EmailModel(
      id: 'email_id_${DateTime.now().millisecondsSinceEpoch}',
      senderName: BNXDummyData.currentUser.name,
      senderEmail: BNXDummyData.currentUser.email,
      recipient: to,
      subject: subject.isEmpty ? '(No Subject)' : subject,
      body: body,
      date: DateTime.now(),
      isRead: true, // composed by user, so read by default
      isStarred: false,
      isDraft: isDraft,
      isSent: !isDraft,
      labels: labels,
      avatar: 'R',
      attachments: attachments,
      hasAttachment: attachments.isNotEmpty,
    );
    state = [newEmail, ...state];
  }

  void receiveMockEmail() {
    final mockEmail = EmailModel(
      id: 'email_id_${DateTime.now().millisecondsSinceEpoch}',
      senderName: 'Antigravity Support',
      senderEmail: 'support@antigravity.ai',
      recipient: 'ravi@bnxmail.com',
      subject: 'Welcome to Antigravity Mail!',
      body: 'Hello Ravi! We have successfully set up your BNX collaboration workspaces and decoupled the channels. Happy coding!',
      date: DateTime.now(),
      isRead: false,
      isStarred: true,
      labels: ['Updates'],
      avatar: 'A',
    );
    state = [mockEmail, ...state];
  }

  void markAllAsRead() {
    state = state.map((email) => email.copyWith(isRead: true)).toList();
  }

  void sortByDate() {
    final sorted = List<EmailModel>.from(state);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    state = sorted;
  }

  void sortBySender() {
    final sorted = List<EmailModel>.from(state);
    sorted.sort((a, b) => a.senderName.compareTo(b.senderName));
    state = sorted;
  }
}

final emailProvider = StateNotifierProvider<EmailNotifier, List<EmailModel>>((ref) {
  return EmailNotifier();
});
