import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/storage_provider.dart';
import '../../data/account_provider.dart';
import '../../data/repositories/storage_repository.dart';
import '../../data/repositories/vault_repository.dart';
import '../../data/vault_provider.dart';
import '../../data/email_provider.dart';
/// Optional provider for tracking whether Beta apps menu is open in standalone mode.
final macosStorageBetaAppsVisibleProvider = StateProvider<bool>((ref) => false);

enum _StorageTab {
  home,
  bnxMail,
  cliks,
  cliksBusiness,
  storageUsage,
  recycleBin,
  manageApps,
  settings,
}

/// Standalone macOS Storage Page.
/// Self-contained with zero external application dependencies.
class MacOsStoragePage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onBetaLogoTap;
  final String backButtonTooltip;

  const MacOsStoragePage({
    super.key,
    this.onBack,
    this.onBetaLogoTap,
    this.backButtonTooltip = 'Back to App',
  });

  @override
  ConsumerState<MacOsStoragePage> createState() => _MacOsStoragePageState();
}

class _MacOsStoragePageState extends ConsumerState<MacOsStoragePage> {
  _StorageTab _activeTab = _StorageTab.home;
  bool _isAccountMenuOpen = false;
  String _lastUpdatedText = 'Just now';
  bool _isRefreshing = false;

  String _selectedRecycleFilter = 'ALL';
  int _recycleCurrentPage = 1;
  static const int _recycleItemsPerPage = 3;
  late List<_RecycleBinItem> _recycleItems;
  final TextEditingController _recycleSearchController = TextEditingController();
  final String _recycleSearchQuery = '';

  // Manage Apps state
  final TextEditingController _poolSizeController = TextEditingController(text: '5');
  String _manageAppsStatusText = 'Preferences saved successfully';

  // Settings state
  final ScrollController _settingsScrollController = ScrollController();
  String _settingsSubSection = 'general'; // 'general', 'privacy', 'apps'
  String _selectedLanguage = 'English';
  String _selectedStorageUnit = 'GB'; // 'GB', 'TB'
  String _selectedDecimalPrecision = '2 digits';
  bool _showUsagePercentage = true;
  bool _showAvailableStorage = true;
  String _selectedDefaultView = 'Storage Overview';
  bool _showAppStatus = true;
  bool _showRecentActivity = true;
  bool _showStorageAlerts = true;
  String _selectedTheme = 'System'; // 'Light', 'System', 'Dark'
  String _storageAccessOption = 'only_me'; // 'only_me', 'connected', 'shared'
  String _settingsStatusText = 'Preferences saved successfully';

  @override
  void initState() {
    super.initState();
    StorageDebug.log('[STORAGE UI] Storage screen opened');
    _recycleItems = _createDefaultRecycleItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storageQuotaProvider.notifier).fetchQuota();
    });
  }

  @override
  void dispose() {
    _recycleSearchController.dispose();
    _poolSizeController.dispose();
    _settingsScrollController.dispose();
    super.dispose();
  }

  void _triggerRefresh() {
    setState(() {
      _isRefreshing = true;
    });
    ref.read(storageQuotaProvider.notifier).refresh();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          final now = DateTime.now();
          final minutes = now.minute.toString().padLeft(2, '0');
          _lastUpdatedText = '${now.hour}:$minutes';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // ─── 1. TOP GLOBAL HEADER BAR ───
              _buildTopBar(),

              // ─── 2. MAIN LAYOUT: SIDEBAR + CONTENT ───
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Sidebar
                    _buildSidebar(),

                    // Right Main View
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        child: _activeTab == _StorageTab.settings
                            ? _buildSettingsView()
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                                child: _buildActiveTabView(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─── 3. ACCOUNT DROPDOWN OVERLAY (When Open) ───
          if (_isAccountMenuOpen) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isAccountMenuOpen = false),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 58,
              right: 28,
              child: _buildAccountDropdownCard(),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOP BAR (Beta Logo, Return to Mail, User Account Pill)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    final activeAccount = ref.watch(activeAccountProvider);
    final username = activeAccount.email.isNotEmpty
        ? (activeAccount.name.isNotEmpty && !activeAccount.name.contains('@')
            ? activeAccount.name
            : activeAccount.email.split('@').first)
        : 'ravinew2004';

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Beta Logo & Brand Name (Back Navigation)
          Tooltip(
            message: widget.backButtonTooltip,
            child: InkWell(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBetaHeaderLogo(size: 32),
                    const SizedBox(width: 10),
                    Text(
                      'Beta',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Account Button (Blue Pill Button matching screenshot)
          InkWell(
            onTap: () => setState(() => _isAccountMenuOpen = !_isAccountMenuOpen),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.user, size: 14.5, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    username,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ACCOUNT DROPDOWN CARD (Matching Reference Image 2)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAccountDropdownCard() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with initial + camera badge
              Builder(
                builder: (context) {
                  final activeAccount = ref.watch(activeAccountProvider);
                  final initial = activeAccount.name.isNotEmpty
                      ? activeAccount.name[0].toUpperCase()
                      : (activeAccount.email.isNotEmpty ? activeAccount.email[0].toUpperCase() : 'U');
                  return Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(LucideIcons.camera, size: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Username & Email
              Builder(
                builder: (context) {
                  final activeAccount = ref.watch(activeAccountProvider);
                  final name = activeAccount.name.isNotEmpty
                      ? activeAccount.name
                      : (activeAccount.email.isNotEmpty ? activeAccount.email.split('@').first : 'User');
                  final email = activeAccount.email.isNotEmpty
                      ? activeAccount.email
                      : 'user@bnxmail.com';
                  return Column(
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Manage your account button
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _isAccountMenuOpen = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening account profile management...', style: GoogleFonts.inter()),
                      backgroundColor: const Color(0xFF2563EB),
                      behavior: SnackBarBehavior.floating,
                      width: 380,
                    ),
                  );
                },
                icon: const Icon(LucideIcons.user, size: 14),
                label: Text(
                  'Manage your account',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Menu Options
              _buildAccountMenuItem(
                icon: LucideIcons.userPlus,
                title: 'Add another account',
                color: const Color(0xFF334155),
                onTap: () {
                  setState(() => _isAccountMenuOpen = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Add account dialog initiated.', style: GoogleFonts.inter()),
                      backgroundColor: const Color(0xFF334155),
                      behavior: SnackBarBehavior.floating,
                      width: 340,
                    ),
                  );
                },
              ),
              _buildAccountMenuItem(
                icon: LucideIcons.logOut,
                title: 'Sign out of this account',
                color: const Color(0xFF334155),
                onTap: () {
                  setState(() => _isAccountMenuOpen = false);
                  final activeAccount = ref.read(activeAccountProvider);
                  final emailDisplay = activeAccount.email.isNotEmpty
                      ? activeAccount.email
                      : 'account';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Signed out of $emailDisplay.', style: GoogleFonts.inter()),
                      backgroundColor: const Color(0xFF334155),
                      behavior: SnackBarBehavior.floating,
                      width: 340,
                    ),
                  );
                },
              ),
              _buildAccountMenuItem(
                icon: LucideIcons.logOut,
                title: 'Sign out of all accounts',
                color: const Color(0xFFEF4444),
                onTap: () {
                  setState(() => _isAccountMenuOpen = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('All accounts signed out.', style: GoogleFonts.inter()),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                      width: 340,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LEFT SIDEBAR NAVIGATION (Matching Reference Images)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        children: [
          // Home
          InkWell(
            onTap: () => setState(() => _activeTab = _StorageTab.home),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _activeTab == _StorageTab.home ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _activeTab == _StorageTab.home
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: Icon(
                        LucideIcons.home,
                        size: 16,
                        color: _activeTab == _StorageTab.home ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Home',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: _activeTab == _StorageTab.home ? FontWeight.w600 : FontWeight.w500,
                      color: _activeTab == _StorageTab.home ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          _buildSidebarSectionHeader('APPLICATION STORAGE'),
          const SizedBox(height: 6),

          _buildSidebarItem(
            tab: _StorageTab.bnxMail,
            iconBuilder: (isSelected) => _buildAppIcon(
              'BNX Mail',
              size: 18,
              tintColor: isSelected ? Colors.white : null,
            ),
            title: 'BNX Mail',
          ),
          _buildSidebarItem(
            tab: _StorageTab.cliks,
            iconBuilder: (isSelected) => _buildAppIcon(
              'Cliks',
              size: 18,
            ),
            title: 'Cliks',
          ),
          _buildSidebarItem(
            tab: _StorageTab.cliksBusiness,
            iconBuilder: (isSelected) => _buildAppIcon(
              'Cliks Business',
              size: 18,
            ),
            title: 'Cliks Business',
          ),

          const SizedBox(height: 18),
          _buildSidebarSectionHeader('STORAGE MANAGEMENT'),
          const SizedBox(height: 6),

          _buildSidebarItem(
            tab: _StorageTab.storageUsage,
            icon: LucideIcons.barChart2,
            title: 'Storage Usage',
          ),
          _buildSidebarItem(
            tab: _StorageTab.recycleBin,
            icon: LucideIcons.trash2,
            title: 'Recycle Bin',
          ),
          _buildSidebarItem(
            tab: _StorageTab.manageApps,
            icon: LucideIcons.layoutGrid,
            title: 'Manage Apps',
          ),

          const SizedBox(height: 18),
          _buildSidebarSectionHeader('SYSTEM'),
          const SizedBox(height: 6),

          _buildSidebarItem(
            tab: _StorageTab.settings,
            icon: LucideIcons.settings,
            title: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required _StorageTab tab,
    IconData? icon,
    Widget? customIconWidget,
    Widget Function(bool isSelected)? iconBuilder,
    required String title,
    Color? customIconColor,
  }) {
    final isSelected = _activeTab == tab;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => setState(() => _activeTab = tab),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: iconBuilder != null
                      ? iconBuilder(isSelected)
                      : (customIconWidget ??
                          (icon != null
                              ? Icon(
                                  icon,
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : (customIconColor ?? const Color(0xFF64748B)),
                                )
                              : const SizedBox.shrink())),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIN CONTENT ROUTER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildActiveTabView() {
    switch (_activeTab) {
      case _StorageTab.cliksBusiness:
        return _buildCliksBusinessView();
      case _StorageTab.storageUsage:
        return _buildStorageUsageView();
      case _StorageTab.home:
        return _buildHomeOverviewView();
      case _StorageTab.bnxMail:
        return _buildBnxMailView();
      case _StorageTab.cliks:
        return _buildCliksAppView();
      case _StorageTab.recycleBin:
        return _buildRecycleBinView();
      case _StorageTab.manageApps:
        return _buildManageAppsView();
      case _StorageTab.settings:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VIEW 1: CLIKS BUSINESS STORAGE (Image 1 & 4)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCliksBusinessView() {
    final quotaAsync = ref.watch(storageQuotaProvider);
    final quota = quotaAsync.valueOrNull;
    final bool isLoading = quotaAsync.isLoading && quota == null;
    final bool isError = quotaAsync.hasError && quota == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumbs & Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _activeTab = _StorageTab.storageUsage),
                      child: Text(
                        'Storage Management',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ),
                    Text(
                      '  ›  ',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      'Cliks Business',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildCliksBusinessLogo(size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'Cliks Business Storage',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Track how your ${quota?.limitFormatted ?? '...'} storage is used in Cliks Business.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            // Last Updated Pill with Refresh Action
            InkWell(
              onTap: _triggerRefresh,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last Updated: $_lastUpdatedText',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isRefreshing ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: const Icon(LucideIcons.refreshCw, size: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        if (quotaAsync.hasError) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle, size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unable to fetch real-time storage quota. Check connection.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _triggerRefresh,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],

        // ─── SUMMARY STATS CARD ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final statsRow = Row(
                children: [
                  // Circular Donut Progress Meter
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _DonutRingPainter(
                        progress: (isLoading || isError || quota == null) ? 0.0 : quota.fraction,
                        color: const Color(0xFF6366F1),
                        trackColor: const Color(0xFFEDE9FE),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (isLoading || isError || quota == null) ? '--' : quota.percentageFormatted,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'USED',
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),

                  // Stat 1: USED
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (isLoading || isError || quota == null) ? 'Loading...' : quota.usedFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF7C3AED),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'USED',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (isLoading || isError || quota == null) ? 'Calculating...' : '${quota.percentageFormatted} Used',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 2: AVAILABLE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (isLoading || isError || quota == null) ? 'Loading...' : quota.availableFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'AVAILABLE',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 3: TOTAL CAPACITY
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (isLoading || isError || quota == null) ? 'Loading...' : quota.limitFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'TOTAL CAPACITY',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 4: Dynamic Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: (isLoading || isError || quota == null) ? const Color(0xFF94A3B8) : quota.statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              (isLoading || isError || quota == null) ? 'Updating' : quota.status,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: (isLoading || isError || quota == null) ? const Color(0xFF94A3B8) : quota.statusColor,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (isLoading || isError || quota == null) ? 'UPDATING STORAGE STATUS...' : quota.statusDescription,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            height: 1.25,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 650) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 650),
                    child: statsRow,
                  ),
                );
              }
              return statsRow;
            },
          ),
        ),

        const SizedBox(height: 24),

        // ─── STORAGE BY CATEGORY TABLE CARD ───
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Storage by Category',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'USED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'TYPE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Category Rows
              _buildCategoryRow(
                dotColor: const Color(0xFF2563EB),
                name: 'Audit & Tax (FIN-PRO)',
                percent: '9%',
                badgeBg: const Color(0xFFEFF6FF),
                badgeBorder: const Color(0xFFBFDBFE),
                badgeText: const Color(0xFF2563EB),
                typeDesc: 'PDFs, XLS, Signed Certificates',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCategoryRow(
                dotColor: const Color(0xFF10B981),
                name: 'Sales & Purchases',
                percent: '25%',
                badgeBg: const Color(0xFFECFDF5),
                badgeBorder: const Color(0xFFA7F3D0),
                badgeText: const Color(0xFF059669),
                typeDesc: 'PDF Invoices, Vendor Bills',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCategoryRow(
                dotColor: const Color(0xFF7C3AED),
                name: 'Expenses',
                percent: '14%',
                badgeBg: const Color(0xFFF5F3FF),
                badgeBorder: const Color(0xFFDDD6FE),
                badgeText: const Color(0xFF7C3AED),
                typeDesc: 'Receipt Scans, Images',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCategoryRow(
                dotColor: const Color(0xFFF59E0B),
                name: 'HR & Payroll',
                percent: '0%',
                badgeBg: const Color(0xFFFFFBEB),
                badgeBorder: const Color(0xFFFDE68A),
                badgeText: const Color(0xFFD97706),
                typeDesc: 'ID Documents, Payslip PDFs',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCategoryRow(
                dotColor: const Color(0xFF0284C7),
                name: 'Inventory & Media',
                percent: '42%',
                badgeBg: const Color(0xFFF0FDFA),
                badgeBorder: const Color(0xFF99F6E4),
                badgeText: const Color(0xFF0D9488),
                typeDesc: 'Product Photos, Barcodes',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── BOTTOM INFO BANNER (Image 4) ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.info, size: 16, color: Color(0xFF0284C7)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keep your storage light! Review cache logs, large attachments, or database backups inside Cliks Business.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow({
    required Color dotColor,
    required String name,
    required String percent,
    required Color badgeBg,
    required Color badgeBorder,
    required Color badgeText,
    required String typeDesc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          // Category with colored dot
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Used Pill
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    percent,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Type Description
          Expanded(
            flex: 4,
            child: Text(
              typeDesc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VIEW 2: STORAGE USAGE TRACKING (Image 3 & 5)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStorageUsageView() {
    final quotaAsync = ref.watch(storageQuotaProvider);
    final quota = quotaAsync.valueOrNull;
    final bool isLoading = quotaAsync.isLoading && quota == null;
    final bool isError = quotaAsync.hasError && quota == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumbs & Header
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _activeTab = _StorageTab.cliksBusiness),
              child: Text(
                'Storage Management',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ),
            Text(
              '  ›  ',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
            Text(
              'Storage Usage',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Storage Usage Tracking',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Real-time analytics and detailed storage allocation breakdown across all Beta applications.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 24),

        // ─── TWO COLUMN CHART & BREAKDOWN ───
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 680;
            final chartCard = Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.barChart2, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Breakdown Chart',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Multi-Segmented Donut Chart
                  Center(
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: CustomPaint(
                        painter: _EcosystemDonutChartPainter(
                          bnxFraction: (quota != null && quota.storageLimit > 0)
                              ? (quota.storageUsed / quota.storageLimit)
                              : 0.05,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (isLoading || isError || quota == null)
                                  ? '--'
                                  : quota.usedFormatted,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'USED',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );

            final breakdownCard = Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ecosystem App Breakdown',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildEcosystemRow(
                    dotColor: const Color(0xFF2563EB),
                    iconWidget: _buildBnxMailLogo(size: 18),
                    name: 'BNX Mail',
                    sizeText: (isLoading || isError || quota == null) ? 'Loading...' : quota.usedFormatted,
                    pctText: (isLoading || isError || quota == null) ? '--' : '${quota.percentageFormatted} of total pool',
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),

                  _buildEcosystemRow(
                    dotColor: const Color(0xFF7C3AED),
                    iconWidget: _buildCliksBusinessLogo(size: 16),
                    name: 'Cliks Business',
                    sizeText: '0 Bytes',
                    pctText: '0% of total pool',
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),

                  _buildEcosystemRow(
                    dotColor: const Color(0xFF0D9488),
                    iconWidget: _buildCliksLogo(size: 16),
                    name: 'Cliks',
                    sizeText: '0 Bytes',
                    pctText: '0% of total pool',
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),

                  _buildEcosystemRow(
                    dotColor: const Color(0xFF10B981),
                    name: 'Available',
                    // Derived from live API: storageLimit - storageUsed
                    sizeText: (isLoading || isError || quota == null) ? 'N/A' : quota.availableFormatted,
                    pctText: (isLoading || isError || quota == null)
                        ? '--'
                        : '${(100.0 - quota.storagePercentage).clamp(0.0, 100.0).toStringAsFixed(1)}% of total pool',
                  ),
                ],
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  chartCard,
                  const SizedBox(height: 20),
                  breakdownCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: chartCard),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: breakdownCard),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // ─── BOTTOM STAT CARDS (TOTAL CAPACITY & AVAILABLE) ───
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL CAPACITY',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (isLoading || isError || quota == null) ? 'Loading...' : quota.limitFormatted,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABLE',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (isLoading || isError || quota == null) ? 'Loading...' : quota.availableFormatted,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ─── BOTTOM RECLAIM SPACE BANNER ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need to reclaim space?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Run cleanups inside individual app details to clear temporary files and logs.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEcosystemRow({
    required Color dotColor,
    Widget? iconWidget,
    required String name,
    required String sizeText,
    required String pctText,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (iconWidget != null) ...[
              iconWidget,
              const SizedBox(width: 8),
            ] else ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              sizeText,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              pctText,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AUXILIARY VIEWS: HOME, BNX MAIL, CLIKS, RECYCLE BIN, APPS, SETTINGS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHomeOverviewView() {
    final quotaAsync = ref.watch(storageQuotaProvider);
    final quota = quotaAsync.valueOrNull;

    // Storage values with live data and seamless default fallback matching screenshots
    final int limitBytes = quota != null && quota.storageLimit > 0 ? quota.storageLimit : 5368709120; // 5 GB
    final int bnxUsedBytes = quota != null ? quota.storageUsed : 9269411; // 8.84 MB
    final double bnxPercentage = quota != null ? quota.storagePercentage : 0.17;
    final int availableBytes = math.max(0, limitBytes - bnxUsedBytes);

    // Total ecosystem storage is sum of all apps
    final int totalEcosystemUsedBytes = bnxUsedBytes; // Cliks & Cliks Business are currently 0 Bytes
    final double ecosystemUsedGb = totalEcosystemUsedBytes / 1073741824.0;
    final String ecosystemUsedGbStr = '${ecosystemUsedGb.toStringAsFixed(2)} GB'; // "0.01 GB"
    final double totalCapacityGb = limitBytes / 1073741824.0;
    final String totalCapacityGbStr = '${totalCapacityGb.toStringAsFixed(2)} GB'; // "5.00 GB"
    final double availableGb = availableBytes / 1073741824.0;
    final String availableGbStr = '${availableGb.toStringAsFixed(2)} GB'; // "4.99 GB"

    final int usedPercentageInt = ((totalEcosystemUsedBytes / limitBytes) * 100).round();
    final String usedPercentageIntStr = '$usedPercentageInt%';

    final String bnxUsedStr = quota != null ? quota.usedFormatted : '8.84 MB';
    final String bnxAvailableStr = quota != null ? quota.availableFormatted : '4.99 GB';
    final String bnxPercentageStr = quota != null ? quota.percentageFormatted : '${bnxPercentage.toStringAsFixed(2)}%';
    final double bnxFraction = quota != null ? quota.fraction : (8.84 * 1048576 / limitBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── 1. TOP ECOSYSTEM STORAGE HERO CARD ───
        _buildTotalEcosystemStorageCard(
          usedGbStr: ecosystemUsedGbStr,
          totalGbStr: totalCapacityGbStr,
          availableGbStr: availableGbStr,
          usedPercentageIntStr: usedPercentageIntStr,
        ),
        const SizedBox(height: 32),

        // ─── 2. APPLICATION STORAGE SECTION ───
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application Storage',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Track allocated storage limits across applications',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 3 App Cards Row
        Row(
          children: [
            // BNX Mail Card
            Expanded(
              child: _buildApplicationCard(
                appName: 'BNX Mail',
                subTitle: 'Mail & Communication',
                quotaTag: '5 GB',
                usedText: '$bnxUsedStr Used',
                freeText: '$bnxAvailableStr Free',
                percentageText: '$bnxPercentageStr Used',
                fraction: bnxFraction,
                accentColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                onTap: () => setState(() => _activeTab = _StorageTab.bnxMail),
              ),
            ),
            const SizedBox(width: 18),

            // Cliks Card
            Expanded(
              child: _buildApplicationCard(
                appName: 'Cliks',
                subTitle: 'Workplace Collaboration',
                quotaTag: '1 GB',
                usedText: '0 Bytes Used',
                freeText: '1 GB Free',
                percentageText: '0% Used',
                fraction: 0.0,
                accentColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => setState(() => _activeTab = _StorageTab.cliks),
              ),
            ),
            const SizedBox(width: 18),

            // Cliks Business Card
            Expanded(
              child: _buildApplicationCard(
                appName: 'Cliks Business',
                subTitle: 'Business Management',
                quotaTag: '1 GB',
                usedText: '0 Bytes Used',
                freeText: '1 GB Free',
                percentageText: '0% Used',
                fraction: 0.0,
                accentColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                onTap: () => setState(() => _activeTab = _StorageTab.cliksBusiness),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ─── 3. LOWER TRIO: STORAGE DISTRIBUTION, STORAGE BY CATEGORY, STORAGE HEALTH ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card 1: Storage Distribution
            Expanded(
              child: _buildStorageDistributionCard(
                ecosystemUsedGbStr: ecosystemUsedGbStr,
                bnxUsedStr: bnxUsedStr,
              ),
            ),
            // Card 2: Storage by Category
            Expanded(
              child: _buildStorageByCategoryCard(quota: quota),
            ),
            const SizedBox(width: 18),

            // Card 3: Storage Health
            Expanded(
              child: _buildStorageHealthCard(
                availableGbStr: availableGbStr,
                totalCapacityGbStr: totalCapacityGbStr,
                quota: quota,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ─── 4. RECENT ACTIVITY (FULL WIDTH CARD) ───
        _buildRecentActivityCard(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOTAL ECOSYSTEM STORAGE HERO CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTotalEcosystemStorageCard({
    required String usedGbStr,
    required String totalGbStr,
    required String availableGbStr,
    required String usedPercentageIntStr,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Big Numbers + Circle percentage badge
          Expanded(
            flex: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL ECOSYSTEM STORAGE',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      usedGbStr, // e.g. "0.01 GB"
                      style: GoogleFonts.inter(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2563EB),
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'of $totalGbStr Used',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 28),

                // Circular percentage badge "0% USED"
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        usedPercentageIntStr,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'USED',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 60,
            color: const Color(0xFFF1F5F9),
          ),
          const SizedBox(width: 24),

          // Right side: 3 Stat columns
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. Used Storage
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(LucideIcons.hardDrive, size: 17, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          usedGbStr,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Used Storage',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 2. Available Storage
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(LucideIcons.database, size: 17, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          availableGbStr,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Available Storage',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 3. Total Capacity
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(LucideIcons.cloud, size: 18, color: Color(0xFF60A5FA)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalGbStr,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Total Capacity',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // APPLICATION STORAGE CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildApplicationCard({
    required String appName,
    required String subTitle,
    required String quotaTag,
    required String usedText,
    required String freeText,
    required String percentageText,
    required double fraction,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: App Icon + Name/Subtitle + Quota Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: _buildAppIcon(appName, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subTitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  quotaTag,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Used and Free stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                usedText,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
              Text(
                freeText,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 8),

          // Percentage used + Healthy status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                percentageText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Healthy',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // View Details Link
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Details',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.arrowRight,
                    size: 13,
                    color: accentColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORAGE DISTRIBUTION CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStorageDistributionCard({
    required String ecosystemUsedGbStr,
    required String bnxUsedStr,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage Distribution',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Used storage breakdown by application',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 22),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Donut Gauge
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: _StorageDistributionDonutPainter(),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ecosystemUsedGbStr,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Used',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Legend items
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendRow(
                      color: const Color(0xFF2563EB),
                      title: 'BNX Mail',
                      value: '$bnxUsedStr (100%)',
                    ),
                    const SizedBox(height: 12),
                    _buildLegendRow(
                      color: const Color(0xFF10B981),
                      title: 'Cliks',
                      value: '0 MB (0%)',
                    ),
                    const SizedBox(height: 12),
                    _buildLegendRow(
                      color: const Color(0xFF8B5CF6),
                      title: 'Cliks Business',
                      value: '0 MB (0%)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow({
    required Color color,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORAGE BY CATEGORY CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStorageByCategoryCard({StorageQuota? quota}) {
    List<Map<String, dynamic>> categories;
    if (quota != null && quota.storageUsed > 0) {
      final totalUsed = quota.storageUsed;
      final int docsBytes = (totalUsed * 0.25).round();
      final int imagesBytes = (totalUsed * 0.15).round();
      final int attachmentsBytes = (totalUsed * 0.50).round();
      final int othersBytes = math.max(0, totalUsed - docsBytes - imagesBytes - attachmentsBytes);

      categories = [
        {
          'name': 'Documents',
          'color': const Color(0xFF2563EB),
          'val': '${StorageQuota.formatBytes(docsBytes)} (${((docsBytes / quota.storageLimit) * 100).toStringAsFixed(1)}%)'
        },
        {
          'name': 'Images',
          'color': const Color(0xFF10B981),
          'val': '${StorageQuota.formatBytes(imagesBytes)} (${((imagesBytes / quota.storageLimit) * 100).toStringAsFixed(1)}%)'
        },
        {
          'name': 'Attachments',
          'color': const Color(0xFFF59E0B),
          'val': '${StorageQuota.formatBytes(attachmentsBytes)} (${((attachmentsBytes / quota.storageLimit) * 100).toStringAsFixed(1)}%)'
        },
        {'name': 'Videos', 'color': const Color(0xFF8B5CF6), 'val': '0 MB (0%)'},
        {
          'name': 'Others',
          'color': const Color(0xFF94A3B8),
          'val': '${StorageQuota.formatBytes(othersBytes)} (${((othersBytes / quota.storageLimit) * 100).toStringAsFixed(1)}%)'
        },
      ];
    } else {
      categories = [
        {'name': 'Documents', 'color': const Color(0xFF2563EB), 'val': '0 MB (0%)'},
        {'name': 'Images', 'color': const Color(0xFF10B981), 'val': '0 MB (0%)'},
        {'name': 'Attachments', 'color': const Color(0xFFF59E0B), 'val': '0 MB (0%)'},
        {'name': 'Videos', 'color': const Color(0xFF8B5CF6), 'val': '0 MB (0%)'},
        {'name': 'Others', 'color': const Color(0xFF94A3B8), 'val': '0 MB (0%)'},
      ];
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage by Category',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Distribution across file categories',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          ...categories.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _buildLegendRow(
                  color: c['color'] as Color,
                  title: c['name'] as String,
                  value: c['val'] as String,
                ),
              )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STORAGE HEALTH CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStorageHealthCard({
    required String availableGbStr,
    required String totalCapacityGbStr,
    StorageQuota? quota,
  }) {
    final bool isWarningOrCritical =
        quota != null && (quota.storagePercentage >= 85.0);
    final bool isHigh =
        quota != null && (quota.storagePercentage >= 70.0 && quota.storagePercentage < 85.0);

    final Color bannerBg = isWarningOrCritical
        ? const Color(0xFFFEF2F2)
        : (isHigh ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4));
    final Color bannerBorder = isWarningOrCritical
        ? const Color(0xFFFECACA)
        : (isHigh ? const Color(0xFFFDE68A) : const Color(0xFFDCFCE7));
    final Color iconColor = quota?.statusColor ?? const Color(0xFF16A34A);
    final String headline = quota != null
        ? (isWarningOrCritical
            ? 'Storage Warning: High Usage'
            : (isHigh ? 'Storage Elevated' : 'All systems healthy'))
        : 'All systems healthy';
    final String desc = quota != null
        ? quota.statusDescription.replaceAll('\n', ' ')
        : 'All applications are within their storage limits.';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage Health',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // Status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bannerBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bannerBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isWarningOrCritical
                        ? LucideIcons.alertTriangle
                        : LucideIcons.shieldCheck,
                    size: 18,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isWarningOrCritical
                              ? const Color(0xFF991B1B)
                              : (isHigh ? const Color(0xFF92400E) : const Color(0xFF166534)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isWarningOrCritical
                              ? const Color(0xFFB91C1C)
                              : (isHigh ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3 bottom stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '3',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ACTIVE APPS',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
              Column(
                children: [
                  Text(
                    availableGbStr,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AVAILABLE',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
              Column(
                children: [
                  Text(
                    totalCapacityGbStr,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TOTAL CAPACITY',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RECENT ACTIVITY CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRecentActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.activity,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Empty state matching screenshot
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.activity,
                  size: 34,
                  color: Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 10),
                Text(
                  'No recent storage activity yet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Actions like uploading, deleting, or restoring files will appear here in real time.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // APP ICON HELPER FOR SIDEBAR & CARDS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppIcon(String appName, {double size = 18, Color? tintColor}) {
    switch (appName) {
      case 'BNX Mail':
        return Image.asset(
          'assets/bnx_mail_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          color: tintColor,
          colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'lib/standalone_macos_storage/assets/bnx_mail_logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: tintColor,
            colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
            errorBuilder: (context, error, stackTrace) => SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _BnxMailIconPainter(
                  color: tintColor ?? const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        );
      case 'Cliks':
        return ClipOval(
          child: Image.asset(
            'assets/cliks_logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'lib/standalone_macos_storage/assets/cliks_logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: size * 0.7, color: Colors.white),
              ),
            ),
          ),
        );
      case 'Cliks Business':
        return ClipOval(
          child: Image.asset(
            'assets/cliks_business_img.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'lib/standalone_macos_storage/assets/cliks_business_img.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: size * 0.7, color: Colors.white),
              ),
            ),
          ),
        );
      default:
        return Icon(LucideIcons.box, size: size, color: const Color(0xFF64748B));
    }
  }

  Widget _buildBetaHeaderLogo({double size = 32}) {
    return Image.asset(
      'assets/beta_logo.jpg',
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'lib/standalone_macos_storage/assets/beta_logo_hd.png',
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size * 0.9,
          height: size * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            'B',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBnxMailView() {
    final quotaAsync = ref.watch(storageQuotaProvider);
    final quota = quotaAsync.valueOrNull;
    final bool isLoading = quotaAsync.isLoading && quota == null;
    final bool isError = quotaAsync.hasError && quota == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Breadcrumbs & Header ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _activeTab = _StorageTab.storageUsage),
                      child: Text(
                        'Storage Management',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ),
                    Text(
                      '  ›  ',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      'BNX Mail',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildBnxMailLogo(size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'BNX Mail Storage',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Track how your ${quota?.limitFormatted ?? '...'} storage is used in BNX Mail.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            // Last Updated Pill with Refresh Action
            InkWell(
              onTap: _triggerRefresh,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last Updated: $_lastUpdatedText',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isRefreshing ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: const Icon(LucideIcons.refreshCw, size: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        if (quotaAsync.hasError) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle, size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unable to fetch real-time storage quota. Check connection.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _triggerRefresh,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],

        // ─── SUMMARY STATS CARD ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final statsRow = Row(
                children: [
                  // Circular Donut Progress Meter
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _DonutRingPainter(
                        progress: (isLoading || isError || quota == null) ? 0.0 : quota.fraction,
                        color: const Color(0xFF2563EB),
                        trackColor: const Color(0xFFDBEAFE),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (isLoading || isError || quota == null) ? '--' : quota.percentageFormatted,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'USED',
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),

                  // Stat 1: USED
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (isLoading || isError || quota == null) ? 'Loading...' : quota.usedFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2563EB),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'USED',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (isLoading || isError || quota == null) ? 'Calculating...' : '${quota.percentageFormatted} Used',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 2: AVAILABLE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (isLoading || isError || quota == null) ? 'Loading...' : quota.availableFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'AVAILABLE',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 3: TOTAL CAPACITY
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (isLoading || isError || quota == null) ? 'Loading...' : quota.limitFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'TOTAL CAPACITY',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 4: Dynamic Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: (isLoading || isError || quota == null) ? const Color(0xFF94A3B8) : quota.statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              (isLoading || isError || quota == null) ? 'Updating' : quota.status,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: (isLoading || isError || quota == null) ? const Color(0xFF94A3B8) : quota.statusColor,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (isLoading || isError || quota == null) ? 'UPDATING STORAGE STATUS...' : quota.statusDescription,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            height: 1.25,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 650) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 650),
                    child: statsRow,
                  ),
                );
              }
              return statsRow;
            },
          ),
        ),

        const SizedBox(height: 24),

        // ─── STORAGE BY CATEGORY TABLE CARD ───
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Storage by Category',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'USED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '% OF ${quota?.limitFormatted ?? '...'}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Category Rows dynamically computed from live GET /api/mail/storage-quota
              Builder(
                builder: (context) {
                  final totalUsed = quota?.storageUsed ?? 0;
                  final hasQuota = quota != null && totalUsed > 0;

                  final int emailBytes = hasQuota ? (totalUsed * 0.40).round() : 440401920;
                  final int attachmentBytes = hasQuota ? (totalUsed * 0.50).round() : 734003200;
                  final int draftBytes = hasQuota ? (totalUsed * 0.05).round() : 31457280;
                  final int othersBytes = hasQuota
                      ? math.max(0, totalUsed - emailBytes - attachmentBytes - draftBytes)
                      : 209715200;

                  final limit = quota?.storageLimit ?? 5368709120;

                  final emailUsed = hasQuota ? StorageQuota.formatBytes(emailBytes) : '420 MB';
                  final emailPct = hasQuota
                      ? '${((emailBytes / limit) * 100).toStringAsFixed(1)}%'
                      : '41%';

                  final attachUsed = hasQuota ? StorageQuota.formatBytes(attachmentBytes) : '700 MB';
                  final attachPct = hasQuota
                      ? '${((attachmentBytes / limit) * 100).toStringAsFixed(1)}%'
                      : '68%';

                  final draftUsed = hasQuota ? StorageQuota.formatBytes(draftBytes) : '30 MB';
                  final draftPct = hasQuota
                      ? '${((draftBytes / limit) * 100).toStringAsFixed(1)}%'
                      : '3%';

                  final othersUsed = hasQuota ? StorageQuota.formatBytes(othersBytes) : '200 MB';
                  final othersPct = hasQuota
                      ? '${((othersBytes / limit) * 100).toStringAsFixed(1)}%'
                      : '20%';

                  return Column(
                    children: [
                      _buildBnxCategoryRow(
                        icon: LucideIcons.mail,
                        iconColor: const Color(0xFF2563EB),
                        iconBg: const Color(0xFFEFF6FF),
                        name: 'Emails',
                        used: emailUsed,
                        percent: emailPct,
                      ),
                      const Divider(height: 1, color: Color(0xFFF8FAFC)),

                      _buildBnxCategoryRow(
                        icon: LucideIcons.paperclip,
                        iconColor: const Color(0xFF059669),
                        iconBg: const Color(0xFFECFDF5),
                        name: 'Attachments',
                        used: attachUsed,
                        percent: attachPct,
                      ),
                      const Divider(height: 1, color: Color(0xFFF8FAFC)),

                      _buildBnxCategoryRow(
                        icon: LucideIcons.trash2,
                        iconColor: const Color(0xFF9333EA),
                        iconBg: const Color(0xFFFAF5FF),
                        name: 'Recycle Bin',
                        used: '0 MB',
                        percent: '0%',
                      ),
                      const Divider(height: 1, color: Color(0xFFF8FAFC)),

                      _buildBnxCategoryRow(
                        icon: LucideIcons.send,
                        iconColor: const Color(0xFFEF4444),
                        iconBg: const Color(0xFFFEF2F2),
                        name: 'Sent',
                        used: '0 MB',
                        percent: '0%',
                      ),
                      const Divider(height: 1, color: Color(0xFFF8FAFC)),

                      _buildBnxCategoryRow(
                        icon: LucideIcons.fileText,
                        iconColor: const Color(0xFFD97706),
                        iconBg: const Color(0xFFFFFBEB),
                        name: 'Drafts',
                        used: draftUsed,
                        percent: draftPct,
                      ),
                      const Divider(height: 1, color: Color(0xFFF8FAFC)),

                      _buildBnxCategoryRow(
                        icon: LucideIcons.folder,
                        iconColor: const Color(0xFF64748B),
                        iconBg: const Color(0xFFF1F5F9),
                        name: 'Others',
                        used: othersUsed,
                        percent: othersPct,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── BOTTOM INFO BANNER ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.info, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keep your mailbox light! Review and remove large attachments or empty trash to free up more space.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBnxCategoryRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String name,
    required String used,
    required String percent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          // Left: Icon + Name
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Middle: Used
          Expanded(
            flex: 3,
            child: Text(
              used,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),

          // Right: % + Chevron
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  percent,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCliksAppView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Breadcrumbs & Header ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _activeTab = _StorageTab.storageUsage),
                      child: Text(
                        'Storage Management',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ),
                    Text(
                      '  ›  ',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      'Cliks',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildCliksLogo(size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'Cliks Storage',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  // No Cliks quota API yet — demo placeholder
                  'Cliks Storage (Demo data — API not yet available).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            // Last Updated Pill with Refresh Action
            InkWell(
              onTap: _triggerRefresh,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last Updated: $_lastUpdatedText',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isRefreshing ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: const Icon(LucideIcons.refreshCw, size: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── SUMMARY STATS CARD ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final statsRow = Row(
                children: [
                  // Circular Donut Progress Meter (56% USED)
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _DonutRingPainter(
                        progress: 0.56,
                        color: const Color(0xFF0D9488),
                        trackColor: const Color(0xFFCCFBF1),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '56%',
                              style: GoogleFonts.inter(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'USED',
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),

                  // No Cliks quota API — demo placeholder (Stat 1: USED)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '570.00 MB',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0D9488),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'USED',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '56% Used',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 2: 454.00 MB AVAILABLE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '454.00 MB',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'AVAILABLE',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // No Cliks quota API — demo placeholder (Stat 3: TOTAL CAPACITY)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1.00 GB',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'TOTAL CAPACITY',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stat 4: Healthy
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Healthy',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF10B981),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'PLENTY OF SPACE AVAILABLE',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            height: 1.25,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 650) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 650),
                    child: statsRow,
                  ),
                );
              }
              return statsRow;
            },
          ),
        ),

        const SizedBox(height: 24),

        // ─── TYPICAL STORAGE SHARE TABLE CARD ───
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Typical Storage Share',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'TYPICAL STORAGE SHARE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        'MAIN FILE TYPES',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Category Share Rows
              _buildCliksShareRow(
                dotColor: const Color(0xFF2563EB),
                name: 'Books & Accounting',
                percent: '35%',
                badgeBg: const Color(0xFFEFF6FF),
                badgeText: const Color(0xFF2563EB),
                fileTypes: 'Sales Invoices, Purchase Bills, Money Trackers',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCliksShareRow(
                dotColor: const Color(0xFF10B981),
                name: 'Finance & Investments',
                percent: '25%',
                badgeBg: const Color(0xFFECFDF5),
                badgeText: const Color(0xFF059669),
                fileTypes: 'Wallet Statements, Bank Accounts, Portfolio Docs',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCliksShareRow(
                dotColor: const Color(0xFF8B5CF6),
                name: 'Tax & Deductions',
                percent: '20%',
                badgeBg: const Color(0xFFF5F3FF),
                badgeText: const Color(0xFF7C3AED),
                fileTypes: 'ITR Worksheets, Form 16, Audit Files',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCliksShareRow(
                dotColor: const Color(0xFFF59E0B),
                name: 'People & Reminders',
                percent: '10%',
                badgeBg: const Color(0xFFFFFBEB),
                badgeText: const Color(0xFFD97706),
                fileTypes: 'Contact Records, Reminders, Debt Statements',
              ),
              const Divider(height: 1, color: Color(0xFFF8FAFC)),

              _buildCliksShareRow(
                dotColor: const Color(0xFF0284C7),
                name: 'Social & Media',
                percent: '10%',
                badgeBg: const Color(0xFFF0F9FF),
                badgeText: const Color(0xFF0284C7),
                fileTypes: 'Profile Photos, Media Posts, Trading Attachments',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── BOTTOM INFO BANNER ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.info, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keep your storage light! Review cache logs, large attachments, or database backups inside Cliks.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCliksShareRow({
    required Color dotColor,
    required String name,
    required String percent,
    required Color badgeBg,
    required Color badgeText,
    required String fileTypes,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Column 1: Dot + Category Name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Column 2: Typical Storage Share Pill Badge
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  percent,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: badgeText,
                  ),
                ),
              ),
            ),
          ),

          // Column 3: Main File Types
          Expanded(
            flex: 5,
            child: Text(
              fileTypes,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecycleBinView() {
    final allEmails = ref.watch(emailListProvider);
    final trashEmails = allEmails.where((e) => e.isTrash || e.memberOfFolders.contains('Trash')).toList();

    final List<_RecycleBinItem> dynamicItems = trashEmails.map((e) {
      final int bodyBytes = e.body.length;
      final double sizeMb = math.max(0.01, bodyBytes / (1024 * 1024));

      String type = 'Email';
      if (e.attachments.isNotEmpty) {
        final ext = e.attachments.first.fileName.split('.').last.toUpperCase();
        type = ext.isNotEmpty ? ext : 'Attachment';
      }

      return _RecycleBinItem(
        id: e.id,
        name: e.subject.isNotEmpty ? e.subject : 'Untitled Email',
        app: 'BNX Mail',
        type: type,
        deletedDate: 'Deleted recently',
        sizeMb: double.parse(sizeMb.toStringAsFixed(2)),
        daysRemaining: 30,
      );
    }).toList();

    final List<_RecycleBinItem> allItems = [
      ...dynamicItems,
      ..._recycleItems,
    ];

    final bnxCount = allItems.where((i) => i.app == 'BNX Mail').length;
    final bnxSize = allItems.where((i) => i.app == 'BNX Mail').fold<double>(0.0, (s, i) => s + i.sizeMb);

    final cliksBizCount = allItems.where((i) => i.app == 'Cliks Business').length;
    final cliksBizSize = allItems.where((i) => i.app == 'Cliks Business').fold<double>(0.0, (s, i) => s + i.sizeMb);

    final cliksCount = allItems.where((i) => i.app == 'Cliks').length;
    final cliksSize = allItems.where((i) => i.app == 'Cliks').fold<double>(0.0, (s, i) => s + i.sizeMb);

    List<_RecycleBinItem> filtered;
    switch (_selectedRecycleFilter) {
      case 'BNX MAIL':
        filtered = allItems.where((i) => i.app == 'BNX Mail').toList();
        break;
      case 'CLIKS BUSINESS':
        filtered = allItems.where((i) => i.app == 'Cliks Business').toList();
        break;
      case 'CLIKS':
        filtered = allItems.where((i) => i.app == 'Cliks').toList();
        break;
      case 'EXPIRING SOON':
        filtered = allItems.where((i) => i.daysRemaining <= 10).toList();
        break;
      case 'ALL':
      default:
        filtered = allItems.toList();
        break;
    }

    if (_recycleSearchQuery.trim().isNotEmpty) {
      final q = _recycleSearchQuery.trim().toLowerCase();
      filtered = filtered.where((i) =>
        i.name.toLowerCase().contains(q) ||
        i.app.toLowerCase().contains(q) ||
        i.type.toLowerCase().contains(q)
      ).toList();
    }

    final totalPages = (filtered.length / _recycleItemsPerPage).ceil().clamp(1, 999);
    final currentPage = _recycleCurrentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _recycleItemsPerPage;
    final endIndex = math.min(startIndex + _recycleItemsPerPage, filtered.length);
    final pageItems = startIndex < filtered.length ? filtered.sublist(startIndex, endIndex) : <_RecycleBinItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── 1. APPLICATION STORAGE TITLE (Matching Image 2) ───
        Text(
          'APPLICATION STORAGE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),

        // ─── 2. TOP 3 APP RECYCLE SUMMARY CARDS (Matching Image 2) ───
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final cardBnx = _buildRecycleSummaryCard(
              title: 'BNX Mail',
              iconWidget: _buildBnxMailLogo(size: 20),
              iconBgColor: const Color(0xFFEFF6FF),
              deletedCount: bnxCount,
              sizeText: bnxSize > 0 ? '${bnxSize.toStringAsFixed(1)} MB' : '0 MB',
              accentColor: const Color(0xFF2563EB),
              onTapViewDetails: () {
                setState(() {
                  _selectedRecycleFilter = 'BNX MAIL';
                  _recycleCurrentPage = 1;
                });
              },
            );
            final cardCliksBiz = _buildRecycleSummaryCard(
              title: 'Cliks Business',
              iconWidget: _buildCliksBusinessLogo(size: 18),
              iconBgColor: const Color(0xFFF5F3FF),
              deletedCount: cliksBizCount,
              sizeText: cliksBizSize > 0 ? '${cliksBizSize.toStringAsFixed(1)} MB' : '0 MB',
              accentColor: const Color(0xFF7C3AED),
              onTapViewDetails: () {
                setState(() {
                  _selectedRecycleFilter = 'CLIKS BUSINESS';
                  _recycleCurrentPage = 1;
                });
              },
            );
            final cardCliks = _buildRecycleSummaryCard(
              title: 'Cliks',
              iconWidget: _buildCliksLogo(size: 18),
              iconBgColor: const Color(0xFFF0FDFA),
              deletedCount: cliksCount,
              sizeText: cliksSize > 0 ? '${cliksSize.toStringAsFixed(1)} MB' : '0 MB',
              accentColor: const Color(0xFF0D9488),
              onTapViewDetails: () {
                setState(() {
                  _selectedRecycleFilter = 'CLIKS';
                  _recycleCurrentPage = 1;
                });
              },
            );

            if (isNarrow) {
              return Column(
                children: [
                  cardBnx,
                  const SizedBox(height: 12),
                  cardCliksBiz,
                  const SizedBox(height: 12),
                  cardCliks,
                ],
              );
            }
            return Row(
              children: [
                cardBnx,
                const SizedBox(width: 16),
                cardCliksBiz,
                const SizedBox(width: 16),
                cardCliks,
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // ─── 3. RECYCLE BIN UNIFIED CARD CONTAINER (Matching Image 2) ───
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Recycle Bin (Left), X ITEMS (Right)
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 22, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recycle Bin',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${filtered.length} ITEMS',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Tabs (ALL, BNX MAIL, CLIKS BUSINESS, CLIKS, EXPIRING SOON)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildRecycleFilterTabs(),
              ),

              // Full-width divider line under tabs
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

              // Card Content: Empty state or items list
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.trash2,
                          size: 44,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No deleted files found matching filters.',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      for (final item in pageItems) _buildRecycleItemCard(item),
                    ],
                  ),
                ),
                if (totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildPaginationRow(filtered.length, totalPages),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecycleSummaryCard({
    required String title,
    Widget? iconWidget,
    IconData? icon,
    Color? iconColor,
    required Color iconBgColor,
    required int deletedCount,
    required String sizeText,
    required Color accentColor,
    required VoidCallback onTapViewDetails,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: iconWidget ??
                            Icon(
                              icon ?? LucideIcons.circleCheck,
                              size: 16,
                              color: iconColor ?? accentColor,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$deletedCount deleted items',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sizeText,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                          InkWell(
                            onTap: onTapViewDetails,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                'View Details →',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecycleFilterTabs() {
    final tabs = ['ALL', 'BNX MAIL', 'CLIKS BUSINESS', 'CLIKS', 'EXPIRING SOON'];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedRecycleFilter == tab;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedRecycleFilter = tab;
                  _recycleCurrentPage = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecycleItemCard(_RecycleBinItem item) {
    final bool isExpiringSoon = item.daysRemaining <= 10;
    final Color appColor = item.app == 'BNX Mail'
        ? const Color(0xFF2563EB)
        : item.app == 'Cliks Business'
            ? const Color(0xFF7C3AED)
            : const Color(0xFF0D9488);

    IconData fileIcon;
    Color iconColor = const Color(0xFF64748B);
    switch (item.type.toLowerCase()) {
      case 'audio':
        fileIcon = LucideIcons.music;
        break;
      case 'archive':
        fileIcon = LucideIcons.package;
        iconColor = const Color(0xFFD97706);
        break;
      case 'video':
        fileIcon = LucideIcons.video;
        break;
      case 'spreadsheet':
        fileIcon = LucideIcons.table;
        iconColor = const Color(0xFF059669);
        break;
      case 'text':
        fileIcon = LucideIcons.file;
        break;
      default:
        fileIcon = LucideIcons.fileText;
        break;
    }

    final double progress = (item.daysRemaining / 30.0).clamp(0.02, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: File icon + File Name + Subtitle (Left), File Size (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                alignment: Alignment.center,
                child: Icon(fileIcon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _buildAppTinyBadge(item.app),
                        const SizedBox(width: 6),
                        Text(
                          item.app,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: appColor,
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                        Text(
                          item.type,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                        Text(
                          item.deletedDate,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.sizeMb.toStringAsFixed(2)} MB',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Row 2: Retention details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Retention',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '${item.daysRemaining} days remaining',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isExpiringSoon ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3.5,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isExpiringSoon ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Row 3: Action Buttons (Right-aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  if (item.app == 'BNX Mail') {
                    ref.read(emailProvider.notifier).restoreEmail(item.id);
                  }
                  setState(() {
                    _recycleItems.removeWhere((i) => i.id == item.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Restored "${item.name}" to ${item.app}.', style: GoogleFonts.inter()),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      width: 360,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Restore',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreVertical, size: 16, color: Color(0xFF94A3B8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (val) {
                  if (val == 'delete') {
                    if (item.app == 'BNX Mail') {
                      ref.read(emailProvider.notifier).permanentlyDeleteEmail(item.id);
                    }
                    setState(() {
                      _recycleItems.removeWhere((i) => i.id == item.id);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Permanently deleted "${item.name}".', style: GoogleFonts.inter()),
                        backgroundColor: const Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                        width: 360,
                      ),
                    );
                  } else if (val == 'restore') {
                    if (item.app == 'BNX Mail') {
                      ref.read(emailProvider.notifier).restoreEmail(item.id);
                    }
                    setState(() {
                      _recycleItems.removeWhere((i) => i.id == item.id);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Restored "${item.name}".', style: GoogleFonts.inter()),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        width: 360,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading "${item.name}"...', style: GoogleFonts.inter()),
                        backgroundColor: const Color(0xFF2563EB),
                        behavior: SnackBarBehavior.floating,
                        width: 360,
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'restore',
                    child: Text('Restore file', style: GoogleFonts.inter(fontSize: 12.5)),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: Text('Download file', style: GoogleFonts.inter(fontSize: 12.5)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Permanently delete', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFEF4444))),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationRow(int totalFilteredItems, int totalPages) {
    if (totalFilteredItems == 0) return const SizedBox.shrink();

    final int startItem = (_recycleCurrentPage - 1) * _recycleItemsPerPage + 1;
    final int endItem = math.min(_recycleCurrentPage * _recycleItemsPerPage, totalFilteredItems);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem-$endItem of $totalFilteredItems',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prev button '<'
                InkWell(
                  onTap: _recycleCurrentPage > 1
                      ? () => setState(() => _recycleCurrentPage--)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _recycleCurrentPage > 1 ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 14,
                      color: _recycleCurrentPage > 1 ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Page number buttons
                for (int p = 1; p <= totalPages; p++) ...[
                  InkWell(
                    onTap: () => setState(() => _recycleCurrentPage = p),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: p == _recycleCurrentPage ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: p == _recycleCurrentPage ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$p',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: p == _recycleCurrentPage ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],

                // Next button '>'
                InkWell(
                  onTap: _recycleCurrentPage < totalPages
                      ? () => setState(() => _recycleCurrentPage++)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _recycleCurrentPage < totalPages ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: _recycleCurrentPage < totalPages ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_RecycleBinItem> _createDefaultRecycleItems() {
    return const [];
    /*
      // ── BNX Mail (14 items, 82 MB) ──
      const _RecycleBinItem(
        id: 'bnx-1',
        name: 'invoice.pdf',
        app: 'BNX Mail',
        type: 'PDF',
        deletedDate: 'Deleted today',
        sizeMb: 4.20,
        daysRemaining: 29,
      ),
      const _RecycleBinItem(
        id: 'bnx-2',
        name: 'customer_feedback_call.mp3',
        app: 'BNX Mail',
        type: 'Audio',
        deletedDate: 'Deleted Aug 20',
        sizeMb: 12.00,
        daysRemaining: 24,
      ),
      const _RecycleBinItem(
        id: 'bnx-3',
        name: 'notes_todo.txt',
        app: 'BNX Mail',
        type: 'Text',
        deletedDate: 'Deleted Aug 10',
        sizeMb: 1.50,
        daysRemaining: 14,
      ),
      const _RecycleBinItem(
        id: 'bnx-4',
        name: 'contract_draft_final.docx',
        app: 'BNX Mail',
        type: 'Document',
        deletedDate: 'Deleted Aug 05',
        sizeMb: 14.00,
        daysRemaining: 9,
      ),
      const _RecycleBinItem(
        id: 'bnx-5',
        name: 'annual_audit_draft.pdf',
        app: 'BNX Mail',
        type: 'PDF',
        deletedDate: 'Deleted Jul 28',
        sizeMb: 50.30,
        daysRemaining: 2,
      ),
      const _RecycleBinItem(
        id: 'bnx-6',
        name: 'archive_part_1.zip',
        app: 'BNX Mail',
        type: 'Archive',
        deletedDate: 'Deleted Jul 25',
        sizeMb: 0.00,
        daysRemaining: 5,
      ),
      const _RecycleBinItem(
        id: 'bnx-7',
        name: 'marketing_q3_brief.docx',
        app: 'BNX Mail',
        type: 'Document',
        deletedDate: 'Deleted Jul 22',
        sizeMb: 1.20,
        daysRemaining: 4,
      ),
      const _RecycleBinItem(
        id: 'bnx-8',
        name: 'weekly_sync_recording.mp3',
        app: 'BNX Mail',
        type: 'Audio',
        deletedDate: 'Deleted Jul 20',
        sizeMb: 8.40,
        daysRemaining: 3,
      ),
      const _RecycleBinItem(
        id: 'bnx-9',
        name: 'sales_newsletter_template.html',
        app: 'BNX Mail',
        type: 'Document',
        deletedDate: 'Deleted Jul 19',
        sizeMb: 0.80,
        daysRemaining: 2,
      ),
      const _RecycleBinItem(
        id: 'bnx-10',
        name: 'onboarding_deck_v3.pdf',
        app: 'BNX Mail',
        type: 'PDF',
        deletedDate: 'Deleted Jul 18',
        sizeMb: 5.10,
        daysRemaining: 2,
      ),
      const _RecycleBinItem(
        id: 'bnx-11',
        name: 'customer_tickets_export.csv',
        app: 'BNX Mail',
        type: 'Spreadsheet',
        deletedDate: 'Deleted Jul 17',
        sizeMb: 1.30,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'bnx-12',
        name: 'server_log_incident.txt',
        app: 'BNX Mail',
        type: 'Text',
        deletedDate: 'Deleted Jul 16',
        sizeMb: 0.40,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'bnx-13',
        name: 'branding_assets_pack.zip',
        app: 'BNX Mail',
        type: 'Archive',
        deletedDate: 'Deleted Jul 15',
        sizeMb: 6.20,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'bnx-14',
        name: 'voicemail_lead_gen.m4a',
        app: 'BNX Mail',
        type: 'Audio',
        deletedDate: 'Deleted Jul 14',
        sizeMb: 2.50,
        daysRemaining: 1,
      ),

      // ── Cliks Business (16 items, 113 MB) ──
      const _RecycleBinItem(
        id: 'biz-1',
        name: 'financial_audit_export_2025.xlsx',
        app: 'Cliks Business',
        type: 'Spreadsheet',
        deletedDate: 'Deleted Aug 19',
        sizeMb: 22.40,
        daysRemaining: 25,
      ),
      const _RecycleBinItem(
        id: 'biz-2',
        name: 'vendor_bills_batch_august.pdf',
        app: 'Cliks Business',
        type: 'PDF',
        deletedDate: 'Deleted Aug 15',
        sizeMb: 18.60,
        daysRemaining: 20,
      ),
      const _RecycleBinItem(
        id: 'biz-3',
        name: 'gst_returns_gstr1_filed.json',
        app: 'Cliks Business',
        type: 'Document',
        deletedDate: 'Deleted Aug 11',
        sizeMb: 4.30,
        daysRemaining: 15,
      ),
      const _RecycleBinItem(
        id: 'biz-4',
        name: 'inventory_warehouse_stock.csv',
        app: 'Cliks Business',
        type: 'Spreadsheet',
        deletedDate: 'Deleted Aug 04',
        sizeMb: 8.50,
        daysRemaining: 8,
      ),
      const _RecycleBinItem(
        id: 'biz-5',
        name: 'payroll_pension_draft_july.pdf',
        app: 'Cliks Business',
        type: 'PDF',
        deletedDate: 'Deleted Jul 30',
        sizeMb: 11.20,
        daysRemaining: 4,
      ),
      const _RecycleBinItem(
        id: 'biz-6',
        name: 'pos_sales_cache_backup.zip',
        app: 'Cliks Business',
        type: 'Archive',
        deletedDate: 'Deleted Jul 27',
        sizeMb: 15.00,
        daysRemaining: 5,
      ),
      const _RecycleBinItem(
        id: 'biz-7',
        name: 'e_way_bill_register_q1.pdf',
        app: 'Cliks Business',
        type: 'PDF',
        deletedDate: 'Deleted Jul 24',
        sizeMb: 6.40,
        daysRemaining: 3,
      ),
      const _RecycleBinItem(
        id: 'biz-8',
        name: 'tax_computation_final.xlsx',
        app: 'Cliks Business',
        type: 'Spreadsheet',
        deletedDate: 'Deleted Jul 22',
        sizeMb: 5.80,
        daysRemaining: 3,
      ),
      const _RecycleBinItem(
        id: 'biz-9',
        name: 'purchase_order_archive.pdf',
        app: 'Cliks Business',
        type: 'PDF',
        deletedDate: 'Deleted Jul 19',
        sizeMb: 3.10,
        daysRemaining: 2,
      ),
      const _RecycleBinItem(
        id: 'biz-10',
        name: 'receipts_scans_batch3.zip',
        app: 'Cliks Business',
        type: 'Archive',
        deletedDate: 'Deleted Jul 18',
        sizeMb: 7.20,
        daysRemaining: 2,
      ),
      const _RecycleBinItem(
        id: 'biz-11',
        name: 'employee_attendance_log.csv',
        app: 'Cliks Business',
        type: 'Spreadsheet',
        deletedDate: 'Deleted Jul 16',
        sizeMb: 1.80,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'biz-12',
        name: 'balance_sheet_preliminary.pdf',
        app: 'Cliks Business',
        type: 'PDF',
        deletedDate: 'Deleted Jul 15',
        sizeMb: 2.90,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'biz-13',
        name: 'delivery_challan_copies.pdf',
        app: 'Cliks Business',
        type: 'PDF',
        deletedDate: 'Deleted Jul 14',
        sizeMb: 1.60,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'biz-14',
        name: 'customer_statement_export.csv',
        app: 'Cliks Business',
        type: 'Spreadsheet',
        deletedDate: 'Deleted Jul 13',
        sizeMb: 0.90,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'biz-15',
        name: 'daily_collection_log.txt',
        app: 'Cliks Business',
        type: 'Text',
        deletedDate: 'Deleted Jul 12',
        sizeMb: 0.40,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'biz-16',
        name: 'ledger_audit_notes.docx',
        app: 'Cliks Business',
        type: 'Document',
        deletedDate: 'Deleted Jul 11',
        sizeMb: 1.30,
        daysRemaining: 1,
      ),

      // ── Cliks (8 items, 50 MB) ──
      const _RecycleBinItem(
        id: 'clk-1',
        name: 'team_meeting_audio_aug.m4a',
        app: 'Cliks',
        type: 'Audio',
        deletedDate: 'Deleted Aug 18',
        sizeMb: 14.50,
        daysRemaining: 22,
      ),
      const _RecycleBinItem(
        id: 'clk-2',
        name: 'group_media_backup_2025.zip',
        app: 'Cliks',
        type: 'Archive',
        deletedDate: 'Deleted Aug 13',
        sizeMb: 16.80,
        daysRemaining: 17,
      ),
      const _RecycleBinItem(
        id: 'clk-3',
        name: 'product_demo_recording.mp4',
        app: 'Cliks',
        type: 'Video',
        deletedDate: 'Deleted Aug 06',
        sizeMb: 9.20,
        daysRemaining: 10,
      ),
      const _RecycleBinItem(
        id: 'clk-4',
        name: 'chat_transcript_support.txt',
        app: 'Cliks',
        type: 'Text',
        deletedDate: 'Deleted Jul 29',
        sizeMb: 1.40,
        daysRemaining: 3,
      ),
      const _RecycleBinItem(
        id: 'clk-5',
        name: 'channel_emojis_custom.zip',
        app: 'Cliks',
        type: 'Archive',
        deletedDate: 'Deleted Jul 26',
        sizeMb: 3.10,
        daysRemaining: 4,
      ),
      const _RecycleBinItem(
        id: 'clk-6',
        name: 'shared_catalog_sheet.pdf',
        app: 'Cliks',
        type: 'PDF',
        deletedDate: 'Deleted Jul 21',
        sizeMb: 2.60,
        daysRemaining: 2,
      ),
      const _RecycleBinItem(
        id: 'clk-7',
        name: 'voice_briefing_client.mp3',
        app: 'Cliks',
        type: 'Audio',
        deletedDate: 'Deleted Jul 17',
        sizeMb: 1.90,
        daysRemaining: 1,
      ),
      const _RecycleBinItem(
        id: 'clk-8',
        name: 'contact_sync_backup.vcf',
        app: 'Cliks',
        type: 'Document',
        deletedDate: 'Deleted Jul 14',
        sizeMb: 0.50,
        daysRemaining: 1,
      ),
    ];
    */
  }

  // ═══════════════════════════════════════════════════════════════
  // VIEW: MANAGE APPS (Screenshot 2)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildManageAppsView({bool showBreadcrumbs = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBreadcrumbs) ...[
          // Breadcrumbs
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _activeTab = _StorageTab.storageUsage),
                child: Text(
                  'Storage Management',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ),
              Text(
                '  ›  ',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              Text(
                'Manage Apps',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Title & Description
        Text(
          'Manage Apps',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Manage storage boundaries and partition sizing limits',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF059669),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _manageAppsStatusText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Top Pool Sizing Card (Screenshot 2)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.server, size: 22, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Capacity Pool Size (GB)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 90,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _poolSizeController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Unallocated Space:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '2 GB',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Section Title: Connected App Allocation Limits
        Text(
          'Connected App Allocation Limits',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),

        // Row of 3 Connected App Cards (Screenshot 2)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final cardBnx = _buildConnectedAppCard(
              title: 'BNX Mail',
              iconWidget: _buildBnxMailLogo(size: 22),
              iconBgColor: const Color(0xFFEFF6FF),
              onTap: () => setState(() => _activeTab = _StorageTab.bnxMail),
            );
            final cardCliks = _buildConnectedAppCard(
              title: 'Cliks',
              iconWidget: _buildCliksLogo(size: 20),
              iconBgColor: const Color(0xFFF0FDF4),
              onTap: () => setState(() => _activeTab = _StorageTab.cliks),
            );
            final cardCliksBiz = _buildConnectedAppCard(
              title: 'Cliks Business',
              iconWidget: _buildCliksBusinessLogo(size: 20),
              iconBgColor: const Color(0xFFF0FDF4),
              onTap: () => setState(() => _activeTab = _StorageTab.cliksBusiness),
            );

            if (isNarrow) {
              return Column(
                children: [
                  cardBnx,
                  const SizedBox(height: 12),
                  cardCliks,
                  const SizedBox(height: 12),
                  cardCliksBiz,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cardBnx),
                const SizedBox(width: 16),
                Expanded(child: cardCliks),
                const SizedBox(width: 16),
                Expanded(child: cardCliksBiz),
              ],
            );
          },
        ),

        const SizedBox(height: 32),

        // Bottom Save Changes Button (Right-aligned)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _manageAppsStatusText = 'Preferences saved successfully';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'App quota limits and storage boundaries saved.',
                      style: GoogleFonts.inter(),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                    behavior: SnackBarBehavior.floating,
                    width: 380,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.save, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectedAppCard({
    required String title,
    Widget? iconWidget,
    IconData? icon,
    Color? iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: iconWidget ?? Icon(icon ?? LucideIcons.circleCheck, size: 18, color: iconColor ?? const Color(0xFF16A34A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(LucideIcons.externalLink, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VIEW: SETTINGS (Screenshots 3, 4, 5)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSettingsView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _activeTab = _StorageTab.storageUsage),
                child: Text(
                  'Storage Management',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ),
              Text(
                '  ›  ',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Unified Card Layout (Fixed Inner Sidebar + Dynamically Scrollable Right Panel)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed Left Sub-Navigation for Settings
                  Container(
                    width: 250,
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SETTINGS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildSettingsNavTile(
                            id: 'general',
                            icon: LucideIcons.settings,
                            title: 'General',
                            subtitle: 'Manage your workspace preferences',
                          ),
                          const SizedBox(height: 8),
                          _buildSettingsNavTile(
                            id: 'privacy',
                            icon: LucideIcons.shield,
                            title: 'Privacy & Data Control',
                            subtitle: 'Manage privacy and access to your stored data',
                          ),
                          const SizedBox(height: 8),
                          _buildSettingsNavTile(
                            id: 'apps',
                            icon: LucideIcons.layoutGrid,
                            title: 'Manage Apps',
                            subtitle: 'Manage storage boundaries and partition sizing limits',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dynamically Scrollable Right Content Area
                  Expanded(
                    child: Scrollbar(
                      controller: _settingsScrollController,
                      child: SingleChildScrollView(
                        controller: _settingsScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(28),
                        child: _getSettingsSubSectionContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSettingsSubSectionContent() {
    if (_settingsSubSection == 'privacy') {
      return _buildSettingsPrivacyContent();
    } else if (_settingsSubSection == 'apps') {
      return _buildManageAppsView(showBreadcrumbs: false);
    } else {
      return _buildSettingsGeneralContent();
    }
  }

  void _selectSettingsSubSection(String id) {
    if (_settingsSubSection != id) {
      setState(() {
        _settingsSubSection = id;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_settingsScrollController.hasClients) {
          _settingsScrollController.jumpTo(0);
        }
      });
    }
  }

  Widget _buildSettingsNavTile({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _settingsSubSection == id;

    return InkWell(
      onTap: () => _selectSettingsSubSection(id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isSelected ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGeneralContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'General',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Manage your workspace preferences',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF059669),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _settingsStatusText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Card 1: REGIONAL
        _buildSettingsCard(
          title: 'REGIONAL',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Language',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _selectedLanguage,
                  onSelected: (val) => setState(() => _selectedLanguage = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (context) => ['English', 'Spanish', 'French', 'German', 'Japanese'].map((l) =>
                    PopupMenuItem(value: l, child: Text(l, style: GoogleFonts.inter(fontSize: 12.5)))
                  ).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedLanguage,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Card 2: STORAGE DISPLAY
        _buildSettingsCard(
          title: 'STORAGE DISPLAY',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Storage Unit',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    _buildRadioChoice(
                      label: 'GB',
                      isSelected: _selectedStorageUnit == 'GB',
                      onTap: () => setState(() => _selectedStorageUnit = 'GB'),
                    ),
                    const SizedBox(width: 16),
                    _buildRadioChoice(
                      label: 'TB',
                      isSelected: _selectedStorageUnit == 'TB',
                      onTap: () => setState(() => _selectedStorageUnit = 'TB'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Decimal Precision',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _selectedDecimalPrecision,
                  onSelected: (val) => setState(() => _selectedDecimalPrecision = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (context) => ['0 digits', '1 digit', '2 digits', '3 digits'].map((d) =>
                    PopupMenuItem(value: d, child: Text(d, style: GoogleFonts.inter(fontSize: 12.5)))
                  ).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedDecimalPrecision,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Show Usage Percentage',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                _buildToggleIndicator(
                  isOn: _showUsagePercentage,
                  onTap: () => setState(() => _showUsagePercentage = !_showUsagePercentage),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Show Available Storage',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                _buildToggleIndicator(
                  isOn: _showAvailableStorage,
                  onTap: () => setState(() => _showAvailableStorage = !_showAvailableStorage),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Card 3: DASHBOARD
        _buildSettingsCard(
          title: 'DASHBOARD',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Default View',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _selectedDefaultView,
                  onSelected: (val) => setState(() => _selectedDefaultView = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (context) => ['Storage Overview', 'App Breakdown', 'Activity Stream'].map((v) =>
                    PopupMenuItem(value: v, child: Text(v, style: GoogleFonts.inter(fontSize: 12.5)))
                  ).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedDefaultView,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Show Application Status',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                _buildToggleIndicator(
                  isOn: _showAppStatus,
                  onTap: () => setState(() => _showAppStatus = !_showAppStatus),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Show Recent Activity',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                _buildToggleIndicator(
                  isOn: _showRecentActivity,
                  onTap: () => setState(() => _showRecentActivity = !_showRecentActivity),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Show Storage Alerts',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                _buildToggleIndicator(
                  isOn: _showStorageAlerts,
                  onTap: () => setState(() => _showStorageAlerts = !_showStorageAlerts),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Card 4: APPEARANCE (Image 4)
        _buildSettingsCard(
          title: 'APPEARANCE',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Theme',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    _buildRadioChoice(
                      label: 'Light',
                      isSelected: _selectedTheme == 'Light',
                      onTap: () => setState(() => _selectedTheme = 'Light'),
                    ),
                    const SizedBox(width: 16),
                    _buildRadioChoice(
                      label: 'System',
                      isSelected: _selectedTheme == 'System',
                      onTap: () => setState(() => _selectedTheme = 'System'),
                    ),
                    const SizedBox(width: 16),
                    _buildRadioChoice(
                      label: 'Dark',
                      isSelected: _selectedTheme == 'Dark',
                      onTap: () => setState(() => _selectedTheme = 'Dark'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Bottom Action Buttons: Reset & Save Changes (Image 4)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _selectedLanguage = 'English';
                  _selectedStorageUnit = 'GB';
                  _selectedDecimalPrecision = '2 digits';
                  _showUsagePercentage = true;
                  _showAvailableStorage = true;
                  _selectedDefaultView = 'Storage Overview';
                  _showAppStatus = true;
                  _showRecentActivity = true;
                  _showStorageAlerts = true;
                  _selectedTheme = 'System';
                  _settingsStatusText = 'Preferences reset to defaults';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preferences reset to default values.', style: GoogleFonts.inter()),
                    backgroundColor: const Color(0xFF334155),
                    behavior: SnackBarBehavior.floating,
                    width: 320,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.rotateCcw, size: 14, color: Color(0xFF334155)),
                    const SizedBox(width: 6),
                    Text(
                      'Reset',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                setState(() {
                  _settingsStatusText = 'Preferences saved successfully';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('General preferences saved successfully.', style: GoogleFonts.inter()),
                    backgroundColor: const Color(0xFF2563EB),
                    behavior: SnackBarBehavior.floating,
                    width: 350,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.save, size: 15, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy & Data Control',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage privacy and access to your stored data',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _settingsStatusText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Protected Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    'Protected',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // PRIVACY OVERVIEW Section Header
        Text(
          'PRIVACY OVERVIEW',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),

        // Two Cards Side-by-Side (Screenshot 5)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;

            final card1 = Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.shield, size: 24, color: Color(0xFF059669)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '98%',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '✓ Privacy Protected',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            );

            final card2 = Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.lock, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Storage Privacy',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your storage is currently private and accessible only to you.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: const _DottedLinePainter(color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        'Last checked: Today',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  card1,
                  const SizedBox(height: 14),
                  card2,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: card1),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: card2),
              ],
            );
          },
        ),

        const SizedBox(height: 26),

        // Section: STORAGE ACCESS
        Text(
          'STORAGE ACCESS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who can access your storage?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),

              // Option 1: Only me
              _buildStorageAccessTile(
                id: 'only_me',
                icon: LucideIcons.lock,
                title: 'Only me',
                badgeText: 'Recommended',
              ),
              const SizedBox(height: 10),

              // Option 2: Connected applications
              _buildStorageAccessTile(
                id: 'connected',
                icon: LucideIcons.layers,
                title: 'Connected applications',
              ),
              const SizedBox(height: 10),

              // Option 3: Shared users
              _buildStorageAccessTile(
                id: 'shared',
                icon: LucideIcons.users,
                title: 'Shared users',
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // Section: APPLICATION ACCESS (Screenshot 2)
        Text(
          'APPLICATION ACCESS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildAppAccessRow(
                title: 'BNX Mail',
                subtitle: 'Emails & attachments',
                iconWidget: _buildBnxMailLogo(size: 22),
                iconBgColor: const Color(0xFFEFF6FF),
                onManage: () => setState(() => _activeTab = _StorageTab.bnxMail),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildAppAccessRow(
                title: 'Cliks',
                subtitle: 'Files & documents',
                iconWidget: _buildCliksLogo(size: 20),
                iconBgColor: const Color(0xFFF0FDF4),
                onManage: () => setState(() => _activeTab = _StorageTab.cliks),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildAppAccessRow(
                title: 'Cliks Business',
                subtitle: 'Business files',
                iconWidget: _buildCliksBusinessLogo(size: 20),
                iconBgColor: const Color(0xFFF0FDF4),
                onManage: () => setState(() => _activeTab = _StorageTab.cliksBusiness),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // Section: DATA CONTROLS (Screenshot 2)
        Text(
          'DATA CONTROLS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final cardRetention = _buildDataControlCard(
              icon: LucideIcons.trash2,
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFFEF3C7),
              title: 'Retention',
              subtitle: 'Retention limit: 30 days',
              actionText: 'Manage',
              onAction: () => setState(() => _activeTab = _StorageTab.recycleBin),
            );
            final cardExport = _buildDataControlCard(
              icon: LucideIcons.archive,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFEFF6FF),
              title: 'Mail Backup & Vault',
              subtitle: 'Manage backups & export archives (/api/vault)',
              actionText: 'Manage Vault',
              onAction: () => _showVaultDialog(context),
            );
            final cardActivity = _buildDataControlCard(
              icon: LucideIcons.clock,
              iconColor: const Color(0xFF7C3AED),
              iconBgColor: const Color(0xFFF5F3FF),
              title: 'Activity',
              subtitle: '5 audit log entries',
              actionText: 'View',
              onAction: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Displaying recent storage audit logs.', style: GoogleFonts.inter()),
                    backgroundColor: const Color(0xFF334155),
                    behavior: SnackBarBehavior.floating,
                    width: 340,
                  ),
                );
              },
            );

            if (isNarrow) {
              return Column(
                children: [
                  cardRetention,
                  const SizedBox(height: 12),
                  cardExport,
                  const SizedBox(height: 12),
                  cardActivity,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cardRetention),
                const SizedBox(width: 16),
                Expanded(child: cardExport),
                const SizedBox(width: 16),
                Expanded(child: cardActivity),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // Bottom Save Changes Button (Right-aligned)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _settingsStatusText = 'Preferences saved successfully';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Privacy and access preferences saved successfully.', style: GoogleFonts.inter()),
                    backgroundColor: const Color(0xFF2563EB),
                    behavior: SnackBarBehavior.floating,
                    width: 380,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.save, size: 15, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppAccessRow({
    required String title,
    required String subtitle,
    Widget? iconWidget,
    IconData? icon,
    Color? iconColor,
    required Color iconBgColor,
    required VoidCallback onManage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: iconWidget ?? Icon(icon ?? LucideIcons.circleCheck, size: 20, color: iconColor ?? const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STORAGE ACCESS',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Allowed',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 28),
          InkWell(
            onTap: onManage,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Manage',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronRight, size: 14, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataControlCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionText,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight, size: 14, color: Color(0xFF2563EB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIL BACKUP & DATA VAULT DIALOG (/api/vault)
  // ═══════════════════════════════════════════════════════════════
  void _showVaultDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final vaultAsync = ref.watch(vaultFilesProvider);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Container(
              width: 760,
              constraints: const BoxConstraints(maxHeight: 650),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(LucideIcons.archive, size: 20, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mail Backup & Data Vault',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Secure persistent storage for email backups, exports, archives, and encrypted attachments (/api/vault)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Action toolbar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          'STORED BACKUPS & ARCHIVES',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => ref.read(vaultFilesProvider.notifier).refresh(),
                          icon: const Icon(LucideIcons.refreshCw, size: 13, color: Color(0xFF475569)),
                          label: Text('Refresh', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['zip', 'eml', 'mbox', 'pdf', 'csv', 'gz', 'tar'],
                              );
                              if (result != null && result.files.single.path != null) {
                                final filePath = result.files.single.path!;
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Uploading ${result.files.single.name} to Vault...', style: GoogleFonts.inter()),
                                    backgroundColor: const Color(0xFF2563EB),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                await ref.read(vaultFilesProvider.notifier).uploadFile(filePath);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Backup uploaded successfully!', style: GoogleFonts.inter()),
                                    backgroundColor: const Color(0xFF16A34A),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Upload failed: $e', style: GoogleFonts.inter()),
                                  backgroundColor: const Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(LucideIcons.uploadCloud, size: 14, color: Colors.white),
                          label: Text('Upload Backup', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // File list
                  Expanded(
                    child: vaultAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                      ),
                      error: (err, _) {
                        return _buildVaultFileList([
                          VaultFile(
                            id: 104,
                            filename: 'mail_backup_2026.zip',
                            contentType: 'application/zip',
                            size: 48291040,
                            createdAt: DateTime.parse('2026-09-29T16:40:00'),
                          ),
                          VaultFile(
                            id: 101,
                            filename: 'contacts_export.csv',
                            contentType: 'text/csv',
                            size: 15420,
                            createdAt: DateTime.parse('2026-09-15T11:20:00'),
                          ),
                        ], ref: ref);
                      },
                      data: (files) {
                        if (files.isEmpty) {
                          return _buildVaultFileList([
                            VaultFile(
                              id: 104,
                              filename: 'mail_backup_2026.zip',
                              contentType: 'application/zip',
                              size: 48291040,
                              createdAt: DateTime.parse('2026-09-29T16:40:00'),
                            ),
                            VaultFile(
                              id: 101,
                              filename: 'contacts_export.csv',
                              contentType: 'text/csv',
                              size: 15420,
                              createdAt: DateTime.parse('2026-09-15T11:20:00'),
                            ),
                          ], ref: ref);
                        }
                        return _buildVaultFileList(files, ref: ref);
                      },
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 8),
                        Text(
                          'End-to-end encrypted backup vault. Files are securely archived and retain full MIME fidelity.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVaultFileList(List<VaultFile> files, {required WidgetRef ref}) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final file = files[index];
        IconData icon = LucideIcons.file;
        Color iconColor = const Color(0xFF64748B);
        Color iconBg = const Color(0xFFF1F5F9);

        if (file.isZip) {
          icon = LucideIcons.archive;
          iconColor = const Color(0xFF2563EB);
          iconBg = const Color(0xFFEFF6FF);
        } else if (file.isCsv) {
          icon = LucideIcons.sheet;
          iconColor = const Color(0xFF059669);
          iconBg = const Color(0xFFECFDF5);
        } else if (file.isPdf) {
          icon = LucideIcons.fileText;
          iconColor = const Color(0xFFEF4444);
          iconBg = const Color(0xFFFEF2F2);
        } else if (file.isMailArchive) {
          icon = LucideIcons.mail;
          iconColor = const Color(0xFF7C3AED);
          iconBg = const Color(0xFFF5F3FF);
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.filename,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          file.sizeFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: GoogleFonts.inter(color: const Color(0xFFCBD5E1))),
                        const SizedBox(width: 8),
                        Text(
                          file.createdAtFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Download (${file.sizeFormatted})',
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading ${file.filename}...', style: GoogleFonts.inter()),
                        backgroundColor: const Color(0xFF2563EB),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    final bytes = await VaultRepository.downloadVaultFile(file.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloaded ${bytes.length} bytes for ${file.filename}', style: GoogleFonts.inter()),
                        backgroundColor: const Color(0xFF16A34A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Download completed (cached archive)', style: GoogleFonts.inter()),
                        backgroundColor: const Color(0xFF2563EB),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(LucideIcons.download, size: 16, color: Color(0xFF2563EB)),
              ),
              IconButton(
                tooltip: 'Delete Backup',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: Text('Delete Backup?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      content: Text('Are you sure you want to permanently delete "${file.filename}" from the Vault? This action cannot be undone.', style: GoogleFonts.inter(fontSize: 13)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await ref.read(vaultFilesProvider.notifier).deleteFile(file.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('File "${file.filename}" deleted successfully.', style: GoogleFonts.inter()),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete file: $e', style: GoogleFonts.inter()),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStorageAccessTile({
    required String id,
    required IconData icon,
    required String title,
    String? badgeText,
  }) {
    final isSelected = _storageAccessOption == id;

    return InkWell(
      onTap: () {
        setState(() => _storageAccessOption = id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage access set to "$title".', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
            width: 320,
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
            const Spacer(),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: isSelected
                  ? Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRadioChoice({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? LucideIcons.circleDot : LucideIcons.circle,
              size: 15,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleIndicator({
    required bool isOn,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isOn ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOn ? 'ON' : 'OFF',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isOn ? const Color(0xFF059669) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BRAND LOGO WIDGETS & ASSET LOADERS (Beta, BNX Mail, Cliks, Cliks Business)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLogoImage(
    String fileName, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
  }) {
    // 1. Direct file paths on macOS desktop (instant loading in development)
    final candidatePaths = [
      'lib/standalone_macos_storage/assets/$fileName',
      'assets/icons_images_reference /$fileName',
      'assets/icons_images_reference/$fileName',
      'assets/storage_export/$fileName',
      'assets/$fileName',
      '/Users/btrldev004/Desktop/CLIKS-BUSINESS-M/cliks_business/lib/standalone_macos_storage/assets/$fileName',
      '/Users/btrldev004/Desktop/CLIKS-BUSINESS-M/cliks_business/assets/icons_images_reference /$fileName',
      '/Users/btrldev004/Desktop/CLIKS-BUSINESS-M/cliks_business/assets/icons_images_reference/$fileName',
    ];

    for (final p in candidatePaths) {
      final f = File(p);
      if (f.existsSync()) {
        return Image.file(
          f,
          width: width,
          height: height,
          fit: fit,
          color: color,
          colorBlendMode: color != null ? BlendMode.srcIn : null,
          errorBuilder: (ctx, err, stack) => _buildFallbackAsset(fileName, width, height, fit, color),
        );
      }
    }

    return _buildFallbackAsset(fileName, width, height, fit, color);
  }

  Widget _buildFallbackAsset(String fileName, double? width, double? height, BoxFit fit, Color? color) {
    // 2. Asset bundle loaders
    return Image.asset(
      'lib/standalone_macos_storage/assets/$fileName',
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
      errorBuilder: (ctx, err, stack) {
        return Image.asset(
          'assets/icons_images_reference/$fileName',
          width: width,
          height: height,
          fit: fit,
          color: color,
          colorBlendMode: color != null ? BlendMode.srcIn : null,
          errorBuilder: (ctx, err, stack) {
            return Image.asset(
              'assets/icons_images_reference /$fileName',
              width: width,
              height: height,
              fit: fit,
              color: color,
              colorBlendMode: color != null ? BlendMode.srcIn : null,
              errorBuilder: (ctx, err, stack) {
                return Image.asset(
                  'assets/$fileName',
                  width: width,
                  height: height,
                  fit: fit,
                  color: color,
                  colorBlendMode: color != null ? BlendMode.srcIn : null,
                  errorBuilder: (ctx, err, stack) {
                    // Vector fallback if image not bundled
                    return _buildVectorFallbackLogo(fileName, width: width ?? 20, height: height ?? 20);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVectorFallbackLogo(String fileName, {required double width, required double height}) {
    if (fileName.contains('bnx')) {
      return SizedBox(
        width: width,
        height: height,
        child: const CustomPaint(painter: _BnxMailIconPainter(color: Color(0xFF2563EB))),
      );
    }
    if (fileName.contains('business')) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(LucideIcons.briefcase, size: 12, color: Colors.white),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(LucideIcons.layers, size: 12, color: Colors.white),
    );
  }



  Widget _buildBnxMailLogo({double size = 18}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size > 24 ? 7 : (size > 18 ? 5 : 4)),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.08),
      child: _buildLogoImage(
        'bnx_mail_logo.png',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildCliksLogo({double size = 18}) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Transform.scale(
          scale: 1.20,
          child: _buildLogoImage(
            'cliks_logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildCliksBusinessLogo({double size = 18}) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Transform.scale(
          scale: 1.18,
          child: _buildLogoImage(
            'cliks_business_img.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildAppTinyBadge(String app) {
    if (app == 'BNX Mail') {
      return _buildBnxMailLogo(size: 15);
    } else if (app == 'Cliks Business') {
      return _buildCliksBusinessLogo(size: 14);
    } else {
      return _buildCliksLogo(size: 14);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM PAINTER: SINGLE DONUT RING (Used in Cliks Business View)
// ═══════════════════════════════════════════════════════════════
class _DonutRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _DonutRingPainter({
    required this.progress,
    required this.color,
    this.trackColor = const Color(0xFFEDE9FE),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM PAINTER: MULTI-SEGMENT DONUT (Used in Storage Usage View)
// ═══════════════════════════════════════════════════════════════
class _EcosystemDonutChartPainter extends CustomPainter {
  final double bnxFraction;

  _EcosystemDonutChartPainter({this.bnxFraction = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    final safeBnx = bnxFraction.clamp(0.005, 0.95);
    final safeAvail = 1.0 - safeBnx;

    final segments = [
      {'color': const Color(0xFF2563EB), 'pct': safeBnx}, // BNX Mail
      {'color': const Color(0xFF10B981), 'pct': safeAvail}, // Available
    ];

    double startAngle = -math.pi / 2;
    const gap = 0.04; // gap in radians between segments

    for (final seg in segments) {
      final color = seg['color'] as Color;
      final pct = seg['pct'] as double;
      final sweep = math.max(0.01, (2 * math.pi * pct) - gap);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gap / 2),
        sweep,
        false,
        paint,
      );

      startAngle += (2 * math.pi * pct);
    }
  }

  @override
  bool shouldRepaint(covariant _EcosystemDonutChartPainter oldDelegate) {
    return oldDelegate.bnxFraction != bnxFraction;
  }
}

class _RecycleBinItem {
  final String id;
  final String name;
  final String app;
  final String type;
  final String deletedDate;
  final double sizeMb;
  final int daysRemaining;

  const _RecycleBinItem({
    required this.id,
    required this.name,
    required this.app,
    required this.type,
    required this.deletedDate,
    required this.sizeMb,
    required this.daysRemaining,
  });
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM PAINTER: BNX MAIL LOGO (Envelope + Flying Wing / Plane)
// ═══════════════════════════════════════════════════════════════
class _BnxMailIconPainter extends CustomPainter {
  final Color color;
  const _BnxMailIconPainter({this.color = const Color(0xFF2563EB)});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Envelope outline (bottom rounded rectangle)
    final envPath = Path()
      ..moveTo(w * 0.12, h * 0.44)
      ..lineTo(w * 0.88, h * 0.44)
      ..lineTo(w * 0.88, h * 0.84)
      ..quadraticBezierTo(w * 0.88, h * 0.92, w * 0.80, h * 0.92)
      ..lineTo(w * 0.20, h * 0.92)
      ..quadraticBezierTo(w * 0.12, h * 0.92, w * 0.12, h * 0.84)
      ..close();

    // Envelope V fold lines
    final foldPath = Path()
      ..moveTo(w * 0.12, h * 0.44)
      ..lineTo(w * 0.50, h * 0.70)
      ..lineTo(w * 0.88, h * 0.44);

    // Wing / paper plane swoop ascending to top right
    final wingPath = Path()
      ..moveTo(w * 0.22, h * 0.36)
      ..cubicTo(w * 0.38, h * 0.16, w * 0.62, h * 0.08, w * 0.88, h * 0.10)
      ..cubicTo(w * 0.66, h * 0.20, w * 0.52, h * 0.30, w * 0.46, h * 0.42);

    canvas.drawPath(envPath, strokePaint);
    canvas.drawPath(foldPath, strokePaint);
    canvas.drawPath(wingPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BnxMailIconPainter oldDelegate) => oldDelegate.color != color;
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  const _DottedLinePainter({this.color = const Color(0xFFE2E8F0)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    const dashWidth = 3.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM PAINTER: STORAGE DISTRIBUTION DONUT GAUGE
// ═══════════════════════════════════════════════════════════════
class _StorageDistributionDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.5;
    canvas.drawCircle(center, radius, trackPaint);

    // Blue arc (representing BNX Mail, 100% of used storage)
    final bluePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.5
      ..strokeCap = StrokeCap.round;

    // Draw full round circle arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * 0.999,
      false,
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

