import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/app_state_provider.dart';
import '../../data/email_provider.dart';
import '../../data/account_provider.dart';
import '../../models/email_model.dart';
import '../theme/colors.dart';
import '../theme/neumorphic.dart';
import 'create_label_dialog.dart';
import 'bnx_calculator.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  bool _isMoreExpanded = false;

  Set<String> get _activeToolNames => ref.watch(appUiProvider).activeToolNames;

  void _toggleTool(String toolLabel, bool isEnabled) {
    if (isEnabled) {
      ref.read(appUiProvider.notifier).removeActiveTool(toolLabel);
    } else {
      ref.read(appUiProvider.notifier).addActiveTool(toolLabel);
    }
  }

  // Master list of all available tools
  final List<Map<String, dynamic>> _allTools = [
    {
      'icon': Icons.calculate_rounded,
      'label': 'Calculator',
      'color': Color(0xFF27AE60),
    },
    {
      'icon': Icons.calendar_today_rounded,
      'label': 'Calendar',
      'color': Color(0xFFF2994A),
    },
    {
      'icon': Icons.people_alt_rounded,
      'label': 'Contacts',
      'color': Color(0xFF2F80ED),
    },
    {
      'icon': Icons.translate_rounded,
      'label': 'Translate',
      'color': Color(0xFFEB5757),
    },
    {
      'icon': Icons.wb_sunny_rounded,
      'label': 'Weather',
      'color': Color(0xFFF2C94C),
    },
    {
      'icon': Icons.newspaper_rounded,
      'label': 'News',
      'color': Color(0xFF56CCF2),
    },
  ];

  String? get _expandedUtilityTab => ref.watch(appUiProvider).activeLeftUtility;
  set _expandedUtilityTab(String? val) {
    ref.read(appUiProvider.notifier).setActiveLeftUtility(val);
  }

  bool _showCustomizer = false;

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final emails = ref.watch(emailListProvider);
    final isDark = uiState.isDarkMode;
    final customLabels = ref.watch(customLabelsProvider);

    final activeAccount = ref.watch(activeAccountProvider);

    bool isSentEmail(EmailModel e) {
      if (e.isTrash || e.memberOfFolders.contains('Trash')) return false;
      if (e.isDraft || e.memberOfFolders.contains('Draft')) return false;
      final userEmail = activeAccount.email.trim().toLowerCase();
      final userName = activeAccount.name.trim().toLowerCase();
      final senderEmail = e.senderEmail.trim().toLowerCase();
      final senderName = e.senderName.trim().toLowerCase();
      final isSenderMatch =
          (userEmail.isNotEmpty && senderEmail == userEmail) ||
          (userName.isNotEmpty && senderName == userName);

      if (e.isSent) {
        if (senderEmail.isNotEmpty && userEmail.isNotEmpty && !isSenderMatch) {
          return false;
        }
        return true;
      }
      if (e.memberOfFolders.contains('Sent')) {
        if (senderEmail.isNotEmpty && userEmail.isNotEmpty && !isSenderMatch) {
          return false;
        }
        return true;
      }
      return isSenderMatch;
    }

    // Helper counts
    final int primaryCount = emails
        .where(
          (e) =>
              e.memberOfFolders.contains('Inbox') &&
              !e.memberOfFolders.contains('Trash') &&
              !isSentEmail(e),
        )
        .length;
    final int allInboxesCount = emails
        .where((e) => !e.isTrash && !e.memberOfFolders.contains('Trash') && !isSentEmail(e))
        .length;
    final int sentCount = emails.where((e) => isSentEmail(e)).length;
    final int draftCount =
        emails.where((e) => (e.isDraft || e.memberOfFolders.contains('Draft')) && !e.isTrash).length;
    final int archiveCount = emails
        .where(
          (e) =>
              (e.isArchive || e.memberOfFolders.contains('Archive')) &&
              !e.isTrash &&
              !e.memberOfFolders.contains('Trash'),
        )
        .length;
    final int starredCount = emails
        .where((e) => (e.isStarred || e.memberOfFolders.contains('Starred')) && !e.isTrash)
        .length;
    final int spamCount =
        emails.where((e) => e.memberOfFolders.contains('Spam') && !e.isTrash).length;
    final int trashCount =
        emails.where((e) => e.memberOfFolders.contains('Trash') || e.isTrash).length;
    final jobKeywords = activeAccount.getKeywords();
    final int jobMailsCount = emails
        .where(
          (e) =>
              !e.isTrash &&
              jobKeywords.any(
                (kw) =>
                    '${e.subject} ${e.body} ${e.senderName} ${e.senderEmail}'
                        .toLowerCase()
                        .contains(kw),
              ),
        )
        .length;

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    final labelsVis = uiState.sidebarLabelVisibility;

    final List<Widget> importantFolderTiles = [
      if (labelsVis['Inbox'] ?? true)
        _buildPillTile(
          icon: Icons.all_inbox_rounded,
          title: 'All Inboxes',
          isSelected: uiState.activeFolder == 'All Inboxes',
          badgeText: allInboxesCount > 0 ? '$allInboxesCount' : null,
          onTap: () => navigateToFolder('All Inboxes', '/'),
        ),
      if (labelsVis['Inbox'] ?? true)
        _buildPillTile(
          icon: Icons.inbox_outlined,
          title: 'Primary',
          isSelected: uiState.activeFolder == 'Inbox',
          badgeText: primaryCount > 0 ? '$primaryCount' : null,
          onTap: () => navigateToFolder('Inbox', '/'),
        ),
      _buildPillTile(
        icon: Icons.local_offer_outlined,
        title: 'Promotions',
        isSelected: uiState.activeFolder == 'Promotions',
        onTap: () => navigateToFolder('Promotions', '/'),
      ),
      _buildPillTile(
        icon: Icons.people_outline_rounded,
        title: 'Social',
        isSelected: uiState.activeFolder == 'Social',
        onTap: () => navigateToFolder('Social', '/'),
      ),
      _buildPillTile(
        icon: Icons.info_outline_rounded,
        title: 'Updates',
        isSelected: uiState.activeFolder == 'Updates',
        onTap: () => navigateToFolder('Updates', '/'),
      ),
      _buildPillTile(
        icon: Icons.work_outline_rounded,
        title: 'Job Mails',
        isSelected: uiState.activeFolder == 'Job Mails',
        badgeText: jobMailsCount > 0 ? '$jobMailsCount' : null,
        onTap: () => navigateToFolder('Job Mails', '/'),
      ),
      if (labelsVis['Starred'] ?? true)
        _buildPillTile(
          icon: Icons.star_outline_rounded,
          title: 'Starred',
          isSelected: uiState.activeFolder == 'Starred',
          badgeText: starredCount > 0 ? '$starredCount' : null,
          onTap: () => navigateToFolder('Starred', '/'),
        ),
      if (labelsVis['Sent'] ?? true)
        _buildPillTile(
          icon: Icons.send_outlined,
          title: 'Sent',
          isSelected: uiState.activeFolder == 'Sent',
          badgeText: sentCount > 0 ? '$sentCount' : null,
          onTap: () => navigateToFolder('Sent', '/'),
        ),
      if (labelsVis['Draft'] ?? true)
        _buildPillTile(
          icon: Icons.file_present_outlined,
          title: 'Drafts',
          isSelected: uiState.activeFolder == 'Draft',
          badgeText: draftCount > 0 ? '$draftCount' : null,
          onTap: () => navigateToFolder('Draft', '/'),
        ),
    ];

    final int importantCount = emails.where((e) => e.isStarred && !e.isTrash).length;
    final int purchasesCount = emails
        .where(
          (e) =>
              !e.isTrash &&
              (e.labels.contains('Purchases') ||
                  e.subject.toLowerCase().contains('payment') ||
                  e.subject.toLowerCase().contains('order')),
        )
        .length;

    final List<Widget> otherFolderTiles = [
      if (labelsVis['Snoozed'] ?? true)
        _buildPillTile(
          icon: Icons.access_time_rounded,
          title: 'Snoozed',
          isSelected: uiState.activeFolder == 'Snoozed',
          onTap: () => navigateToFolder('Snoozed', '/'),
        ),
      _buildPillTile(
        icon: Icons.label_important_outline_rounded,
        title: 'Important',
        isSelected: uiState.activeFolder == 'Important',
        badgeText: importantCount > 0 ? '$importantCount' : null,
        onTap: () => navigateToFolder('Important', '/'),
      ),
      _buildPillTile(
        icon: Icons.shopping_bag_outlined,
        title: 'Purchases',
        isSelected: uiState.activeFolder == 'Purchases',
        badgeText: purchasesCount > 0 ? '$purchasesCount' : null,
        onTap: () => navigateToFolder('Purchases', '/'),
      ),
      _buildPillTile(
        icon: Icons.schedule_send_outlined,
        title: 'Scheduled',
        isSelected: uiState.activeFolder == 'Scheduled',
        onTap: () => navigateToFolder('Scheduled', '/'),
      ),
      _buildPillTile(
        icon: Icons.outbox_outlined,
        title: 'Outbox',
        isSelected: uiState.activeFolder == 'Outbox',
        onTap: () => navigateToFolder('Outbox', '/'),
      ),
      _buildPillTile(
        icon: Icons.archive_outlined,
        title: 'Archive',
        isSelected: uiState.activeFolder == 'Archive',
        badgeText: archiveCount > 0 ? '$archiveCount' : null,
        onTap: () => navigateToFolder('Archive', '/'),
      ),
      _buildPillTile(
        icon: Icons.mail_outline_rounded,
        title: 'All Mail',
        isSelected: uiState.activeFolder == 'All Mail',
        onTap: () => navigateToFolder('All Mail', '/'),
      ),
      _buildPillTile(
        icon: Icons.report_gmailerrorred_outlined,
        title: 'Spam',
        isSelected: uiState.activeFolder == 'Spam',
        badgeText: spamCount > 0 ? '$spamCount' : null,
        onTap: () => navigateToFolder('Spam', '/'),
      ),
      if (labelsVis['Trash'] ?? true)
        _buildPillTile(
          icon: Icons.delete_outline_rounded,
          title: 'Trash',
          isSelected: uiState.activeFolder == 'Trash',
          badgeText: trashCount > 0 ? '$trashCount' : null,
          onTap: () => navigateToFolder('Trash', '/'),
        ),
      _buildPillTile(
        icon: Icons.bar_chart_outlined,
        title: 'Analytics',
        isSelected: uiState.activeFolder == 'Analytics',
        onTap: () => navigateToFolder('Analytics', '/analytics'),
      ),
      _buildPillTile(
        icon: Icons.assignment_outlined,
        title: 'Templates',
        isSelected: uiState.activeFolder == 'Templates',
        onTap: () => navigateToFolder('Templates', '/'),
      ),
    ];

    // If Chat/Colab section is active, show the specialized sidebar as per the screenshot
    if (uiState.activeFolder == 'Chat' || uiState.activeFolder == 'Casbox') {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isMobile
              ? Brightness.light
              : (isDark ? Brightness.light : Brightness.dark),
          statusBarBrightness: isMobile
              ? Brightness.dark
              : (isDark ? Brightness.dark : Brightness.light),
        ),
        child: Drawer(
          backgroundColor: isDark
              ? BNXColors.darkBg
              : const Color(0xFFEAF2F9), // slightly blended background
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // --- TOP BLUE SECTION (SAME AS MAIN SIDEBAR) ---
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 20,
                    20,
                    24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF195bac), Color(0xFF2471D4)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/logo.jpg',
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.mail,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'BNXmail',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildDynamicBitToolRail(isDark),
                    ],
                  ),
                ),
                // Make the rest of the drawer scrollable to avoid overflow
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // --- UTILITY PANEL (shows when a tool is tapped) ---
                      _buildSlidingTabPanel(isDark),
                      const SizedBox(height: 8),
                      // "Casbox" section button
                      _buildPillTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Casbox',
                        isSelected: uiState.activeFolder == 'Casbox',
                        onTap: () => navigateToFolder('Casbox', '/colab'),
                      ),
                      // "Colab" section button
                      _buildPillTile(
                        icon: Icons.people_alt_outlined,
                        title: 'Colab',
                        isSelected: uiState.activeFolder == 'Chat',
                        onTap: () => navigateToFolder('Chat', '/colab'),
                      ),
                      const SizedBox(height: 16),
                      // Bottom sections: Settings and Help & Support
                      _buildPillTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        isSelected: uiState.activeFolder == 'Settings',
                        onTap: () => navigateToFolder('Settings', '/settings'),
                      ),
                      _buildPillTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        isSelected: uiState.activeFolder == 'Help',
                        onTap: () => navigateToFolder('Help', '/help'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isMobile
            ? Brightness.light
            : (isDark ? Brightness.light : Brightness.dark),
        statusBarBrightness: isMobile
            ? Brightness.dark
            : (isDark ? Brightness.dark : Brightness.light),
      ),
      child: Drawer(
        backgroundColor: isDark ? BNXColors.darkBg : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // --- TOP BLUE SECTION (BRANDING + DYNAMIC BIT TOOL RAIL) ---
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 20,
                  20,
                  24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF195bac), Color(0xFF2471D4)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/logo.jpg',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.mail,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'BNXmail',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDynamicBitToolRail(isDark),
                  ],
                ),
              ),

              // --- MAIN LIST CONTENT ---
              const SizedBox(height: 8),
              _buildSlidingTabPanel(isDark),
              _buildPremiumComposeButton(isDark, uiState),
              const SizedBox(height: 8),
              ...importantFolderTiles,
              if (!_isMoreExpanded)
                _buildPillTile(
                  icon: Icons.keyboard_arrow_down_rounded,
                  title: 'Show more',
                  isSelected: false,
                  onTap: () => setState(() => _isMoreExpanded = true),
                )
              else ...[
                ...otherFolderTiles,
                _buildPillTile(
                  icon: Icons.keyboard_arrow_up_rounded,
                  title: 'Show less',
                  isSelected: false,
                  onTap: () => setState(() => _isMoreExpanded = false),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(indent: 16, endIndent: 16, thickness: 0.8),
              ),
              _buildLabelsHeader(isDark),
              ...customLabels.map(
                (l) => _buildPillTile(
                  icon: uiState.activeLabel == l.name
                      ? Icons.label_rounded
                      : Icons.label_outline_rounded,
                  iconColor: l.color,
                  title: l.name,
                  isSelected: uiState.activeLabel == l.name,
                  trailing: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 36),
                    onSelected: (val) {
                      if (val == 'edit') {
                        CreateLabelDialog.show(context, labelToEdit: l);
                      } else if (val == 'delete') {
                        ref
                            .read(customLabelsProvider.notifier)
                            .deleteLabel(l.id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Edit', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(fontSize: 14, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    ref.read(appUiProvider.notifier).selectLabel(l.name);
                    final scaffold = Scaffold.maybeOf(context);
                    if (scaffold != null && scaffold.isDrawerOpen) {
                      Navigator.pop(context);
                    }
                    context.go('/home');
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(indent: 16, endIndent: 16, thickness: 0.8),
              ),
              _buildPillTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                isSelected: uiState.activeFolder == 'Settings',
                onTap: () => navigateToFolder('Settings', '/settings'),
              ),
              _buildPillTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                isSelected: uiState.activeFolder == 'Help',
                onTap: () => navigateToFolder('Help', '/help'),
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'BNX Mail v1.1.0',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicBitToolRail(bool isDark) {
    if (_showCustomizer) {
      // Inline edit mode: shows all tools with selection indicator
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Bit Tool static logo at the start (Customizer mode)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Image.asset(
                        'assets/bit_tool_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF195bac),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  ..._allTools.map((tool) {
                    final bool isEnabled = _activeToolNames.contains(
                      tool['label'],
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _toggleTool(tool['label'], isEnabled),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isEnabled
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isEnabled
                                      ? Colors.transparent
                                      : Colors.white30,
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                tool['icon'],
                                color: isEnabled
                                    ? const Color(0xFF195BAC)
                                    : Colors.white.withValues(alpha: 0.4),
                                size: 16,
                              ),
                            ),
                            if (isEnabled)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // CHECKMARK ICON TO FINISH CUSTOMIZATION
                  GestureDetector(
                    onTap: () => setState(() => _showCustomizer = false),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF195BAC),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Normal mode: shows active tools only + static logo + '+' icon
    final List<Map<String, dynamic>> activeTools = _allTools
        .where((t) => _activeToolNames.contains(t['label']))
        .toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Bit Tool static logo at the start (Normal mode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/bit_tool_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF195bac),
                        size: 16,
                      ),
                    ),
                  ),
                ),
                ...activeTools.map((tool) {
                  final bool isActive = _expandedUtilityTab == tool['label'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _expandedUtilityTab = isActive
                            ? null
                            : tool['label'],
                      ),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          tool['icon'],
                          color: isActive
                              ? const Color(0xFF195BAC)
                              : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  );
                }),
                // PLUS ICON FOR CUSTOMIZATION
                GestureDetector(
                  onTap: () => setState(() => _showCustomizer = true),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPillTile({
    required IconData icon,
    required String title,
    required bool isSelected,
    String? badgeText,
    Color? iconColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color activeColor = Color(0xFF195BAC);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ??
                    (isSelected
                        ? activeColor
                        : (isDark ? Colors.white70 : Colors.black54)),
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? activeColor
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              if (badgeText != null)
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeColor : Colors.grey,
                  ),
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumComposeButton(bool isDark, dynamic uiState) {
    if (uiState.activeFolder == 'Templates') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          context.push('/compose');
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: const Row(
            children: [
              SizedBox(width: 20),
              Icon(Icons.edit_outlined, color: Color(0xFF195BAC), size: 24),
              SizedBox(width: 16),
              Text(
                'Compose',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF195BAC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabelsHeader(bool isDark) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 8, 16, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'CUSTOM LABELS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        GestureDetector(
          onTap: () => _showCreateLabelDialog(context),
          child: Icon(
            Icons.add,
            size: 16,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    ),
  );

  Widget _buildSlidingTabPanel(bool isDark) {
    if (_expandedUtilityTab == null) return const SizedBox.shrink();
    Widget content;
    switch (_expandedUtilityTab) {
      case 'Calculator':
        content = BNXCalculatorWidget(isDark: isDark);
        break;
      case 'Calendar':
        content = SidebarCalendarWidget(isDark: isDark);
        break;
      case 'Contacts':
        content = SidebarContactsWidget(isDark: isDark);
        break;
      case 'Translate':
        content = SidebarTranslateWidget(isDark: isDark);
        break;
      case 'Weather':
        content = SidebarWeatherWidget(isDark: isDark);
        break;
      case 'News':
        content = SidebarNewsWidget(isDark: isDark);
        break;
      default:
        content = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: NeumorphicContainer(
        borderRadius: 20,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _expandedUtilityTab!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF195BAC),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expandedUtilityTab = null),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            content,
          ],
        ),
      ),
    );
  }

  void _showCreateLabelDialog(BuildContext context) {
    CreateLabelDialog.show(context);
  }

  void navigateToFolder(String folderName, String routePath) {
    ref.read(appUiProvider.notifier).selectFolder(folderName);
    ref.read(appUiProvider.notifier).selectEmail(null);
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) Navigator.pop(context);

    // Normalize '/' targets to go to '/home'
    final targetRoute = routePath == '/' ? '/home' : routePath;
    if (GoRouterState.of(context).uri.toString() != targetRoute) {
      context.go(targetRoute);
    }
  }
}

// ==========================================
// --- ADDITIONAL UTILITY WIDGETS ---
// ==========================================

class SidebarCalendarWidget extends StatefulWidget {
  final bool isDark;
  const SidebarCalendarWidget({super.key, required this.isDark});

  @override
  State<SidebarCalendarWidget> createState() => _SidebarCalendarWidgetState();
}

class _SidebarCalendarWidgetState extends State<SidebarCalendarWidget> {
  int _selectedDay = 14;
  final Map<int, List<String>> _events = {
    14: ['14:00 - Project Review', '16:30 - Antigravity Sync'],
    15: ['10:00 - UI Design Alignment', '15:00 - Client Call'],
    16: ['11:30 - Tech Refinement Session'],
    17: ['13:00 - Team Lunch'],
    18: ['09:00 - Release Checkpoint'],
  };
  final TextEditingController _eventController = TextEditingController();

  @override
  void dispose() {
    _eventController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isDark ? Colors.amber : const Color(0xFF195BAC);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'July 2026',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        _buildGrid(),
        const Divider(height: 20),
        Text(
          "SCHEDULE FOR JULY $_selectedDay",
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        ...?_events[_selectedDay]?.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              children: [
                Icon(Icons.lens, size: 6, color: themeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(event, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        if (_events[_selectedDay] == null || _events[_selectedDay]!.isEmpty)
          const Text(
            'No events scheduled.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _eventController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Add new event...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle, color: themeColor),
              onPressed: () {
                final txt = _eventController.text.trim();
                if (txt.isNotEmpty) {
                  setState(() {
                    _events.putIfAbsent(_selectedDay, () => []).add(txt);
                    _eventController.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final List<Widget> days = [];
    // Start Wednesday July 1st (Sun=0, Mon=1, Tue=2, Wed=3 offset)
    for (int i = 0; i < 3; i++) {
      days.add(const SizedBox.shrink());
    }
    for (int d = 1; d <= 31; d++) {
      final isSelected = d == _selectedDay;
      final hasEvent = _events[d] != null && _events[d]!.isNotEmpty;
      days.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDay = d),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF195BAC) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasEvent && !isSelected
                    ? Colors.blue.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$d',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected || hasEvent
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (widget.isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.2,
      children: days,
    );
  }
}

class SidebarContactsWidget extends ConsumerStatefulWidget {
  final bool isDark;
  const SidebarContactsWidget({super.key, required this.isDark});

  @override
  ConsumerState<SidebarContactsWidget> createState() =>
      _SidebarContactsWidgetState();
}

class _SidebarContactsWidgetState extends ConsumerState<SidebarContactsWidget> {
  final List<Map<String, String>> _contacts = [
    {'name': 'Sarah Chen', 'email': 'sarah.chen@bnxmail.com', 'initial': 'SC'},
    {
      'name': 'Alex Rivera',
      'email': 'alex.rivera@techcorp.com',
      'initial': 'AR',
    },
    {
      'name': 'James Wilson',
      'email': 'james.wilson@design.com',
      'initial': 'JW',
    },
    {'name': 'John Doe', 'email': 'john.doe@bnxmail.com', 'initial': 'JD'},
  ];
  String _searchQuery = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _showAddForm = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _contacts
        .where(
          (c) =>
              c['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c['email']!.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Search contacts...',
            prefixIcon: const Icon(Icons.search, size: 16),
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final c = filtered[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: Text(
                    c['initial']!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                title: Text(
                  c['name']!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  c['email']!,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.mail_outline,
                    size: 16,
                    color: Color(0xFF195BAC),
                  ),
                  onPressed: () {
                    ref
                        .read(appUiProvider.notifier)
                        .updateComposeDraft(to: c['email']!);
                    Navigator.pop(context);
                    context.push('/compose');
                  },
                ),
              );
            },
          ),
        ),
        const Divider(),
        if (_showAddForm) ...[
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Name',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Email',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showAddForm = false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final email = _emailController.text.trim();
                  if (name.isNotEmpty && email.isNotEmpty) {
                    setState(() {
                      final parts = name.split(' ');
                      final initial = parts
                          .map((p) => p.isNotEmpty ? p[0] : '')
                          .join()
                          .toUpperCase();
                      _contacts.add({
                        'name': name,
                        'email': email,
                        'initial': initial.isNotEmpty ? initial : '?',
                      });
                      _nameController.clear();
                      _emailController.clear();
                      _showAddForm = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF195BAC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                child: const Text('Save', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ] else
          TextButton.icon(
            onPressed: () => setState(() => _showAddForm = true),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add Contact', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: const Color(0xFF195BAC),
            ),
          ),
      ],
    );
  }
}

class SidebarTranslateWidget extends StatefulWidget {
  final bool isDark;
  const SidebarTranslateWidget({super.key, required this.isDark});

  @override
  State<SidebarTranslateWidget> createState() => _SidebarTranslateWidgetState();
}

class _SidebarTranslateWidgetState extends State<SidebarTranslateWidget> {
  final TextEditingController _inputController = TextEditingController();
  String _translatedText = '';
  String _targetLang = 'Spanish';

  final Map<String, Map<String, String>> _mockDb = {
    'hello': {
      'French': 'Bonjour',
      'Spanish': 'Hola',
      'German': 'Hallo',
      'Japanese': 'こんにちは (Konnichiwa)',
    },
    'thank you': {
      'French': 'Merci',
      'Spanish': 'Gracias',
      'German': 'Danke',
      'Japanese': 'ありがとう (Arigatou)',
    },
    'how are you': {
      'French': 'Comment ça va?',
      'Spanish': '¿Cómo estás?',
      'German': 'Wie geht es dir?',
      'Japanese': 'お元気ですか (Ogenki desu ka)',
    },
    'good morning': {
      'French': 'Bonjour',
      'Spanish': 'Buenos días',
      'German': 'Guten Morgen',
      'Japanese': 'おはようございます (Ohayou gozaimasu)',
    },
  };

  void _translate() {
    final input = _inputController.text.trim().toLowerCase();
    if (input.isEmpty) {
      setState(() => _translatedText = '');
      return;
    }
    if (_mockDb.containsKey(input)) {
      setState(() => _translatedText = _mockDb[input]![_targetLang]!);
    } else {
      setState(
        () => _translatedText =
            '[$_targetLang] ${input[0].toUpperCase()}${input.substring(1)} (Simulated)',
      );
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'To: ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _targetLang,
              isDense: true,
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
              dropdownColor: widget.isDark
                  ? BNXColors.darkSurface
                  : Colors.white,
              underline: const SizedBox.shrink(),
              items: ['French', 'Spanish', 'German', 'Japanese'].map((
                String lang,
              ) {
                return DropdownMenuItem<String>(value: lang, child: Text(lang));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _targetLang = val;
                    if (_inputController.text.isNotEmpty) _translate();
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _inputController,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Type word (e.g. hello, thank you)...',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (_) => _translate(),
        ),
        if (_translatedText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _targetLang.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _translatedText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class SidebarWeatherWidget extends StatefulWidget {
  final bool isDark;
  const SidebarWeatherWidget({super.key, required this.isDark});

  @override
  State<SidebarWeatherWidget> createState() => _SidebarWeatherWidgetState();
}

class _SidebarWeatherWidgetState extends State<SidebarWeatherWidget> {
  String _selectedCity = 'New York';
  bool _useCelsius = true;

  final Map<String, Map<String, dynamic>> _weatherData = {
    'New York': {
      'temp': 24,
      'cond': 'Partly Cloudy',
      'icon': Icons.wb_cloudy_rounded,
      'humidity': '62%',
      'wind': '12 km/h',
    },
    'London': {
      'temp': 18,
      'cond': 'Light Rain',
      'icon': Icons.grain_rounded,
      'humidity': '80%',
      'wind': '15 km/h',
    },
    'Tokyo': {
      'temp': 28,
      'cond': 'Sunny',
      'icon': Icons.wb_sunny_rounded,
      'humidity': '50%',
      'wind': '8 km/h',
    },
    'Paris': {
      'temp': 21,
      'cond': 'Clear',
      'icon': Icons.wb_sunny_outlined,
      'humidity': '58%',
      'wind': '10 km/h',
    },
    'Mumbai': {
      'temp': 30,
      'cond': 'Thunderstorm',
      'icon': Icons.thunderstorm_rounded,
      'humidity': '85%',
      'wind': '22 km/h',
    },
  };

  @override
  Widget build(BuildContext context) {
    final data = _weatherData[_selectedCity]!;
    final int baseTemp = data['temp'];
    final displayTemp = _useCelsius
        ? baseTemp
        : ((baseTemp * 9 / 5) + 32).round();
    final unit = _useCelsius ? '°C' : '°F';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _weatherData.keys.map((city) {
              final isSel = city == _selectedCity;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(city, style: const TextStyle(fontSize: 10)),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCity = city);
                  },
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              data['icon'] as IconData,
              size: 36,
              color: Colors.orangeAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCity,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    data['cond'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  '$displayTemp$unit',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _useCelsius = !_useCelsius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _useCelsius ? '°F' : '°C',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Humidity: ${data['humidity']}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              'Wind: ${data['wind']}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class SidebarNewsWidget extends StatefulWidget {
  final bool isDark;
  const SidebarNewsWidget({super.key, required this.isDark});

  @override
  State<SidebarNewsWidget> createState() => _SidebarNewsWidgetState();
}

class _SidebarNewsWidgetState extends State<SidebarNewsWidget> {
  int _expandedIndex = -1;
  final List<Map<String, String>> _news = [
    {
      'title': 'BNX Mail v1.1.0 Released!',
      'summary':
          'The next-generation neumorphic email client now boasts inline widgets, customizable dynamic bit rails, and improved state synchronizations.',
      'time': '2h ago',
    },
    {
      'title': 'Market Hits Historic Highs',
      'summary':
          'Technology shares rally today, pushing indices to new records. AI and SaaS providers lead the market expansion.',
      'time': '5h ago',
    },
    {
      'title': 'Remote Collaboration Study',
      'summary':
          'A recent workplace survey reveals that integrated inline utilities (calendars, quick calculators) boost developer daily workflow efficiency by 24%.',
      'time': '1d ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(_news.length, (idx) {
        final item = _news[idx];
        final isExpanded = _expandedIndex == idx;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : idx),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['title']!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        item['time']!,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      item['summary']!,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
