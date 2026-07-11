import 'package:flutter/material.dart';
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

  const DashboardShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth >= 600 && screenWidth < BNXConstants.desktopBreakpoint;
    
    // Auto collapse sidebar on tablet screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMobile) {
        final notifier = ref.read(appUiProvider.notifier);
        if (isTablet && !uiState.isSidebarCollapsed) {
          notifier.setSidebarCollapsed(true);
        }
      }
    });

    final double activeSidebarWidth = isMobile
        ? 0.0
        : (uiState.isSidebarCollapsed
            ? BNXConstants.sidebarCollapsedWidth
            : BNXConstants.sidebarExpandedWidth);

    final bool showRightPanel = uiState.activeRightUtility != 'none' && !isMobile && screenWidth > 950;
    final bool showRightRail = !isMobile;

    final String currentRoute = GoRouterState.of(context).uri.toString();
    final int selectedIndex = currentRoute == '/profile' ? 1 : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        final currentRoute = GoRouterState.of(context).uri.toString();
        
        if (uiState.composeStatus != ComposeStatus.closed) {
          ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.closed);
        } else if (currentRoute != '/') {
          context.go('/');
          ref.read(appUiProvider.notifier).selectFolder('Inbox');
        } else if (uiState.activeFolder != 'Inbox') {
          ref.read(appUiProvider.notifier).selectFolder('Inbox');
        } else {
          // Stay in app or exit? User said "should go only to home page only"
          // In Flutter, if we want to allow exit, we should set canPop to true
          // But user wants to stay on home page. 
          // Note: canPop: false means we intercept it.
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightBg,
        drawer: isMobile ? const Drawer(child: Sidebar()) : null,
        bottomNavigationBar: isMobile
            ? NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  if (index == 0) {
                    context.go('/');
                  } else if (index == 1) {
                    context.go('/profile');
                  }
                },
                backgroundColor: isDark ? BNXColors.darkSurface : const Color(0xFFF3F6FC),
                indicatorColor: isDark ? BNXColors.darkSidebarSelected : const Color(0xFFC2E7FF),
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      label: const Text('99+', style: TextStyle(color: Colors.white, fontSize: 10)),
                      backgroundColor: Colors.red,
                      child: Icon(Icons.mail_outlined, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    selectedIcon: Badge(
                      label: const Text('99+', style: TextStyle(color: Colors.white, fontSize: 10)),
                      backgroundColor: Colors.red,
                      child: Icon(Icons.mail, color: isDark ? BNXColors.darkPrimary : const Color(0xFF001D35)),
                    ),
                    label: 'Mail',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.account_circle_outlined, color: isDark ? Colors.white70 : Colors.black87),
                    selectedIcon: Icon(Icons.account_circle, color: isDark ? BNXColors.darkPrimary : const Color(0xFF001D35)),
                    label: 'Profile',
                  ),
                ],
              )
            : null,
        floatingActionButton: (isMobile && uiState.composeStatus == ComposeStatus.closed && currentRoute == '/' && uiState.activeFolder != 'Templates' && uiState.activeFolder != 'Settings')
            ? (() {
                final isFabExtended = ref.watch(fabExtensionProvider);
                return isFabExtended
                    ? FloatingActionButton.extended(
                        onPressed: () {
                          ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
                        },
                        backgroundColor: isDark ? BNXColors.darkPrimary : const Color(0xFFC2E7FF),
                        foregroundColor: isDark ? Colors.black : const Color(0xFF001D35),
                        elevation: 4,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Compose', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    : FloatingActionButton(
                        onPressed: () {
                          ref.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);
                        },
                        backgroundColor: isDark ? BNXColors.darkPrimary : const Color(0xFFC2E7FF),
                        foregroundColor: isDark ? Colors.black : const Color(0xFF001D35),
                        elevation: 4,
                        child: const Icon(Icons.edit_outlined),
                      );
              })()
            : null,
        body: Stack(
          children: [
            Row(
              children: [
                // 1. LEFT SIDEBAR (Hidden on mobile)
                if (!isMobile)
                  AnimatedContainer(
                    duration: BNXConstants.animationDurationFast,
                    width: activeSidebarWidth,
                    child: const Sidebar(),
                  ),

                // Divider between sidebar and center panel (Hidden on mobile)
                if (!isMobile)
                  VerticalDivider(
                    width: 1,
                    color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
                  ),

                // 2. CENTER PANEL CONTAINER (Top Bar + Main Page Child + Right Side Utility Panel)
                Expanded(
                  child: SafeArea(
                    top: isMobile,
                    bottom: false,
                    child: Column(
                      children: [
                        // Top App Bar - Hide in Settings, Profile, Colab, or Help
                        if (currentRoute != '/profile' &&
                            uiState.activeFolder != 'Settings' &&
                            uiState.activeFolder != 'Colab' &&
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
                                        topLeft: Radius.circular(BNXConstants.borderRadiusL),
                                      ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? BNXColors.darkSurface : Colors.white,
                                    borderRadius: isMobile 
                                        ? BorderRadius.zero 
                                        : const BorderRadius.only(
                                            topLeft: Radius.circular(BNXConstants.borderRadiusL),
                                          ),
                                    boxShadow: isMobile ? null : BNXConstants.softShadow,
                                  ),
                                  child: child,
                                ),
                              ),
                            ),

                            // Expandable Right Utility Panel (e.g. Calendar)
                            if (showRightPanel)
                              _buildExpandableRightPanel(context, ref, uiState, isDark),

                            // Far Right Rail (Mini icons)
                            if (showRightRail)
                              _buildRightIconRail(context, ref, uiState, isDark),
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
    );
  }

  Widget _buildExpandableRightPanel(BuildContext context, WidgetRef ref, AppUiState uiState, bool isDark) {
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
        panelContent = _buildTasksPanel(isDark);
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
            padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 8),
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
                    ref.read(appUiProvider.notifier).setActiveRightUtility('none');
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

  Widget _buildRightIconRail(BuildContext context, WidgetRef ref, AppUiState uiState, bool isDark) {
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
              shape: isSelected ? NeumorphicShape.pressed : NeumorphicShape.flat,
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
          Consumer(builder: (context, ref, _) {
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
          }),
          const Divider(indent: 12, endIndent: 12, height: 24),
          // Plus icon to add add-ons
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Google Workspace Marketplace Add-ons...')),
              );
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
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ))
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
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
      currentRow.add(Expanded(
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
      ));
      
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
      children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: r,
      )).toList(),
    );
  }

  Widget _buildKeepPanel(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMiniCard(context, 'Design Checklist', '1. Corner radius 16\n2. Color code #F4F7FB\n3. Hover animations', Colors.teal),
        _buildMiniCard(context, 'Feedback on Compose', 'Make compose window float dynamically and support minimized state.', Colors.orange),
      ],
    );
  }

  Widget _buildContactsPanel(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.account_circle, color: Colors.blue),
          title: Text('Sarah Chen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text('sarah.chen@bnxmail.com', style: TextStyle(fontSize: 11)),
        ),
        ListTile(
          leading: Icon(Icons.account_circle, color: Colors.indigo),
          title: Text('Alex Rivera', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text('alex.rivera@techcorp.com', style: TextStyle(fontSize: 11)),
        ),
        ListTile(
          leading: Icon(Icons.account_circle, color: Colors.purple),
          title: Text('James Wilson', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text('james.wilson@design.com', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildTasksPanel(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTaskItem('Finish responsive draft view', true),
        _buildTaskItem('Deploy frontend build to github pages', false),
        _buildTaskItem('Resolve dark mode typography constraints', false),
      ],
    );
  }

  Widget _buildMiniCard(BuildContext context, String title, String body, Color color) {
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
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(String task, bool done) {
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Colors.green : Colors.grey,
        size: 20,
      ),
      title: Text(
        task,
        style: TextStyle(
          fontSize: 13,
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? Colors.grey : null,
        ),
      ),
    );
  }
}
