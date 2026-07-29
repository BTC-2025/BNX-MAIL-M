import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/app_state_provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../core/widgets/sidebar.dart';
import '../../../core/widgets/top_search_bar.dart';
import '../../../core/widgets/compose_dialog.dart';
import '../../../core/widgets/notification_centre_panel.dart';
import '../../../data/notification_provider.dart';

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final bool isTablet =
        screenWidth >= 600 && screenWidth < BNXConstants.desktopBreakpoint;

    // Auto collapse sidebar on tablet screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMobile) {
        final notifier = ref.read(appUiProvider.notifier);
        if (isTablet && !uiState.isSidebarCollapsed) {
          notifier.setSidebarCollapsed(true);
        }
      }
    });
    final String currentRoute = GoRouterState.of(context).uri.toString();
    final bool isSettings = currentRoute == '/settings';
    final bool isProfile = currentRoute == '/profile';
    final bool isManageAccount = currentRoute == '/manage-account';

    final double activeSidebarWidth = (isMobile || isProfile || isManageAccount)
        ? 0.0
        : (uiState.isSidebarCollapsed
              ? (uiState.activeLeftUtility != null
                    ? BNXConstants.sidebarCollapsedWidth + 280.0
                    : BNXConstants.sidebarCollapsedWidth)
              : BNXConstants.sidebarExpandedWidth);

    final bool showRightPanel =
        uiState.activeRightUtility != 'none' && !isMobile && screenWidth > 950;
    final bool showRightRail = !isMobile;

    int selectedIndex = 0;
    if (isProfile) {
      selectedIndex = 2;
    } else if (currentRoute == '/colab') {
      selectedIndex = 1;
    } else if (isSettings) {
      selectedIndex = -1;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final currentRoute = GoRouterState.of(context).uri.toString();
          if (uiState.composeStatus != ComposeStatus.closed) {
            ref
                .read(appUiProvider.notifier)
                .setComposeStatus(ComposeStatus.closed);
          } else if (currentRoute != '/home') {
            // Always go to /home — never let back reach the splash screen
            context.go('/home');
            ref.read(appUiProvider.notifier).selectFolder('Inbox');
          } else if (uiState.activeFolder != 'Inbox') {
            ref.read(appUiProvider.notifier).selectFolder('Inbox');
          }
        },
        child: Scaffold(
          backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightBg,
          extendBody: true,
          drawer: isMobile ? const Drawer(child: Sidebar()) : null,
          bottomNavigationBar:
              (isMobile &&
                  !isSettings &&
                  currentRoute != '/help' &&
                  currentRoute != '/compose' &&
                  currentRoute != '/connect-settings' &&
                  uiState.composeStatus == ComposeStatus.closed)
              ? Container(
                  color: Colors.transparent,
                  child: SafeArea(
                    bottom: true,
                    minimum: EdgeInsets.zero,
                    child: Container(
                      height: 64,
                      margin: const EdgeInsets.fromLTRB(54, 0, 54, 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.08,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Mail Tab
                          _buildCustomBottomTab(
                            isSelected: selectedIndex == 0,
                            icon: Icons.mail_rounded,
                            label: 'Mail',
                            onTap: () {
                              context.go('/home');
                              ref
                                  .read(appUiProvider.notifier)
                                  .selectFolder('Inbox');
                            },
                            isDark: isDark,
                          ),
                          // Chat Tab
                          _buildCustomBottomTab(
                            isSelected: selectedIndex == 1,
                            icon: Icons.chat_bubble_rounded,
                            label: 'Chat',
                            onTap: () {
                              context.go('/colab');
                              ref
                                  .read(appUiProvider.notifier)
                                  .selectFolder('Casbox');
                            },
                            isDark: isDark,
                          ),
                          // Profile Tab
                          _buildCustomBottomTab(
                            isSelected: selectedIndex == 2,
                            icon: Icons.person_rounded,
                            label: 'Profile',
                            onTap: () {
                              context.go('/profile');
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
          floatingActionButton:
              (isMobile &&
                  uiState.composeStatus == ComposeStatus.closed &&
                  (currentRoute == '/home' ||
                      (currentRoute == '/colab' &&
                          uiState.activeFolder == 'Casbox')) &&
                  uiState.activeFolder != 'Templates' &&
                  uiState.activeFolder != 'Settings')
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 68.0),
                  child: (() {
                    final isFabExtended = ref.watch(fabExtensionProvider);
                    return isFabExtended
                        ? FloatingActionButton.extended(
                            onPressed: () {
                              context.push('/compose');
                            },
                            backgroundColor: const Color(0xFF195BAC),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text(
                              'Compose',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                        : FloatingActionButton(
                            onPressed: () {
                              context.push('/compose');
                            },
                            backgroundColor: const Color(0xFF195BAC),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            child: const Icon(Icons.edit_outlined),
                          );
                  })(),
                )
              : null,
          body: Stack(
            children: [
              Row(
                children: [
                  // 1. LEFT SIDEBAR (Hidden on mobile, profile, and manage-account pages)
                  if (!isMobile && !isProfile && !isManageAccount)
                    AnimatedContainer(
                      duration: BNXConstants.animationDurationFast,
                      width: activeSidebarWidth,
                      child: const Sidebar(),
                    ),

                  // Divider between sidebar and center panel
                  if (!isMobile && !isProfile && !isManageAccount)
                    VerticalDivider(
                      width: 1,
                      color: isDark
                          ? BNXColors.darkBorder
                          : BNXColors.lightBorder,
                    ),

                  // 2. CENTER PANEL CONTAINER (Top Bar + Main Page Child + Right Side Utility Panel)
                  Expanded(
                    child: SafeArea(
                      top: isMobile && currentRoute != '/profile' && currentRoute != '/manage-account',
                      bottom: false,
                      child: Column(
                        children: [
                          // Top App Bar - Hide in Settings, Profile, Manage Account, Colab, or Help
                          if (currentRoute != '/profile' &&
                              currentRoute != '/manage-account' &&
                              uiState.activeFolder != 'Settings' &&
                              uiState.activeFolder != 'Chat' &&
                              uiState.activeFolder != 'Casbox' &&
                              uiState.activeFolder != 'Help')
                            const TopSearchBar(),

                          // Main Content Split Area
                          Expanded(
                            child: Row(
                              children: [
                                // Main Screen Content (GoRouter child: Email List, Colab, or Settings)
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: isMobile
                                        ? BorderRadius.zero
                                        : const BorderRadius.only(
                                            topLeft: Radius.circular(
                                              BNXConstants.borderRadiusL,
                                            ),
                                          ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? BNXColors.darkSurface
                                            : Colors.white,
                                        borderRadius: isMobile
                                            ? BorderRadius.zero
                                            : const BorderRadius.only(
                                                topLeft: Radius.circular(
                                                  BNXConstants.borderRadiusL,
                                                ),
                                              ),
                                        boxShadow: isMobile
                                            ? null
                                            : BNXConstants.softShadow,
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return FadeTransition(
                                            opacity: CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeInOut,
                                            ),
                                            child: child,
                                          );
                                        },
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ),

                                // Expandable Right Utility Panel (e.g. Calendar)
                                if (showRightPanel)
                                  _buildExpandableRightPanel(
                                    context,
                                    ref,
                                    uiState,
                                    isDark,
                                  ),

                                // Far Right Rail (Mini icons)
                                if (showRightRail)
                                  _buildRightIconRail(
                                    context,
                                    ref,
                                    uiState,
                                    isDark,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 3. FLOATING COMPOSE DIALOG (Overlays bottom right)
              const ComposeDialog(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableRightPanel(
    BuildContext context,
    WidgetRef ref,
    AppUiState uiState,
    bool isDark,
  ) {
    if (uiState.activeRightUtility == 'none') {
      return const SizedBox.shrink();
    }

    Widget panelContent;

    switch (uiState.activeRightUtility) {
      case 'Calendar':
        panelContent = _buildCalendarPanel(context, isDark);
        break;
      case 'Keep':
        panelContent = _buildKeepPanel(context, isDark);
        break;
      case 'Contacts':
        panelContent = _buildContactsPanel(isDark);
        break;
      case 'Tasks':
        panelContent = _buildContactsPanel(
          isDark,
        ); // Corrected to Contacts or logic from previous
        break;
      // Feature 4: Notification Centre
      case 'Notifications':
        panelContent = const NotificationCentrePanel();
        break;
      default:
        panelContent = const Center(child: Text('Utility panel'));
    }

    return Container(
      width: BNXConstants.calendarExpandedWidth,
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 8,
              top: 12,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  uiState.activeRightUtility,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    ref
                        .read(appUiProvider.notifier)
                        .setActiveRightUtility('none');
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: panelContent),
        ],
      ),
    );
  }

  Widget _buildRightIconRail(
    BuildContext context,
    WidgetRef ref,
    AppUiState uiState,
    bool isDark,
  ) {
    final activeUtil = uiState.activeRightUtility;

    Widget railIcon({
      required String name,
      required IconData icon,
      required Color color,
      required String tooltip,
    }) {
      final isSelected = activeUtil == name;

      return Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              ref.read(appUiProvider.notifier).setActiveRightUtility(name);
            },
            child: NeumorphicContainer(
              width: 44,
              height: 44,
              boxShape: BoxShape.circle,
              shape: isSelected
                  ? NeumorphicShape.pressed
                  : NeumorphicShape.flat,
              depth: isSelected ? 0 : 2.0,
              color: isSelected
                  ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB))
                  : Colors.transparent,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Icon(
                icon,
                color: isSelected
                    ? (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary)
                    : color,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: BNXConstants.rightSidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkBg : BNXColors.lightBg,
        border: Border(
          left: BorderSide(
            color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          railIcon(
            name: 'Calendar',
            icon: Icons.calendar_today_rounded,
            color: Colors.amber.shade700,
            tooltip: 'Calendar',
          ),
          railIcon(
            name: 'Keep',
            icon: Icons.lightbulb_outline_rounded,
            color: Colors.yellow.shade800,
            tooltip: 'Keep (Notes)',
          ),
          railIcon(
            name: 'Contacts',
            icon: Icons.person_pin_rounded,
            color: Colors.blue.shade700,
            tooltip: 'Contacts',
          ),
          railIcon(
            name: 'Tasks',
            icon: Icons.check_circle_outline_rounded,
            color: Colors.teal.shade700,
            tooltip: 'Tasks',
          ),
          // Feature 4: Notification Centre bell in rail
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadNotificationsCountProvider);
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  railIcon(
                    name: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                    color: Colors.orange.shade700,
                    tooltip: 'Notifications',
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 4,
                      top: 8,
                      child: IgnorePointer(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(indent: 12, endIndent: 12, height: 24),
          // Plus icon to add add-ons
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              _showAddOnsMarketplaceDialog(context, isDark);
            },
            tooltip: 'Get add-ons',
          ),
        ],
      ),
    );
  }

  // --- Utility Mock Sub-panels ---
  Widget _buildCalendarPanel(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),
        Text(
          'July 2026',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        // Mini Calendar Grid Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        // Simple Calendar Grid simulation
        _buildCalendarGrid(),

        const Divider(height: 24),

        Text(
          "TODAY'S SCHEDULE",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        NeumorphicContainer(
          borderRadius: 12,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(color: Colors.amber.withValues(alpha: 0.24)),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '14:00 - Project Review',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.amber,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Reviewing mail client features with team members.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    // Generate simple calendar dates starting Wed July 1
    final List<Widget> rows = [];
    List<Widget> currentRow = [];

    // Wed is day 3 (Sun=0, Mon=1, Tue=2, Wed=3)
    for (int i = 0; i < 3; i++) {
      currentRow.add(const Expanded(child: SizedBox()));
    }

    for (int day = 1; day <= 31; day++) {
      final isToday = day == 1; // July 1st
      currentRow.add(
        Expanded(
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? BNXColors.lightPrimary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.white : null,
                ),
              ),
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add(const Expanded(child: SizedBox()));
      }
      rows.add(Row(children: currentRow));
    }

    return Column(
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: r,
            ),
          )
          .toList(),
    );
  }

  Widget _buildKeepPanel(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMiniCard(
          context,
          'Design Checklist',
          '1. Corner radius 16\n2. Color code #F4F7FB\n3. Hover animations',
          Colors.teal,
        ),
        _buildMiniCard(
          context,
          'Feedback on Compose',
          'Make compose window float dynamically and support minimized state.',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildContactsPanel(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.account_circle, color: Colors.blue),
          title: Text(
            'Sarah Chen',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'sarah.chen@bnxmail.com',
            style: TextStyle(fontSize: 11),
          ),
        ),
        ListTile(
          leading: Icon(Icons.account_circle, color: Colors.indigo),
          title: Text(
            'Alex Rivera',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'alex.rivera@techcorp.com',
            style: TextStyle(fontSize: 11),
          ),
        ),
        ListTile(
          leading: Icon(Icons.account_circle, color: Colors.purple),
          title: Text(
            'James Wilson',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'james.wilson@design.com',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard(
    BuildContext context,
    String title,
    String body,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NeumorphicContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 8,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: Border.all(color: color.withValues(alpha: 0.3)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomTab({
    required bool isSelected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 12.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF195BAC) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white54 : Colors.black54),
              size: 20,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOnsMarketplaceDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final List<Map<String, dynamic>> addOns = [
              {
                'name': 'Zoom for BNX',
                'desc': 'Start Zoom meetings from emails.',
                'icon': Icons.video_camera_back_rounded,
                'installed': false,
              },
              {
                'name': 'Trello Integration',
                'desc': 'Turn emails into Trello cards.',
                'icon': Icons.dashboard_customize_rounded,
                'installed': false,
              },
              {
                'name': 'Dropbox Attachments',
                'desc': 'Attach Dropbox files easily.',
                'icon': Icons.cloud_queue_rounded,
                'installed': false,
              },
              {
                'name': 'Slack Connector',
                'desc': 'Forward details directly to Slack.',
                'icon': Icons.chat_outlined,
                'installed': false,
              },
            ];

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: Color(0xFF195BAC),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add-on Marketplace',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: addOns.map((addon) {
                    final bool isInstalled = addon['installed'] as bool;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE9F4FF),
                        child: Icon(
                          addon['icon'] as IconData,
                          color: const Color(0xFF195BAC),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        addon['name'] as String,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        addon['desc'] as String,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          setDialogState(() {
                            addon['installed'] = !isInstalled;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isInstalled
                                    ? '${addon['name']} uninstalled.'
                                    : '${addon['name']} installed successfully!',
                              ),
                              backgroundColor: isInstalled
                                  ? Colors.redAccent
                                  : Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          isInstalled ? 'Uninstall' : 'Install',
                          style: TextStyle(
                            color: isInstalled
                                ? Colors.redAccent
                                : const Color(0xFF195BAC),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
