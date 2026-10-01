import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../core/widgets/sidebar.dart';
import '../../../core/widgets/top_search_bar.dart';
import '../../../core/widgets/compose_dialog.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../models/account_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/email_provider.dart';
import '../../../data/all_inboxes_provider.dart';
import '../../auth/presentation/notifiers/auth_notifier.dart';
import '../../../core/widgets/notification_centre_panel.dart';
import '../../../core/widgets/bnx_calculator.dart';
import '../../../core/widgets/virtual_keyboard.dart';

final isEditingPinsProvider = StateProvider<bool>((ref) => false);
final isVirtualKeyboardOpenProvider = StateProvider<bool>((ref) => false);
final globalNotesListProvider = StateProvider<List<Map<String, String>>>(
  (ref) => [],
);
final weatherDetectedProvider = StateProvider<bool>((ref) => false);

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final isVirtualKeyboardOpen = ref.watch(isVirtualKeyboardOpenProvider);

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final bool isDesktopOS =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    final bool isTablet =
        screenWidth >= 600 && screenWidth < BNXConstants.desktopBreakpoint;

    // Auto collapse sidebar on tablet screens (ONLY for mobile/web tablets, never macOS or Windows desktop)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMobile && !isDesktopOS) {
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
        : (isDesktopOS
              ? BNXConstants.sidebarExpandedWidth
              : (uiState.isSidebarCollapsed
                    ? (uiState.activeLeftUtility != null
                          ? BNXConstants.sidebarCollapsedWidth + 280.0
                          : BNXConstants.sidebarCollapsedWidth)
                    : BNXConstants.sidebarExpandedWidth));

    final bool showRightRail = !isMobile;
    final bool isRightRailVisible = isDesktopOS
        ? ref.watch(desktopRightRailVisibleProvider)
        : showRightRail;
    final bool showRightPanel =
        uiState.activeRightUtility != 'none' && !isMobile && screenWidth > 950;

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
                  padding: const EdgeInsets.only(bottom: 92.0),
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
              if (isDesktopOS)
                Column(
                  children: [
                    _buildDesktopTopHeader(
                      context,
                      ref,
                      uiState,
                      currentRoute,
                      isDark,
                    ),
                    Expanded(
                      child: Container(
                        color: isDark
                            ? BNXColors.darkBg
                            : const Color(0xFFE9F4FF),
                        child: Row(
                          children: [
                            if (!isProfile && !isManageAccount)
                              AnimatedContainer(
                                duration: BNXConstants.animationDurationFast,
                                width: activeSidebarWidth,
                                child: const Sidebar(),
                              ),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? BNXColors.darkSurface
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isDark ? 0.2 : 0.04,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: child,
                                    ),
                                  ),
                                  if (showRightPanel)
                                    _buildExpandableRightPanel(
                                      context,
                                      ref,
                                      uiState,
                                      isDark,
                                    ),
                                ],
                              ),
                            ),
                            if (isRightRailVisible)
                              _buildRightIconRail(
                                context,
                                ref,
                                uiState,
                                isDark,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
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
                        top:
                            isMobile &&
                            currentRoute != '/profile' &&
                            currentRoute != '/manage-account',
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
                                          transitionBuilder:
                                              (
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

              // 4. FLOATING VIRTUAL KEYBOARD (Desktop only, overlays bottom right matching Image 1)
              if (isDesktopOS && isVirtualKeyboardOpen)
                Positioned(
                  right: 68,
                  bottom: 20,
                  child: VirtualKeyboardWidget(
                    onClose: () {
                      ref.read(isVirtualKeyboardOpenProvider.notifier).state =
                          false;
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TOP DESKTOP HEADER (Solid Blue bar matching reference image) ---
  Widget _buildDesktopTopHeader(
    BuildContext context,
    WidgetRef ref,
    AppUiState uiState,
    String currentRoute,
    bool isDark,
  ) {
    final activeAccount = ref.watch(activeAccountProvider);
    final isColab = currentRoute == '/colab';

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF195BAC),
      child: Row(
        children: [
          // 1. Logo + Brand
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.jpg',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.mail_rounded,
                  color: Color(0xFF195BAC),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'BNXmail',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 48),

          // 2. Compose Pill Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref
                    .read(appUiProvider.notifier)
                    .setComposeStatus(ComposeStatus.normal);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF202124),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Compose',
                      style: TextStyle(
                        color: Color(0xFF202124),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // 3. Center Mail / Chat pill switcher
          Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mail tab
                InkWell(
                  onTap: () {
                    if (isColab) {
                      context.go('/home');
                      ref.read(appUiProvider.notifier).selectFolder('Inbox');
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: !isColab ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Mail',
                      style: TextStyle(
                        color: !isColab
                            ? const Color(0xFF195BAC)
                            : Colors.white,
                        fontWeight: !isColab
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                // Chat tab
                InkWell(
                  onTap: () {
                    if (!isColab) {
                      context.go('/colab');
                      ref.read(appUiProvider.notifier).selectFolder('Casbox');
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isColab ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Chat',
                      style: TextStyle(
                        color: isColab ? const Color(0xFF195BAC) : Colors.white,
                        fontWeight: isColab ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 4. Search mail...
          Container(
            width: 200,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Search mail...',
                      hintStyle: TextStyle(color: Colors.white60, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    onChanged: (val) {
                      ref.read(appUiProvider.notifier).setSearchQuery(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 5. User Profile (Highlighted Account Tab)
          InkWell(
            onTap: () =>
                _showAccountMenuPopup(context, ref, activeAccount, isDark),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarWidget(
                    name: activeAccount.name.isNotEmpty
                        ? activeAccount.name
                        : 'ravinew2004',
                    avatarUrl: activeAccount.avatarUrl,
                    size: 26,
                    fontSize: 11,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    activeAccount.name.isNotEmpty
                        ? activeAccount.name
                        : 'ravinew2004',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          // Vertical divider between account and bit tool button
          Container(
            height: 20,
            width: 1.2,
            color: Colors.white.withValues(alpha: 0.35),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),

          // 6. Bit Tool Round Toggle Button with bit_tool_logo.png
          Tooltip(
            message: 'Toggle Bit Tool Rail',
            child: InkWell(
              onTap: () {
                ref
                    .read(desktopRightRailVisibleProvider.notifier)
                    .update((v) => !v);
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/bit_tool_logo.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF195BAC),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final bool isBeta = uiState.activeRightUtility == 'Beta';
    final String panelTitle =
        (uiState.activeRightUtility == 'Keep' ||
            uiState.activeRightUtility == 'Notes')
        ? 'Notes'
        : (uiState.activeRightUtility == 'Calculator'
              ? 'BNX Calculator'
              : (uiState.activeRightUtility == 'Weather' ||
                    uiState.activeRightUtility == 'Cloud')
              ? 'Weather'
              : (isBeta ? 'BETA' : uiState.activeRightUtility));

    final double panelWidth = uiState.activeRightUtility == 'Calculator'
        ? 340
        : (isBeta ? 330 : 300);

    switch (uiState.activeRightUtility) {
      case 'Beta':
        panelContent = _buildBetaPanel(context, ref, isDark);
        break;
      case 'Notes':
      case 'Keep':
        panelContent = _buildNotesPanel(context, ref, isDark);
        break;
      case 'Calendar':
        panelContent = _buildCalendarPanel(context, isDark);
        break;
      case 'Contacts':
        panelContent = _buildContactsPanel(isDark);
        break;
      case 'Calculator':
        panelContent = SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: BNXCalculatorWidget(isDark: isDark),
        );
        break;
      case 'Weather':
      case 'Cloud':
        panelContent = _buildWeatherPanel(context, ref, isDark);
        break;
      case 'Notifications':
        panelContent = const NotificationCentrePanel();
        break;
      default:
        panelContent = _buildNotesPanel(context, ref, isDark);
    }

    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? BNXColors.darkBorder : const Color(0xFFE2E8F0),
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
              right: 12,
              top: 12,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  panelTitle,
                  style: TextStyle(
                    fontWeight: isBeta ? FontWeight.w900 : FontWeight.bold,
                    fontSize: isBeta ? 22 : 15,
                    color: isBeta
                        ? const Color(0xFF195BAC)
                        : (isDark ? Colors.white : Colors.black87),
                    letterSpacing: isBeta ? -0.5 : 0,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBeta) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          'EDIT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    InkWell(
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('none');
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFF1F5F9),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: panelContent),
        ],
      ),
    );
  }

  // --- BETA ECOSYSTEM PANEL MATCHING IMAGE 2 ---
  Widget _buildBetaPanel(BuildContext context, WidgetRef ref, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Tab switcher: FAVORITES | RECENT
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FAVORITES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 72,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              '|',
              style: TextStyle(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'RECENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Apps Row under FAVORITES
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBetaAppItem(
              name: 'Cliks',
              imageAsset: 'assets/cliks_logo.png',
              fallbackIcon: Icons.verified_user_rounded,
              color: const Color(0xFF059669),
              isDark: isDark,
            ),
            _buildBetaAppItem(
              name: 'BNXmail',
              imageAsset: 'assets/bnx_mail_logo.png',
              fallbackIcon: Icons.mark_email_read_rounded,
              color: const Color(0xFF195BAC),
              isDark: isDark,
            ),
            _buildBetaAppItem(
              name: 'Bit-Tool',
              imageAsset: 'assets/bit_tool_logo.png',
              fallbackIcon: Icons.tune_rounded,
              color: const Color(0xFF2563EB),
              isDark: isDark,
            ),
            _buildBetaAppItem(
              name: 'B2Auth',
              customIcon: _buildB2AuthIcon(isDark),
              fallbackIcon: Icons.shield_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Section: BASE  PUBLIC | BUSINESS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BASE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                decoration: TextDecoration.underline,
                decorationThickness: 2,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PUBLIC',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
                Text(
                  '  |  ',
                  style: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    fontSize: 10,
                  ),
                ),
                Text(
                  'BUSINESS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Apps Grid under BASE
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBetaAppItem(
              name: 'Cliks',
              imageAsset: 'assets/cliks_logo.png',
              fallbackIcon: Icons.verified_user_rounded,
              color: const Color(0xFF059669),
              isDark: isDark,
              showCard: true,
            ),
            _buildBetaAppItem(
              name: 'BNXmail',
              imageAsset: 'assets/bnx_mail_logo.png',
              fallbackIcon: Icons.mark_email_read_rounded,
              color: const Color(0xFF195BAC),
              isDark: isDark,
              showCard: true,
            ),
            _buildBetaAppItem(
              name: 'Bit-Tool',
              imageAsset: 'assets/bit_tool_logo.png',
              fallbackIcon: Icons.tune_rounded,
              color: const Color(0xFF2563EB),
              isDark: isDark,
              showCard: true,
            ),
            _buildBetaAppItem(
              name: 'B2Auth',
              customIcon: _buildB2AuthIcon(isDark),
              fallbackIcon: Icons.shield_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              isDark: isDark,
              showCard: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildBetaAppItem(
            name: 'CliksBusin...',
            imageAsset: 'assets/cliks_business_img.png',
            fallbackIcon: Icons.check_circle_rounded,
            color: const Color(0xFF059669),
            isDark: isDark,
            showCard: true,
          ),
        ),
        const SizedBox(height: 28),

        // Beta Labs Release Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? BNXColors.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/bnx_mail_logo.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'BETA LABS RELEASE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'COMING SOON',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4F46E5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Building the next generation of Beta applications.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Footer
        Center(
          child: Text(
            'BETA ECOSYSTEM · FUTURE READY',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildB2AuthIcon(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 32,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
        Icon(
          Icons.fingerprint_rounded,
          size: 16,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
      ],
    );
  }

  Widget _buildBetaAppItem({
    required String name,
    String? imageAsset,
    Widget? customIcon,
    IconData? fallbackIcon,
    Color? color,
    required bool isDark,
    bool showCard = false,
  }) {
    return SizedBox(
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: showCard
                ? BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? BNXColors.darkBorder
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.04,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            alignment: Alignment.center,
            child:
                customIcon ??
                (imageAsset != null
                    ? Image.asset(
                        imageAsset,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => Icon(
                          fallbackIcon ?? Icons.apps,
                          color: color ?? const Color(0xFF195BAC),
                          size: 26,
                        ),
                      )
                    : Icon(
                        fallbackIcon ?? Icons.apps,
                        color: color ?? const Color(0xFF195BAC),
                        size: 26,
                      )),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- NOTES PANEL MATCHING IMAGE 1 ---
  Widget _buildNotesPanel(BuildContext context, WidgetRef ref, bool isDark) {
    final notes = ref.watch(globalNotesListProvider);

    return Column(
      children: [
        // Global Notes Section Header matching Image 1
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Icon(
                Icons.folder_open_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Global Notes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Add Note',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      _showAddNoteDialog(context, ref, isDark);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFEF3C7),
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Center content: if empty, show "No notes found" exactly like Image 1
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 68,
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notes found',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  note['title'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final updated =
                                      List<Map<String, String>>.from(notes)
                                        ..removeAt(index);
                                  ref
                                          .read(
                                            globalNotesListProvider.notifier,
                                          )
                                          .state =
                                      updated;
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if ((note['body'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              note['body'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref, bool isDark) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Global Note',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Note Title...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write note content here...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final current = ref.read(globalNotesListProvider);
                ref.read(globalNotesListProvider.notifier).state = [
                  ...current,
                  {
                    'title': titleController.text.trim(),
                    'body': bodyController.text.trim(),
                  },
                ];
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  // --- WEATHER PANEL MATCHING IMAGE 2 ---
  Widget _buildWeatherPanel(BuildContext context, WidgetRef ref, bool isDark) {
    final weatherDetected = ref.watch(weatherDetectedProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: weatherDetected
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wb_sunny_rounded,
                    size: 48,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '28°C',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Partly Sunny • Bengaluru',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'High: 31°C   Low: 21°C\nHumidity: 58% • Wind: 12 km/h',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(weatherDetectedProvider.notifier).state = false;
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00B4D8),
                      side: const BorderSide(color: Color(0xFF00B4D8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Change Location',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cyan Sun + Cloud Weather Icon matching Image 2
                  SizedBox(
                    width: 64,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: const [
                        Positioned(
                          top: 0,
                          child: Icon(
                            Icons.wb_sunny_outlined,
                            size: 34,
                            color: Color(0xFF00B4D8),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Icon(
                            Icons.cloud_outlined,
                            size: 40,
                            color: Color(0xFF00B4D8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Local Weather',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Allow location access to see the current weather in your area.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(weatherDetectedProvider.notifier).state = true;
                    },
                    icon: const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Detect Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- BIT TOOL RIGHT RAIL MATCHING IMAGES 1, 2, 3, 4 ---
  Widget _buildRightIconRail(
    BuildContext context,
    WidgetRef ref,
    AppUiState uiState,
    bool isDark,
  ) {
    final activeUtil = uiState.activeRightUtility;
    final bool isEditingPins = ref.watch(isEditingPinsProvider);
    final bool isVirtualKeyboardOpen = ref.watch(isVirtualKeyboardOpenProvider);

    Widget circleRailItem({
      required String name,
      required Widget iconWidget,
      required Color borderColor,
      required String tooltip,
      required VoidCallback onTap,
      Color? bgColor,
      bool isActive = false,
    }) {
      final isSelected = isActive || activeUtil == name;

      return Tooltip(
        message: tooltip,
        preferBelow: false,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    bgColor ??
                    (isDark ? const Color(0xFF1E293B) : Colors.white),
                border: Border.all(
                  color: isSelected ? const Color(0xFF195BAC) : borderColor,
                  width: isSelected ? 2.0 : 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: iconWidget,
            ),
          ),
        ),
      );
    }

    Widget bottomCircleButton({
      required IconData icon,
      required String tooltip,
      required bool isActive,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: tooltip,
        preferBelow: false,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF195BAC)
                      : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                  width: isActive ? 1.8 : 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: isActive
                    ? const Color(0xFF195BAC)
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkBg : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? BNXColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Scrollable Pin items area to strictly prevent any RenderFlex overflow
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  if (isEditingPins) ...[
                    // Top EDIT PINS label matching Image 2
                    InkWell(
                      onTap: () {
                        ref.read(isEditingPinsProvider.notifier).state = false;
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          'EDIT\nPINS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF1E293B),
                            letterSpacing: 0.5,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 1. Calendar (Amber/Orange)
                    circleRailItem(
                      name: 'Calendar',
                      tooltip: 'Calendar',
                      borderColor: const Color(0xFFFDE68A),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFFFFBEB),
                      iconWidget: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Calendar');
                      },
                    ),

                    // 2. BNX Calculator (Green)
                    circleRailItem(
                      name: 'Calculator',
                      tooltip: 'BNX Calculator',
                      borderColor: const Color(0xFFA7F3D0),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFECFDF5),
                      iconWidget: const Icon(
                        Icons.calculate_outlined,
                        color: Color(0xFF10B981),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Calculator');
                      },
                    ),

                    // 3. Contacts (Blue)
                    circleRailItem(
                      name: 'Contacts',
                      tooltip: 'Contacts & Teams',
                      borderColor: const Color(0xFFBFDBFE),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                      iconWidget: const Icon(
                        Icons.people_alt_outlined,
                        color: Color(0xFF3B82F6),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Contacts');
                      },
                    ),

                    // 4. Notes (Yellow)
                    circleRailItem(
                      name: 'Notes',
                      tooltip: 'Notes',
                      borderColor: const Color(0xFFFDE68A),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFFFFBEB),
                      iconWidget: const Icon(
                        Icons.note_alt_outlined,
                        color: Color(0xFFF59E0B),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Notes');
                      },
                    ),

                    // 5. Keyboard (Purple)
                    circleRailItem(
                      name: 'Keyboard',
                      tooltip: 'Virtual Keyboard',
                      isActive: isVirtualKeyboardOpen,
                      borderColor: const Color(0xFFC7D2FE),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEEF2FF),
                      iconWidget: const Icon(
                        Icons.keyboard_alt_outlined,
                        color: Color(0xFF6366F1),
                        size: 19,
                      ),
                      onTap: () {
                        ref.read(isVirtualKeyboardOpenProvider.notifier).state =
                            !isVirtualKeyboardOpen;
                      },
                    ),

                    // 6. Weather (Cyan)
                    circleRailItem(
                      name: 'Weather',
                      tooltip: 'Weather',
                      borderColor: const Color(0xFFBAE6FD),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF0F9FF),
                      iconWidget: const Icon(
                        Icons.wb_sunny_outlined,
                        color: Color(0xFF0EA5E9),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Weather');
                      },
                    ),

                    // 7. Checkmark / Save (Green Filled circle matching Image 2)
                    Tooltip(
                      message: 'Finish Editing Pins',
                      preferBelow: false,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            ref.read(isEditingPinsProvider.notifier).state =
                                false;
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Normal Rail Mode matching Image 1:
                    // 1. Beta Ecosystem (B)
                    circleRailItem(
                      name: 'Beta',
                      tooltip: 'Beta Ecosystem',
                      borderColor: const Color(0xFF93C5FD),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                      iconWidget: const Text(
                        'B',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xFF195BAC),
                          height: 1.1,
                        ),
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Beta');
                      },
                    ),

                    // 2. Calendar (Soft Orange)
                    circleRailItem(
                      name: 'Calendar',
                      tooltip: 'Calendar',
                      borderColor: const Color(0xFFFDE68A),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFFFFBEB),
                      iconWidget: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Calendar');
                      },
                    ),

                    // 3. BNX Calculator (Soft Green) - Directly below Calendar
                    circleRailItem(
                      name: 'Calculator',
                      tooltip: 'BNX Calculator',
                      borderColor: const Color(0xFFA7F3D0),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFECFDF5),
                      iconWidget: const Icon(
                        Icons.calculate_outlined,
                        color: Color(0xFF10B981),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Calculator');
                      },
                    ),

                    // 4. Contacts / Colab (Soft Blue)
                    circleRailItem(
                      name: 'Contacts',
                      tooltip: 'Contacts & Teams',
                      borderColor: const Color(0xFFBFDBFE),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                      iconWidget: const Icon(
                        Icons.people_alt_outlined,
                        color: Color(0xFF3B82F6),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Contacts');
                      },
                    ),

                    // 5. Notes (Soft Yellow)
                    circleRailItem(
                      name: 'Notes',
                      tooltip: 'Notes',
                      borderColor: const Color(0xFFFDE68A),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFFFFBEB),
                      iconWidget: const Icon(
                        Icons.note_alt_outlined,
                        color: Color(0xFFF59E0B),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Notes');
                      },
                    ),

                    // 6. Keyboard (Soft Purple) - Toggles Virtual Keyboard
                    circleRailItem(
                      name: 'Keyboard',
                      tooltip: 'Virtual Keyboard',
                      isActive: isVirtualKeyboardOpen,
                      borderColor: const Color(0xFFC7D2FE),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEEF2FF),
                      iconWidget: const Icon(
                        Icons.keyboard_alt_outlined,
                        color: Color(0xFF6366F1),
                        size: 19,
                      ),
                      onTap: () {
                        ref.read(isVirtualKeyboardOpenProvider.notifier).state =
                            !isVirtualKeyboardOpen;
                      },
                    ),

                    // 7. Weather (Soft Cyan)
                    circleRailItem(
                      name: 'Weather',
                      tooltip: 'Weather',
                      borderColor: const Color(0xFFBAE6FD),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF0F9FF),
                      iconWidget: const Icon(
                        Icons.wb_sunny_outlined,
                        color: Color(0xFF0EA5E9),
                        size: 19,
                      ),
                      onTap: () {
                        ref
                            .read(appUiProvider.notifier)
                            .setActiveRightUtility('Weather');
                      },
                    ),

                    // 8. Plus icon (+) with dashed/dotted circular outline to customize pins
                    Tooltip(
                      message: 'Customize / Edit Pins (+)',
                      preferBelow: false,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            ref.read(isEditingPinsProvider.notifier).state =
                                true;
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1),
                                width: 1.4,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Divider before bottom actions matching Image 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Divider(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              height: 1,
            ),
          ),

          // Last second button: Pencil inside circle (toggles Virtual Keyboard)
          bottomCircleButton(
            icon: Icons.edit_outlined,
            tooltip: 'Virtual Keyboard',
            isActive: isVirtualKeyboardOpen,
            onTap: () {
              ref.read(isVirtualKeyboardOpenProvider.notifier).state =
                  !isVirtualKeyboardOpen;
            },
          ),

          // Last button down: Sliders inside circle (customizes Edit Pins)
          bottomCircleButton(
            icon: Icons.tune_rounded,
            tooltip: 'Customize Pins',
            isActive: isEditingPins,
            onTap: () {
              ref.read(isEditingPinsProvider.notifier).state = !isEditingPins;
            },
          ),
          const SizedBox(height: 8),
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

  Widget buildMiniCard(
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

  void showAddOnsMarketplaceDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final List<Map<String, dynamic>> addOns = [
              {
                'name': 'BNX Calculator',
                'desc': 'Scientific & GST calculator in utility rail.',
                'icon': Icons.calculate_outlined,
                'installed': true,
              },
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

  void _showAccountMenuPopup(
    BuildContext context,
    WidgetRef ref,
    AccountModel activeAccount,
    bool isDark,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (ctx) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(top: 52, right: 60),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with camera badge
                Stack(
                  children: [
                    AvatarWidget(
                      name: activeAccount.name,
                      avatarUrl: activeAccount.avatarUrl,
                      size: 72,
                      fontSize: 26,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  activeAccount.name.isNotEmpty
                      ? activeAccount.name
                      : 'ravinew2004',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeAccount.email.isNotEmpty
                      ? activeAccount.email
                      : 'ravinew2004@bnxmail.com',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                // Manage your account button
                InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/manage-account');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.manage_accounts_outlined,
                          size: 16,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF1E293B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Manage your account',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
                const SizedBox(height: 10),
                // Add another account
                _buildAccountPopupItem(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Add another account',
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/login');
                  },
                ),
                // Sign out of this account
                _buildAccountPopupItem(
                  icon: Icons.logout_rounded,
                  title: 'Sign out of this account',
                  isDark: isDark,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final activeEmail = activeAccount.email.isNotEmpty
                        ? activeAccount.email
                        : activeAccount.id;
                    await ref
                        .read(accountsProvider.notifier)
                        .signOutSingleAccount(
                          targetEmail: activeEmail,
                          ref: ref,
                          context: context,
                        );
                  },
                ),
                // Sign out of all accounts
                _buildAccountPopupItem(
                  icon: Icons.logout_rounded,
                  title: 'Sign out of all accounts',
                  isDark: isDark,
                  isDanger: true,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await AuthRepository.logout();
                    ref.read(emailProvider.notifier).clear();
                    ref.read(accountsProvider.notifier).clear();
                    ref.read(allInboxesProvider.notifier).clear();
                    ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountPopupItem({
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger
        ? const Color(0xFFDC2626)
        : (isDark ? Colors.white : const Color(0xFF1E293B));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isDanger ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
