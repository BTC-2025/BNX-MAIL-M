import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/connection_provider.dart';
import '../../../core/theme/colors.dart';

class ConnectSettingsScreen extends ConsumerStatefulWidget {
  const ConnectSettingsScreen({super.key});

  @override
  ConsumerState<ConnectSettingsScreen> createState() =>
      _ConnectSettingsScreenState();
}

class _ConnectSettingsScreenState extends ConsumerState<ConnectSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final connectionState = ref.watch(connectionProvider);
    final isDark = uiState.isDarkMode;

    final Color cardColor = isDark ? BNXColors.darkSurface : Colors.white;
    final Color textColor = isDark
        ? BNXColors.darkTextPrimary
        : BNXColors.lightTextPrimary;
    final Color subTextColor = isDark
        ? BNXColors.darkTextSecondary
        : BNXColors.lightTextSecondary;
    final Color borderColor = isDark
        ? BNXColors.darkBorder
        : BNXColors.lightBorder;
    final Color activeColor = const Color(0xFF195BAC);

    final Color headerColor = isDark ? BNXColors.darkSurface : Colors.white;
    final Color bottomBgColor = isDark
        ? BNXColors.darkBg
        : const Color(0xFFE9F4FF);

    return Scaffold(
      backgroundColor: bottomBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top White Header Section (Header + TabBar + SearchBar)
            Container(
              color: headerColor,
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  // Back button + Title Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: textColor,
                          ),
                          onPressed: () {
                            context.go('/colab');
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Secure Connections',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          connectionState
                                              .connectedUsers
                                              .isNotEmpty
                                          ? Colors.green
                                          : Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    connectionState.connectedUsers.isNotEmpty
                                        ? '${connectionState.connectedUsers.length} Active Tunnels Connected'
                                        : 'No Active Connections (Standby)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabbar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.transparent,
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide.none,
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: isDark ? Colors.white : activeColor,
                    unselectedLabelColor: subTextColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Connect'),
                      Tab(text: 'Connected'),
                      Tab(text: 'Blocked'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Search Bar inside Header Container
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? BNXColors.darkBg
                            : const Color(0xFFE9F4FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search user connection...',
                          hintStyle: TextStyle(
                            color: subTextColor.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: subTextColor,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Down section (TabBarView only)
            Expanded(
              child: Container(
                color: bottomBgColor,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConnectTab(
                      connectionState,
                      cardColor,
                      textColor,
                      subTextColor,
                      borderColor,
                      activeColor,
                      isDark,
                    ),
                    _buildConnectedTab(
                      connectionState,
                      cardColor,
                      textColor,
                      subTextColor,
                      borderColor,
                      activeColor,
                      isDark,
                    ),
                    _buildBlockedTab(
                      connectionState,
                      cardColor,
                      textColor,
                      subTextColor,
                      borderColor,
                      activeColor,
                      isDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectTab(
    ConnectionStateData state,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color borderColor,
    Color activeColor,
    bool isDark,
  ) {
    final filtered = state.availableUsers
        .where((u) => u.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        Icons.people_outline_rounded,
        'No available users found',
        subTextColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 4.0,
        bottom: 8.0,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final username = filtered[index];
        final randomLatency = 20 + Random(username.hashCode).nextInt(80);
        return Container(
          margin: const EdgeInsets.only(bottom: 3.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: activeColor.withValues(alpha: 0.1),
                child: Text(
                  username[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.network_ping_rounded,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$randomLatency ms (Tunnel Stable)',
                            style: TextStyle(color: subTextColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Block User',
                    onPressed: () {
                      ref.read(connectionProvider.notifier).block(username);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$username has been blocked.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(connectionProvider.notifier).connect(username);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Establishing secure tunnel with $username...',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectedTab(
    ConnectionStateData state,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color borderColor,
    Color activeColor,
    bool isDark,
  ) {
    final filtered = state.connectedUsers
        .where((u) => u.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        Icons.sync_disabled_rounded,
        'No active connections',
        subTextColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 4.0,
        bottom: 8.0,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final username = filtered[index];
        final simulatedIP =
            '10.240.0.${Random(username.hashCode).nextInt(254) + 1}';
        return Container(
          margin: const EdgeInsets.only(bottom: 3.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: isDark ? 0.05 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.vpn_lock_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Secure Tunnel IP: $simulatedIP',
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      ref
                          .read(connectionProvider.notifier)
                          .disconnect(username);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Secure tunnel with $username terminated.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Disconnect',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric(
                    'Speed',
                    '4.2 MB/s',
                    Icons.speed_rounded,
                    subTextColor,
                  ),
                  _buildMetric(
                    'Tunnel Type',
                    'WireGuard L2',
                    Icons.security_rounded,
                    subTextColor,
                  ),
                  _buildMetric(
                    'Uptime',
                    '02h 14m',
                    Icons.timer_outlined,
                    subTextColor,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockedTab(
    ConnectionStateData state,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color borderColor,
    Color activeColor,
    bool isDark,
  ) {
    final filtered = state.blockedUsers
        .where((u) => u.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        Icons.gavel_rounded,
        'No blocked users',
        subTextColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 4.0,
        bottom: 8.0,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final username = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 3.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Access Restricted',
                      style: TextStyle(
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(connectionProvider.notifier).unblock(username);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$username has been unblocked.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: activeColor),
                child: const Text(
                  'Unblock',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String message, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
