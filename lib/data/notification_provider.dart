import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationType { email, system, alert, security }

class NotificationModel {
  final String id;
  final String title;
  final String subtitle;
  final DateTime time;
  final NotificationType type;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    this.type = NotificationType.email,
    this.isRead = false,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    DateTime? time,
    NotificationType? type,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      time: time ?? this.time,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier()
      : super([
          NotificationModel(
            id: 'notif_1',
            title: 'New email from Sarah Chen',
            subtitle: '🚀 BNXMail Platform Launch Roadmap 2026',
            time: DateTime.now().subtract(const Duration(minutes: 3)),
            type: NotificationType.email,
            isRead: false,
          ),
          NotificationModel(
            id: 'notif_2',
            title: 'GitHub Security Alert',
            subtitle: '3 vulnerabilities found in npm dependencies',
            time: DateTime.now().subtract(const Duration(minutes: 18)),
            type: NotificationType.alert,
            isRead: false,
          ),
          NotificationModel(
            id: 'notif_3',
            title: 'Deployment Successful',
            subtitle: 'bnxmail-frontend-web is live on Vercel',
            time: DateTime.now().subtract(const Duration(hours: 1)),
            type: NotificationType.system,
            isRead: false,
          ),
          NotificationModel(
            id: 'notif_4',
            title: 'Code review request',
            subtitle: 'Alex Rivera requested your review on PR #42',
            time: DateTime.now().subtract(const Duration(hours: 2)),
            type: NotificationType.email,
            isRead: true,
          ),
          NotificationModel(
            id: 'notif_5',
            title: 'Security scan complete',
            subtitle: 'No threats detected. Your account is secure.',
            time: DateTime.now().subtract(const Duration(hours: 5)),
            type: NotificationType.security,
            isRead: true,
          ),
          NotificationModel(
            id: 'notif_6',
            title: 'New message in #bnxmail-design',
            subtitle: 'James Wilson: Updated icons for Compose, Starred...',
            time: DateTime.now().subtract(const Duration(hours: 8)),
            type: NotificationType.email,
            isRead: true,
          ),
        ]);

  int get unreadCount => state.where((n) => !n.isRead).length;

  void markRead(String id) {
    state =
        state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
        (ref) => NotificationsNotifier());

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});
