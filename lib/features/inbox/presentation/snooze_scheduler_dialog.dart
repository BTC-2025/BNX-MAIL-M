import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/email_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';

class SnoozeSchedulerDialog extends ConsumerStatefulWidget {
  final String emailId;
  final String emailSubject;

  const SnoozeSchedulerDialog({
    super.key,
    required this.emailId,
    required this.emailSubject,
  });

  static Future<void> show(
    BuildContext context, {
    required String emailId,
    required String emailSubject,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SnoozeSchedulerDialog(
        emailId: emailId,
        emailSubject: emailSubject,
      ),
    );
  }

  @override
  ConsumerState<SnoozeSchedulerDialog> createState() =>
      _SnoozeSchedulerDialogState();
}

class _SnoozeSchedulerDialogState
    extends ConsumerState<SnoozeSchedulerDialog> {
  DateTime? _customDate;
  TimeOfDay? _customTime;
  bool _showCustomPicker = false;

  String _formatSnoozeTime(DateTime dt) {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    if (dt.day == now.day && dt.month == now.month) {
      return 'Today, $hour:$min $period';
    }
    return '${months[dt.month - 1]} ${dt.day}, $hour:$min $period';
  }

  void _snoozeUntil(DateTime until) {
    ref.read(emailProvider.notifier).snoozeEmail(widget.emailId, until);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Snoozed until ${_formatSnoozeTime(until)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1D4ED8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final List<_SnoozeOption> options = [
      _SnoozeOption(
        icon: Icons.wb_sunny_outlined,
        color: const Color(0xFFF59E0B),
        label: 'Later Today',
        subtitle: _formatSnoozeTime(DateTime(now.year, now.month, now.day, 18, 0)),
        time: DateTime(now.year, now.month, now.day, 18, 0),
      ),
      _SnoozeOption(
        icon: Icons.wb_twilight_outlined,
        color: const Color(0xFFEF4444),
        label: 'Tomorrow Morning',
        subtitle: _formatSnoozeTime(
            DateTime(now.year, now.month, now.day + 1, 8, 0)),
        time: DateTime(now.year, now.month, now.day + 1, 8, 0),
      ),
      _SnoozeOption(
        icon: Icons.weekend_outlined,
        color: const Color(0xFF10B981),
        label: 'This Weekend',
        subtitle: _formatSnoozeTime(_nextWeekend(now)),
        time: _nextWeekend(now),
      ),
      _SnoozeOption(
        icon: Icons.date_range_outlined,
        color: const Color(0xFF3B82F6),
        label: 'Next Week',
        subtitle: _formatSnoozeTime(
            now.add(const Duration(days: 7)).copyWith(hour: 9, minute: 0)),
        time: now.add(const Duration(days: 7)).copyWith(hour: 9, minute: 0),
      ),
    ];

    return NeumorphicContainer(
      borderRadius: 24,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Snooze email',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      widget.emailSubject,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Snooze options
          ...options.map((opt) => _buildOption(opt, isDark)),
          // Custom date option
          _buildCustomOption(isDark, now),
        ],
      ),
    );
  }

  Widget _buildOption(_SnoozeOption opt, bool isDark) {
    return InkWell(
      onTap: () => _snoozeUntil(opt.time),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            NeumorphicContainer(
              width: 40,
              height: 40,
              shape: NeumorphicShape.pressed,
              borderRadius: 12,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
              child: Center(child: Icon(opt.icon, color: opt.color, size: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    opt.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomOption(bool isDark, DateTime now) {
    return InkWell(
      onTap: () async {
        // Pick date
        final picked = await showDatePicker(
          context: context,
          initialDate: now.add(const Duration(days: 1)),
          firstDate: now,
          lastDate: now.add(const Duration(days: 365)),
        );
        if (!mounted || picked == null) return;

        // Pick time
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 9, minute: 0),
        );
        if (!mounted || pickedTime == null) return;

        final finalDt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _snoozeUntil(finalDt);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            NeumorphicContainer(
              width: 40,
              height: 40,
              shape: NeumorphicShape.pressed,
              borderRadius: 12,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
              child: const Center(
                child: Icon(Icons.edit_calendar_outlined,
                    color: Color(0xFF8B5CF6), size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick date & time',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Choose a custom snooze time',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  DateTime _nextWeekend(DateTime now) {
    // Find next Saturday
    var d = now.add(const Duration(days: 1));
    while (d.weekday != DateTime.saturday) {
      d = d.add(const Duration(days: 1));
    }
    return DateTime(d.year, d.month, d.day, 9, 0);
  }
}

class _SnoozeOption {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final DateTime time;

  const _SnoozeOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.time,
  });
}
