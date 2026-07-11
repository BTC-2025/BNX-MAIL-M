import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notification_provider.dart';
import '../theme/colors.dart';

class NotificationCentrePanel extends ConsumerWidget {
  const NotificationCentrePanel({super.key});

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.email:
        return Icons.mail_outline_rounded;
      case NotificationType.system:
        return Icons.check_circle_outline_rounded;
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.security:
        return Icons.shield_outlined;
    }
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.email:
        return const Color(0xFF3B82F6);
      case NotificationType.system:
        return const Color(0xFF10B981);
      case NotificationType.alert:
        return const Color(0xFFEF4444);
      case NotificationType.security:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Actions row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NOTIFICATIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  letterSpacing: 1.0,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    ref.read(notificationsProvider.notifier).markAllRead(),
                icon: const Icon(Icons.done_all_rounded, size: 14),
                label: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor:
                      isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notifications.isEmpty
              ? _buildEmpty(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: notifications.length,
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    return _NotificationCard(
                      notification: n,
                      isDark: isDark,
                      icon: _iconFor(n.type),
                      color: _colorFor(n.type),
                      timeAgo: _timeAgo(n.time),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 48,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No new notifications',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final NotificationModel notification;
  final bool isDark;
  final IconData icon;
  final Color color;
  final String timeAgo;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.icon,
    required this.color,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.red, size: 20),
      ),
      onDismissed: (_) =>
          ref.read(notificationsProvider.notifier).dismiss(notification.id),
      child: GestureDetector(
        onTap: () =>
            ref.read(notificationsProvider.notifier).markRead(notification.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : (isDark
                    ? color.withValues(alpha: 0.08)
                    : color.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: notification.isRead
                    ? Colors.transparent
                    : color,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Unread dot
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 6, top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
