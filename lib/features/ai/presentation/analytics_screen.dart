import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/colors.dart';
import '../../../data/app_state_provider.dart';
import '../data/analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);
    final isDark = ref.watch(appUiProvider).isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkSurface : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(analyticsProvider.notifier).loadAnalytics();
        },
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            // ─── Header: Analytics Dashboard ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF3B82F6),
                              Color(0xFF1D4ED8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analytics Dashboard',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Mailbox insights, composition & activity',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                  onPressed: () {
                    ref.read(analyticsProvider.notifier).loadAnalytics();
                  },
                  tooltip: 'Refresh analytics',
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (analytics.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // ─── Card 1: Mailbox Composition (Donut PieChart) ────
              _buildMailboxCompositionCard(analytics, isDark, isMobile),
              const SizedBox(height: 24),

              // ─── Card 2: Daily Email Volume ───────────────────────
              _buildDailyVolumeCard(analytics, isDark),
              const SizedBox(height: 24),

              // ─── Card 3: Monthly Volume Overview ───────────────────
              _buildMonthlyVolumeCard(analytics, isDark),
              const SizedBox(height: 24),

              // ─── Grid Row: Top Senders & Top Recipients ────────────
              if (isMobile) ...[
                _buildTopSendersCard(analytics, isDark),
                const SizedBox(height: 24),
                _buildTopReceiversCard(analytics, isDark),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopSendersCard(analytics, isDark)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTopReceiversCard(analytics, isDark)),
                  ],
                ),
              ],
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  // ── 1. Mailbox Composition Donut PieChart ─────────────────────────────────

  Widget _buildMailboxCompositionCard(EmailAnalyticsData data, bool isDark, bool isMobile) {
    final total = data.inbox + data.sent + data.archive + data.drafts + data.spam + data.trash;

    final slices = [
      _PieSlice('INBOX', data.inbox, const Color(0xFFEF4444)),
      _PieSlice('Sent', data.sent, const Color(0xFF8B5CF6)),
      _PieSlice('Archive', data.archive, const Color(0xFF3B82F6)),
      _PieSlice('Drafts', data.drafts, const Color(0xFF64748B)),
      _PieSlice('Spam', data.spam, const Color(0xFFF59E0B)),
      _PieSlice('Trash', data.trash, const Color(0xFF10B981)),
    ];

    return _buildCardContainer(
      isDark: isDark,
      title: 'MAILBOX COMPOSITION',
      subtitle: 'Proportion of messages stored across mailboxes',
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Donut PieChart
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 50,
                sectionsSpace: 3,
                startDegreeOffset: -90,
                sections: slices.map((s) {
                  final val = s.count > 0 ? s.count.toDouble() : 0.1;
                  return PieChartSectionData(
                    color: s.color,
                    value: val,
                    title: '',
                    radius: 26,
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 500),
              swapAnimationCurve: Curves.easeInOutCubic,
            ),
          ),
          const SizedBox(height: 24),

          // Legend Pills matching Screenshot 1
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: slices.map((s) {
              final pct = total > 0 ? (s.count / total * 100).toStringAsFixed(0) : '0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.label} (${s.count})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── 2. Daily Email Volume (Non-congested Animated BarChart) ─────────────

  Widget _buildDailyVolumeCard(EmailAnalyticsData data, bool isDark) {
    final allDates = <String>{
      ...data.receivedByDate.keys,
      ...data.sentByDate.keys,
    }.toList()
      ..sort();

    if (allDates.isEmpty) {
      return _buildCardContainer(
        isDark: isDark,
        title: 'Daily Email Volume (Received vs Sent)',
        subtitle: 'Comparison of messages received and sent per day',
        child: _buildEmptyChartState('No daily activity recorded yet.', isDark),
      );
    }

    // Limit to last 6 dates on mobile for clear non-congested spacing
    final displayDates = allDates.length > 6 ? allDates.sublist(allDates.length - 6) : allDates;

    double maxY = 0;
    for (final d in displayDates) {
      final r = (data.receivedByDate[d] ?? 0).toDouble();
      final s = (data.sentByDate[d] ?? 0).toDouble();
      if (r > maxY) maxY = r;
      if (s > maxY) maxY = s;
    }
    if (maxY == 0) maxY = 10;

    return _buildCardContainer(
      isDark: isDark,
      title: 'Daily Email Volume (Received vs Sent)',
      subtitle: 'Comparison of messages received and sent per day',
      child: Column(
        children: [
          // Legend indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildChartLegendDot('Received', const Color(0xFF2563EB), isDark),
              const SizedBox(width: 14),
              _buildChartLegendDot('Sent', const Color(0xFF10B981), isDark),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.25,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = displayDates[group.x.toInt()];
                      final label = rodIndex == 0 ? 'Received' : 'Sent';
                      return BarTooltipItem(
                        '$d\n$label: ${rod.toY.toInt()}',
                        TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= displayDates.length) return const SizedBox.shrink();
                        final dStr = displayDates[idx];
                        final parts = dStr.split('-');
                        final shortLabel = parts.length >= 3 ? '${parts[1]}/${parts[2]}' : dStr;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            shortLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: displayDates.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final date = entry.value;
                  final recvVal = (data.receivedByDate[date] ?? 0).toDouble();
                  final sentVal = (data.sentByDate[date] ?? 0).toDouble();

                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: recvVal,
                        color: const Color(0xFF2563EB),
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: sentVal,
                        color: const Color(0xFF10B981),
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 450),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Monthly Volume Overview ──────────────────────────────────────────

  Widget _buildMonthlyVolumeCard(EmailAnalyticsData data, bool isDark) {
    final allMonths = <String>{
      ...data.receivedByMonth.keys,
      ...data.sentByMonth.keys,
    }.toList()
      ..sort();

    if (allMonths.isEmpty) {
      return _buildCardContainer(
        isDark: isDark,
        title: 'Monthly Volume Overview',
        subtitle: 'Total volume comparison across months',
        child: _buildEmptyChartState('No monthly history available.', isDark),
      );
    }

    final displayMonths = allMonths.length > 5 ? allMonths.sublist(allMonths.length - 5) : allMonths;

    double maxY = 0;
    for (final m in displayMonths) {
      final r = (data.receivedByMonth[m] ?? 0).toDouble();
      final s = (data.sentByMonth[m] ?? 0).toDouble();
      if (r > maxY) maxY = r;
      if (s > maxY) maxY = s;
    }
    if (maxY == 0) maxY = 10;

    return _buildCardContainer(
      isDark: isDark,
      title: 'Monthly Volume Overview',
      subtitle: 'Total volume comparison across months',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildChartLegendDot('Received', const Color(0xFF6366F1), isDark),
              const SizedBox(width: 14),
              _buildChartLegendDot('Sent', const Color(0xFF14B8A6), isDark),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.25,
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= displayMonths.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            displayMonths[idx],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: displayMonths.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final month = entry.value;
                  final recvVal = (data.receivedByMonth[month] ?? 0).toDouble();
                  final sentVal = (data.sentByMonth[month] ?? 0).toDouble();

                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: recvVal,
                        color: const Color(0xFF6366F1),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: sentVal,
                        color: const Color(0xFF14B8A6),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 450),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Top Senders Card ───────────────────────────────────────────────────

  Widget _buildTopSendersCard(EmailAnalyticsData data, bool isDark) {
    final senders = data.topSenders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = senders.take(5).toList();

    return _buildCardContainer(
      isDark: isDark,
      title: 'Top Senders',
      subtitle: 'Contacts who send you the most emails',
      child: top5.isEmpty
          ? _buildEmptyChartState('No sender metrics recorded.', isDark)
          : Column(
              children: top5.map((entry) {
                final max = top5.first.value > 0 ? top5.first.value : 1;
                final ratio = (entry.value / max).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.grey.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.value} msgs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── 5. Top Receivers Card ─────────────────────────────────────────────────

  Widget _buildTopReceiversCard(EmailAnalyticsData data, bool isDark) {
    final receivers = data.topReceivers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = receivers.take(5).toList();

    return _buildCardContainer(
      isDark: isDark,
      title: 'Top Recipients',
      subtitle: 'Contacts you email most frequently',
      child: top5.isEmpty
          ? _buildEmptyChartState('No recipient metrics recorded.', isDark)
          : Column(
              children: top5.map((entry) {
                final max = top5.first.value > 0 ? top5.first.value : 1;
                final ratio = (entry.value / max).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.grey.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.value} msgs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _buildChartLegendDot(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyChartState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

class _PieSlice {
  final String label;
  final int count;
  final Color color;

  _PieSlice(this.label, this.count, this.color);
}
