import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
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

    // Pie chart colors
    final List<Color> pieColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    final labelColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkSurface : Colors.white,
      body: ListView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        children: [
          // ─── Header ───────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      BNXColors.lightPrimary,
                      BNXColors.lightPrimary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email Analytics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Insights from your mailbox',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Stat Cards Row ────────────────────────────────────
          isMobile
              ? Column(
                  children: [
                    Row(children: [
                      Expanded(child: _StatCard(label: 'Total', value: analytics.total, icon: Icons.mail_outline_rounded, color: const Color(0xFF3B82F6), isDark: isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Unread', value: analytics.unread, icon: Icons.mark_email_unread_outlined, color: const Color(0xFFEF4444), isDark: isDark)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _StatCard(label: 'Sent', value: analytics.sent, icon: Icons.send_outlined, color: const Color(0xFF10B981), isDark: isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Starred', value: analytics.starred, icon: Icons.star_outline_rounded, color: const Color(0xFFF59E0B), isDark: isDark)),
                    ]),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _StatCard(label: 'Total Emails', value: analytics.total, icon: Icons.mail_outline_rounded, color: const Color(0xFF3B82F6), isDark: isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _StatCard(label: 'Unread', value: analytics.unread, icon: Icons.mark_email_unread_outlined, color: const Color(0xFFEF4444), isDark: isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _StatCard(label: 'Sent', value: analytics.sent, icon: Icons.send_outlined, color: const Color(0xFF10B981), isDark: isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _StatCard(label: 'Starred', value: analytics.starred, icon: Icons.star_outline_rounded, color: const Color(0xFFF59E0B), isDark: isDark)),
                  ],
                ),
          const SizedBox(height: 28),

          // ─── Bar Chart: Emails per Weekday ────────────────────
          _ChartCard(
            title: 'Email Activity by Weekday',
            subtitle: 'Emails received per day of the week',
            icon: Icons.show_chart_rounded,
            iconColor: const Color(0xFF3B82F6),
            isDark: isDark,
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (analytics.emailsPerWeekday.isNotEmpty
                          ? analytics.emailsPerWeekday.reduce((a, b) => a > b ? a : b)
                          : 10)
                      .toDouble() * 1.3,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                        interval: _computeInterval(analytics.emailsPerWeekday),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          final idx = v.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              days[idx],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    analytics.emailsPerWeekday.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: analytics.emailsPerWeekday[i].toDouble(),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF3B82F6),
                              const Color(0xFF1D4ED8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Two charts side by side on desktop ───────────────
          isMobile
              ? Column(
                  children: [
                    _buildLabelChart(analytics, labelColors, isDark),
                    const SizedBox(height: 20),
                    _buildTopSendersChart(analytics, pieColors, isDark),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _buildLabelChart(analytics, labelColors, isDark)),
                    const SizedBox(width: 20),
                    Expanded(
                        child: _buildTopSendersChart(
                            analytics, pieColors, isDark)),
                  ],
                ),
          const SizedBox(height: 24),

          // ─── Read vs Unread donut ─────────────────────────────
          _ChartCard(
            title: 'Read vs Unread',
            subtitle: 'Overall mailbox read rate',
            icon: Icons.donut_large_rounded,
            iconColor: const Color(0xFF10B981),
            isDark: isDark,
            child: SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 55,
                        sections: [
                          PieChartSectionData(
                            value: (analytics.total - analytics.unread)
                                .toDouble()
                                .clamp(0, double.infinity),
                            color: const Color(0xFF10B981),
                            radius: 40,
                            title: '',
                          ),
                          PieChartSectionData(
                            value: analytics.unread.toDouble(),
                            color: const Color(0xFFEF4444),
                            radius: 40,
                            title: '',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendItem(
                        color: const Color(0xFF10B981),
                        label: 'Read',
                        value: analytics.total - analytics.unread,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _LegendItem(
                        color: const Color(0xFFEF4444),
                        label: 'Unread',
                        value: analytics.unread,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      // Read rate percent
                      if (analytics.total > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${((analytics.total - analytics.unread) / analytics.total * 100).toStringAsFixed(0)}% read',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  double _computeInterval(List<int> data) {
    if (data.isEmpty) return 1;
    final max = data.reduce((a, b) => a > b ? a : b);
    if (max <= 5) return 1;
    if (max <= 20) return 5;
    return 10;
  }

  Widget _buildLabelChart(EmailAnalytics analytics, List<Color> colors, bool isDark) {
    return _ChartCard(
      title: 'Label Distribution',
      subtitle: 'Emails per label category',
      icon: Icons.label_outline_rounded,
      iconColor: const Color(0xFF8B5CF6),
      isDark: isDark,
      child: Column(
        children: analytics.labelCounts.take(6).toList().asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          final maxCount = analytics.labelCounts.isNotEmpty
              ? analytics.labelCounts.first.value
              : 1;
          final ratio = maxCount > 0 ? entry.value / maxCount : 0.0;
          final color = colors[idx % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 12,
                      backgroundColor:
                          isDark ? Colors.white10 : Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopSendersChart(
      EmailAnalytics analytics, List<Color> colors, bool isDark) {
    if (analytics.topSenders.isEmpty) {
      return _ChartCard(
        title: 'Top Senders',
        subtitle: 'Most frequent email senders',
        icon: Icons.people_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
        isDark: isDark,
        child: const Center(
            child: Text('No data', style: TextStyle(color: Colors.grey))),
      );
    }

    final total = analytics.topSenders.fold(0, (s, e) => s + e.value);

    return _ChartCard(
      title: 'Top Senders',
      subtitle: 'Most frequent email senders',
      icon: Icons.people_outline_rounded,
      iconColor: const Color(0xFFF59E0B),
      isDark: isDark,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: analytics.topSenders.asMap().entries.map((e) {
                  final idx = e.key;
                  final entry = e.value;
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: colors[idx % colors.length],
                    radius: 45,
                    title: total > 0
                        ? '${(entry.value / total * 100).toStringAsFixed(0)}%'
                        : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...analytics.topSenders.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[idx % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors[idx % colors.length],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: 16,
      border: Border.all(color: color.withValues(alpha: 0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              // Trend indicator (static for now)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '↑ live',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      padding: const EdgeInsets.all(20),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFF),
      borderRadius: 20,
      border: Border.all(
        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
