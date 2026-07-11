import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/email_provider.dart';

class EmailAnalytics {
  final int total;
  final int unread;
  final int sent;
  final int starred;
  final int drafts;
  final int snoozed;
  // Emails received per weekday: index 0 = Mon, 6 = Sun
  final List<int> emailsPerWeekday;
  // Top senders: name -> count
  final List<MapEntry<String, int>> topSenders;
  // Label distribution: label -> count
  final List<MapEntry<String, int>> labelCounts;

  const EmailAnalytics({
    required this.total,
    required this.unread,
    required this.sent,
    required this.starred,
    required this.drafts,
    required this.snoozed,
    required this.emailsPerWeekday,
    required this.topSenders,
    required this.labelCounts,
  });
}

final analyticsProvider = Provider<EmailAnalytics>((ref) {
  final emails = ref.watch(emailProvider);

  final inbox =
      emails.where((e) => !e.isTrash && !e.isDraft && !e.isSent).toList();

  // Weekday distribution (Mon=1 … Sun=7 in Dart's weekday)
  final weekdayCounts = List<int>.filled(7, 0);
  for (final e in inbox) {
    final idx = e.date.weekday - 1; // 0=Mon, 6=Sun
    weekdayCounts[idx]++;
  }

  // Top senders from inbox
  final senderMap = <String, int>{};
  for (final e in inbox) {
    senderMap[e.senderName] = (senderMap[e.senderName] ?? 0) + 1;
  }
  final topSenders = senderMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Label distribution
  final labelMap = <String, int>{};
  for (final e in emails.where((e) => !e.isTrash)) {
    for (final l in e.labels) {
      labelMap[l] = (labelMap[l] ?? 0) + 1;
    }
  }
  final labelCounts = labelMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return EmailAnalytics(
    total: emails.where((e) => !e.isTrash).length,
    unread: emails
        .where((e) => !e.isRead && !e.isTrash && !e.isDraft && !e.isSent)
        .length,
    sent: emails.where((e) => e.isSent && !e.isTrash).length,
    starred: emails.where((e) => e.isStarred && !e.isTrash).length,
    drafts: emails.where((e) => e.isDraft && !e.isTrash).length,
    snoozed: emails.where((e) => e.isSnoozed && !e.isTrash).length,
    emailsPerWeekday: weekdayCounts,
    topSenders: topSenders.take(5).toList(),
    labelCounts: labelCounts.take(6).toList(),
  );
});
