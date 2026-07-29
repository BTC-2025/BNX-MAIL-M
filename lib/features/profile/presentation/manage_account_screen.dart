import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/account_provider.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/colab_provider.dart';
import '../../../data/email_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/presentation/notifiers/auth_notifier.dart';
import '../../../models/account_model.dart';

class ManageAccountScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const ManageAccountScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends ConsumerState<ManageAccountScreen>
    with SingleTickerProviderStateMixin {
  late int _selectedTab;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Active Workspace State
  String _selectedWorkspace = 'BNX Tech Enterprise';
  String _userRole = 'Senior Product Lead';
  final List<String> _workspaces = [
    'BNX Tech Enterprise',
    'Cliks Corporate Suite',
    'Bit Tool Developer Lab',
  ];

  // Shared Mailboxes State
  final List<Map<String, String>> _sharedMailboxes = [
    {
      'email': 'tech-leads@bnxmail.com',
      'subtitle': 'Primary Shared Mailbox • Delegate Access Granted',
    },
  ];

  // Subscription State
  String _subPlanName = 'Cliks Business';
  String _subPrice = '\$29/month';
  final String _subRenewalDate = 'Aug 15, 2026';
  String _subPaymentMethod = '•••• 4242 (Visa)';
  int _subTeamSeats = 25;

  // Advanced Privacy Toggles
  bool _zeroKnowledgeEncryption = true;
  bool _biometricLock = false;
  bool _webAppActivity = true;
  bool _locationScrubbing = true;
  bool _autoPurgeSearch = true;

  static const _brandBlue = Color(0xFF195BAC);
  static const _brandBlueLight = Color(0xFF3B82F6);
  static const _accentGreen = Color(0xFF16A34A);

  final List<_TabItem> _tabs = const [
    _TabItem(title: 'Home', icon: Icons.grid_view_rounded, selectedIcon: Icons.grid_view_rounded),
    _TabItem(title: 'Personal information', icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded),
    _TabItem(title: 'Payment and subscription', icon: Icons.card_membership_rounded, selectedIcon: Icons.card_membership_rounded),
    _TabItem(title: 'Account storage', icon: Icons.cloud_outlined, selectedIcon: Icons.cloud_rounded),
    _TabItem(title: 'B2 auth', icon: Icons.security_outlined, selectedIcon: Icons.security_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = filePath.split('.').last.toLowerCase();
          final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
          final base64String = 'data:$mime;base64,${base64Encode(bytes)}';

          final activeAccount = ref.read(activeAccountProvider);
          await ref.read(accountsProvider.notifier).updateAvatar(activeAccount.id, base64String);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Profile photo updated!'),
                backgroundColor: _brandBlue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    ref.read(emailProvider.notifier).clear();
    ref.read(accountsProvider.notifier).clear();
    await AuthRepository.logout();
    ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _switchTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final activeAccount = ref.watch(activeAccountProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    final bgColor = isDark ? BNXColors.darkBg : const Color(0xFFE9F4FF);
    final surfaceColor = isDark ? BNXColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ──
            _buildAppBar(isDark, surfaceColor),

            // ── Main Content Area ──
            Expanded(
              child: isMobile
                  ? _buildMobileLayout(activeAccount, isDark, surfaceColor)
                  : _buildDesktopLayout(activeAccount, isDark, surfaceColor),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark, Color surfaceColor) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            tooltip: 'Back',
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/beta_logo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _brandBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Beta',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'My Account',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              size: 20,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
            tooltip: 'Help',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATIVE MOBILE LAYOUT WITH GLASS TAB DOCK
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(AccountModel account, bool isDark, Color surfaceColor) {
    return Column(
      children: [
        // ── Modern Floating Segmented Tab Bar ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _switchTab(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [_brandBlue, _brandBlueLight],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _brandBlue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? tab.selectedIcon : tab.icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tab.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // ── Tab Content Container ──
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: _buildActiveTabContent(account, isDark, true),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT WITH SIDEBAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(AccountModel account, bool isDark, Color surfaceColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left Sidebar Navigation ──
        SizedBox(
          width: 220,
          child: Container(
            color: surfaceColor,
            child: Column(
              children: [
                const SizedBox(height: 16),
                ...List.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  final isSelected = _selectedTab == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: InkWell(
                      onTap: () => _switchTab(index),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    _brandBlue.withValues(alpha: isDark ? 0.25 : 0.1),
                                    _brandBlueLight.withValues(alpha: isDark ? 0.15 : 0.05),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          border: isSelected
                              ? Border.all(
                                  color: _brandBlue.withValues(alpha: isDark ? 0.4 : 0.2),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? tab.selectedIcon : tab.icon,
                              size: 20,
                              color: isSelected
                                  ? (isDark ? _brandBlueLight : _brandBlue)
                                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tab.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? _brandBlueLight : _brandBlue)
                                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: InkWell(
                    onTap: _handleSignOut,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                          SizedBox(width: 12),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Right Main Content ──
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: _buildActiveTabContent(account, isDark, false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB ROUTER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveTabContent(AccountModel account, bool isDark, bool isMobile) {
    switch (_selectedTab) {
      case 0:
        return _buildHomeTab(account, isDark, isMobile);
      case 1:
        return _buildPersonalInfoTab(account, isDark, isMobile);
      case 2:
        return _buildPaymentAndSubscriptionTab(account, isDark, isMobile);
      case 3:
        return _buildAccountStorageTab(account, isDark, isMobile);
      case 4:
        return _buildB2AuthTab(account, isDark, isMobile);
      default:
        return _buildHomeTab(account, isDark, isMobile);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. ACCOUNT STORAGE TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAccountStorageTab(AccountModel account, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Storage Overview', Icons.cloud_outlined, isDark),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: 0.05,
                  minHeight: 12,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF195BAC)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0.0 GB used',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '15.0 GB total',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildActionTile(
                isDark: isDark,
                icon: Icons.unarchive_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Clean up space',
                subtitle: 'Remove large files and old emails',
                onTap: () {},
              ),
              _buildActionTile(
                isDark: isDark,
                icon: Icons.add_shopping_cart_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Upgrade storage',
                subtitle: 'Get more space for your account',
                onTap: () {},
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. B2 AUTH TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildB2AuthTab(AccountModel account, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E3A5F)]
                  : [const Color(0xFF0284C7), const Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'B2 Auth Suite',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Unified Identity & Security Management',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening B2 Auth App...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open B2 Auth App', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E40AF),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE HERO CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProfileHero(AccountModel account, bool isDark) {
    final username = account.email.split('@').first;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF0F172A)]
              : [const Color(0xFF195BAC), const Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: isDark ? 0.2 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
            child: AvatarWidget(
              name: account.name,
              avatarUrl: account.avatarUrl,
              size: 48,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 14),
          // Username and Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  account.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'BUSINESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sign Out Icon
          IconButton(
            onPressed: _handleSignOut,
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDIT DIALOG HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _editFullName(AccountModel account) {
    final ctrl = TextEditingController(text: account.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Full Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Enter full name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                ref.read(accountsProvider.notifier).updateAccountFields(account.id, name: newName);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name updated!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editUsername(AccountModel account) {
    final currentUsername = account.email.contains('@') ? account.email.split('@').first : account.email;
    final ctrl = TextEditingController(text: currentUsername);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Username'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Username', hintText: 'Enter username'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newUsername = ctrl.text.trim();
              if (newUsername.isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Username set to "@$newUsername"!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editRecoveryEmail(AccountModel account) {
    final ctrl = TextEditingController(text: account.recoveryEmail ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Recovery Email'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Recovery Email', hintText: 'user@example.com'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newMail = ctrl.text.trim();
              ref.read(accountsProvider.notifier).updateAccountFields(account.id, recoveryEmail: newMail);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recovery email updated!'), behavior: SnackBarBehavior.floating),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editPhone(AccountModel account) {
    final ctrl = TextEditingController(text: account.phone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+1 234 567 8900'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newPhone = ctrl.text.trim();
              ref.read(accountsProvider.notifier).updateAccountFields(account.id, phone: newPhone);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Phone number updated!'), behavior: SnackBarBehavior.floating),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _selectBirthday(AccountModel account) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: account.dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) {
      ref.read(accountsProvider.notifier).updateAccountFields(account.id, dob: picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Birthday updated!'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _editAccountType(AccountModel account) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Account Type'),
        children: ['BUSINESS', 'ENTERPRISE', 'PERSONAL'].map((type) {
          final isSelected = account.accountType.toUpperCase() == type;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(accountsProvider.notifier).updateAccountFields(account.id, accountType: type);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Account type set to $type'), behavior: SnackBarBehavior.floating),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(type, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected) const Icon(Icons.check_rounded, color: _brandBlue, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _selectLanguage(AccountModel account) {
    final langs = ['English (US)', 'English (UK)', 'Spanish', 'French', 'German', 'Hindi', 'Japanese', 'Chinese'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: langs.map((lang) {
          final isSelected = account.language == lang;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(accountsProvider.notifier).updateAccountFields(account.id, language: lang);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Language set to $lang'), behavior: SnackBarBehavior.floating),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected) const Icon(Icons.check_rounded, color: _brandBlue, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _selectAccessibility(AccountModel account) {
    final options = ['Default', 'High Contrast', 'Large Text', 'Screen Reader Optimized'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Accessibility Preference'),
        children: options.map((opt) {
          final isSelected = account.accessibility == opt;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(accountsProvider.notifier).updateAccountFields(account.id, accessibility: opt);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Accessibility set to $opt'), behavior: SnackBarBehavior.floating),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(opt, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected) const Icon(Icons.check_rounded, color: _brandBlue, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _editUserRole() {
    final ctrl = TextEditingController(text: _userRole);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Role / Designation'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Role', hintText: 'e.g. Senior Product Lead'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newRole = ctrl.text.trim();
              if (newRole.isNotEmpty) {
                setState(() => _userRole = newRole);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Role updated!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddWorkspaceModal() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Workspace'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Workspace Name', hintText: 'e.g. Acme Corp Labs'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _workspaces.add(name);
                  _selectedWorkspace = name;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Created & switched to "$name"!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddSharedMailboxModal() {
    final mailCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Shared Mailbox'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mailCtrl,
              decoration: const InputDecoration(labelText: 'Mailbox Email', hintText: 'team@bnxmail.com'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Description / Role', hintText: 'Support Shared Mailbox'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final email = mailCtrl.text.trim();
              if (email.isNotEmpty) {
                setState(() {
                  _sharedMailboxes.add({
                    'email': email,
                    'subtitle': titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Shared Mailbox Access',
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Shared Mailbox "$email" added!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Add Mailbox'),
          ),
        ],
      ),
    );
  }

  void _showManageSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Plan: $_subPlanName ($_subPrice)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Next Renewal: $_subRenewalDate'),
            Text('Payment Method: $_subPaymentMethod'),
            Text('Active Seats: $_subTeamSeats Seats'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditPaymentMethodDialog();
            },
            child: const Text('Edit Payment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditSeatsDialog();
            },
            child: const Text('Edit Seats'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showEditPaymentMethodDialog() {
    final ctrl = TextEditingController(text: _subPaymentMethod);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Payment Method'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Payment Method', hintText: '•••• 4242 (Visa)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() => _subPaymentMethod = val);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment method updated!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditSeatsDialog() {
    final ctrl = TextEditingController(text: _subTeamSeats.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Team Seats'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Number of Seats', hintText: '25'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                setState(() => _subTeamSeats = val);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Team seats updated to $val!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. HOME TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab(AccountModel account, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileHero(account, isDark),

        // Quick Actions 2x2 Grid (100% Overflow-free)
        _buildQuickActionGrid(account, isDark, isMobile),
        const SizedBox(height: 16),

        // Account Storage Card
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIconBadge(Icons.cloud_outlined, isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Account Storage',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.05,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(_brandBlue),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '0.0 GB used',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '15.0 GB total',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Quick Action Grid Layout with Auto-height (No Fixed Grid Aspect Ratio = Zero Overflow)
  Widget _buildQuickActionGrid(AccountModel account, bool isDark, bool isMobile) {
    final items = [
      _QuickAction(
        icon: Icons.person_outline_rounded,
        title: 'Personal Info',
        subtitle: 'Name, photo, email',
        color: const Color(0xFF3B82F6),
        onTap: () => _switchTab(1),
      ),
      _QuickAction(
        icon: Icons.card_membership_rounded,
        title: 'Payments',
        subtitle: 'Subscriptions',
        color: const Color(0xFF10B981),
        onTap: () => _switchTab(2),
      ),
      _QuickAction(
        icon: Icons.cloud_outlined,
        title: 'Storage',
        subtitle: 'Account limits',
        color: const Color(0xFF8B5CF6),
        onTap: () => _switchTab(3),
      ),
      _QuickAction(
        icon: Icons.security_outlined,
        title: 'B2 Auth',
        subtitle: 'Security & login',
        color: const Color(0xFF0EA5E9),
        onTap: () => _switchTab(4),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            return GestureDetector(
              onTap: item.onTap,
              child: SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? BNXColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 18, color: item.color),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. PERSONAL INFO TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPersonalInfoTab(AccountModel account, bool isDark, bool isMobile) {
    final username = account.email.split('@').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Info Card
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Basic Info', Icons.badge_outlined, isDark),
              const SizedBox(height: 4),
              Text(
                'Visible to other BNX users',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.camera_alt_outlined,
                label: 'Photo',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarWidget(
                      name: account.name,
                      avatarUrl: account.avatarUrl,
                      size: 32,
                      fontSize: 13,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildSmallButton('Change', onTap: _pickAndUploadPhoto, isDark: isDark),
                    ),
                  ],
                ),
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.person_outline_rounded,
                label: 'Full Name',
                value: account.name,
                isClickable: true,
                onTap: () => _editFullName(account),
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.alternate_email_rounded,
                label: 'Username',
                value: username,
                isClickable: true,
                onTap: () => _editUsername(account),
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.tag_rounded,
                label: 'Account ID',
                value: (account.id.isNotEmpty && account.id != 'loading')
                    ? (account.id.startsWith('#') ? account.id : '#${account.id.length > 8 ? account.id.substring(0, 8) : account.id}')
                    : '#BNX-${(account.email.hashCode.abs() % 9000) + 1000}',
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.cake_outlined,
                label: 'Birthday',
                value: account.dob != null
                    ? '${account.dob!.day}/${account.dob!.month}/${account.dob!.year}'
                    : 'Not set',
                isClickable: true,
                onTap: () => _selectBirthday(account),
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.business_center_outlined,
                label: 'Account Type',
                isClickable: true,
                onTap: () => _editAccountType(account),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_brandBlue.withValues(alpha: 0.15), _brandBlueLight.withValues(alpha: 0.1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    account.accountType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _brandBlue,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Contact Info Card
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Contact Info', Icons.contact_mail_outlined, isDark),
              const SizedBox(height: 16),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.email_outlined,
                label: 'Email',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        account.email,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '✓',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _accentGreen),
                      ),
                    ),
                  ],
                ),
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.mail_outline_rounded,
                label: 'Recovery',
                value: (account.recoveryEmail != null && account.recoveryEmail!.isNotEmpty)
                    ? account.recoveryEmail
                    : 'Not set',
                isClickable: true,
                onTap: () => _editRecoveryEmail(account),
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: (account.phone != null && account.phone!.isNotEmpty)
                    ? account.phone
                    : 'Not set',
                isClickable: true,
                onTap: () => _editPhone(account),
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Preferences Card
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Preferences', Icons.tune_rounded, isDark),
              const SizedBox(height: 16),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.language_rounded,
                label: 'Language',
                value: account.language,
                isClickable: true,
                onTap: () => _selectLanguage(account),
              ),
              _buildInfoTile(
                isDark: isDark,
                icon: Icons.accessibility_new_rounded,
                label: 'Accessibility',
                value: account.accessibility,
                isClickable: true,
                onTap: () => _selectAccessibility(account),
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. EMAILS & IDENTITIES TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmailsTab(AccountModel account, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Email Identities', Icons.alternate_email_rounded, isDark),
              const SizedBox(height: 16),

              // Primary email card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A5F), const Color(0xFF1E293B)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFF0F9FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? _brandBlueLight.withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_brandBlue, _brandBlueLight]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.email_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.email,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Primary email address',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'New email addresses can be registered through the BNX Mail application.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          height: 1.4,
                        ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. WORKSPACES & TEAMS (ORGANIZATION HUB)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWorkspacesTab(AccountModel account, bool isDark, bool isMobile) {
    final colabGroups = ref.watch(colabListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Hero Organization Header Banner & Workspace Switcher ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF311B92), const Color(0xFF0F172A)]
                  : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.corporate_fare_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedWorkspace,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$_userRole • ${account.email}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _editUserRole,
                              child: const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == '__add__') {
                        _showAddWorkspaceModal();
                      } else {
                        setState(() => _selectedWorkspace = val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched workspace to "$val"'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Switch', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      ..._workspaces.map((w) => PopupMenuItem(
                            value: w,
                            child: Text('$w${w == _selectedWorkspace ? ' (Active)' : ''}'),
                          )),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: '__add__',
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: _brandBlue),
                            SizedBox(width: 8),
                            Text('+ Add New Workspace', style: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 2. Team & Casbox Group Memberships Card (Connected to Riverpod) ──
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildSectionHeader('Casbox & Team Groups', Icons.groups_rounded, isDark),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateGroupModal(context, isDark),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Group', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: _brandBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Live collaborative channels linked to your account',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 14),

              if (colabGroups.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.forum_outlined, size: 36, color: isDark ? Colors.white38 : Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No Casbox groups found',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateGroupModal(context, isDark),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Create First Team Group'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...colabGroups.map((group) {
                  final isLast = group == colabGroups.last;
                  final memberCount = group.members.length;
                  return _buildActionTile(
                    isDark: isDark,
                    icon: Icons.forum_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: group.name,
                    subtitle: group.desc.isNotEmpty
                        ? '${group.desc} • $memberCount members'
                        : '$memberCount members • Casbox Channel',
                    trailingWidget: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _brandBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        memberCount > 1 ? 'Team' : 'Personal',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brandBlue),
                      ),
                    ),
                    onTap: () {
                      context.push('/colab');
                    },
                    showDivider: !isLast,
                  );
                }),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 3. Shared Mailboxes & Email Delegation Card ──
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildSectionHeader('Shared Mailboxes & Delegates', Icons.mark_email_read_rounded, isDark),
                  ),
                  TextButton.icon(
                    onPressed: _showAddSharedMailboxModal,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Mailbox', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: _brandBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Manage team email aliases and executive delegation rights',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 14),

              ..._sharedMailboxes.map((box) {
                final isLast = box == _sharedMailboxes.last;
                return _buildActionTile(
                  isDark: isDark,
                  icon: Icons.mark_email_unread_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: box['email'] ?? '',
                  subtitle: box['subtitle'] ?? 'Shared Mailbox',
                  trailingWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Delegate',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                  ),
                  onTap: () {},
                  showDivider: !isLast,
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 4. Ecosystem Workspace Seats Card ──
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Company Seat Allocations', Icons.badge_rounded, isDark),
              const SizedBox(height: 4),
              Text(
                'Product tier seats provisioned by your corporate admin',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 14),

              _buildActionTile(
                isDark: isDark,
                icon: Icons.business_center_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Cliks Business (Billing App)',
                subtitle: 'Enterprise Seat • Full Admin Rights',
                onTap: () {},
              ),
              _buildActionTile(
                isDark: isDark,
                icon: Icons.build_circle_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Bit Tool (API Suite)',
                subtitle: 'Developer Tier Workspace • 50,000 API req/mo',
                onTap: () {},
                showDivider: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  void _showCreateGroupModal(BuildContext context, bool isDark) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final memberCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Team Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Mobile Engineering',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Group purpose & goals',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: memberCtrl,
              decoration: const InputDecoration(
                labelText: 'Member Emails (comma separated)',
                hintText: 'alex@bnxmail.com, sara@bnxmail.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final members = memberCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              Navigator.pop(dialogCtx);

              await ref.read(colabListProvider.notifier).addGroup(
                    name: name,
                    members: members,
                    desc: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Team workspace group',
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Team Group "$name" created successfully!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. DATA & PRIVACY TAB (ADVANCED SECURITY & PRIVACY CONTROLS)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDataPrivacyTab(AccountModel account, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Hero Privacy Shield Status Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E3A5F)]
                  : [const Color(0xFF0284C7), const Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Privacy Guard Active',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Zero-knowledge encryption & B2 Auth security',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 2. Security & Encryption Controls Card ──
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Security & Encryption', Icons.lock_outline_rounded, isDark),
              const SizedBox(height: 4),
              Text(
                'Protect your messages and identity across BNX apps',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 12),

              _buildPrivacySwitchTile(
                isDark: isDark,
                icon: Icons.enhanced_encryption_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Zero-Knowledge Encryption',
                subtitle: 'Hardware PGP encryption for emails & attachments',
                value: _zeroKnowledgeEncryption,
                onChanged: (v) => setState(() => _zeroKnowledgeEncryption = v),
              ),
              _buildPrivacySwitchTile(
                isDark: isDark,
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Biometric App Lock',
                subtitle: 'Require Face ID or Fingerprint for Casbox & Mail',
                value: _biometricLock,
                onChanged: (v) => setState(() => _biometricLock = v),
              ),
              _buildPrivacySwitchTile(
                isDark: isDark,
                icon: Icons.wrong_location_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Location Metadata Scrubbing',
                subtitle: 'Automatically strip GPS and IP data from files',
                value: _locationScrubbing,
                onChanged: (v) => setState(() => _locationScrubbing = v),
                showDivider: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 3. Activity & Data Privacy Vault Card ──
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Activity & Data Controls', Icons.data_usage_rounded, isDark),
              const SizedBox(height: 4),
              Text(
                'Manage activity logs and history retention',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 12),

              _buildPrivacySwitchTile(
                isDark: isDark,
                icon: Icons.history_toggle_off_rounded,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Web & App Activity Vault',
                subtitle: 'Encrypt activity logs across BNX services',
                value: _webAppActivity,
                onChanged: (v) => setState(() => _webAppActivity = v),
              ),
              _buildPrivacySwitchTile(
                isDark: isDark,
                icon: Icons.auto_delete_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Auto-Purge Search Logs',
                subtitle: 'Automatically erase search history after 30 days',
                value: _autoPurgeSearch,
                onChanged: (v) => setState(() => _autoPurgeSearch = v),
                showDivider: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 4. Data Export & Takeout Archive Card ──
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Data Export & Storage', Icons.cloud_download_outlined, isDark),
              const SizedBox(height: 4),
              Text(
                'Download or manage your BNX account data',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
              const SizedBox(height: 16),

              _buildActionTile(
                isDark: isDark,
                icon: Icons.download_for_offline_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Download Account Archive',
                subtitle: 'Export emails, contacts, and settings (JSON/MBOX)',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preparing your BNX data archive download...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildActionTile(
                isDark: isDark,
                icon: Icons.cleaning_services_rounded,
                iconColor: const Color(0xFF64748B),
                title: 'Clear Offline Storage Cache',
                subtitle: 'Frees up local device storage without deleting cloud emails',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offline storage cache cleared successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                showDivider: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 5. Account Removal Card ──
        _buildGlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Account Retention', Icons.warning_amber_rounded, isDark),
              const SizedBox(height: 16),

              _buildActionTile(
                isDark: isDark,
                icon: Icons.delete_forever_rounded,
                iconColor: Colors.redAccent,
                title: 'Delete B2 Auth Account',
                subtitle: 'Permanently remove your account and all associated data',
                onTap: () {
                  _showDeleteAccountConfirmationDialog(context, isDark);
                },
                showDivider: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPrivacySwitchTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: _brandBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmationDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Delete Account?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This action is irreversible. All emails, Casbox messages, and profile configurations will be permanently deleted from B2 Auth.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _handleSignOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED UTILITY COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGlassCard({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? BNXColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        _buildIconBadge(icon, isDark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildIconBadge(IconData icon, bool isDark) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _brandBlue.withValues(alpha: isDark ? 0.25 : 0.12),
            _brandBlueLight.withValues(alpha: isDark ? 0.15 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isDark ? _brandBlueLight : _brandBlue,
      ),
    );
  }

  Widget _buildInfoTile({
    required bool isDark,
    required IconData icon,
    required String label,
    String? value,
    Widget? trailing,
    bool isClickable = false,
    bool showDivider = true,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: trailing ??
                Text(
                  value ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF334155),
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
          if (isClickable || onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ],
        ],
      ),
    );

    if (isClickable || onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }

  Widget _buildActionTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailingWidget,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(width: 8),
            trailingWidget,
          ],
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: tile,
      );
    }
    return tile;
  }

  Widget _buildSmallButton(String text, {required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? _brandBlueLight : _brandBlue,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYMENTS & SUBSCRIPTIONS TAB (CLIKS BUSINESS & COMPANY APPS)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaymentAndSubscriptionTab(AccountModel account, bool isDark, bool isMobile) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Hero Header Banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E3A5F)]
                  : [const Color(0xFF195BAC), const Color(0xFF1E40AF)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.subscriptions_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Payments & Subscriptions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage product licenses & company environment apps',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 2. FEATURED PRODUCT SUBSCRIPTION: CLIKS BUSINESS ──
        const Text(
          'Active Product Subscription',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _brandBlue.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_center_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _subPlanName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _accentGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _accentGreen, width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: _accentGreen, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'SUBSCRIBED',
                                    style: TextStyle(
                                      color: _accentGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Billing App • $_subPrice',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: borderColor),
              const SizedBox(height: 12),

              // Plan Details Grid
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _buildSubDetailItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Next Renewal',
                    value: _subRenewalDate,
                    isDark: isDark,
                  ),
                  _buildSubDetailItem(
                    icon: Icons.credit_card_rounded,
                    label: 'Payment Method',
                    value: _subPaymentMethod,
                    isDark: isDark,
                  ),
                  _buildSubDetailItem(
                    icon: Icons.people_outline_rounded,
                    label: 'Team Seats',
                    value: '$_subTeamSeats Active Seats',
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showManageSubscriptionDialog,
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Manage Subscription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Upgrade Plan'),
                          children: [
                            SimpleDialogOption(
                              onPressed: () {
                                setState(() {
                                  _subPlanName = 'Cliks Enterprise';
                                  _subPrice = '\$79/month';
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Upgraded to Cliks Enterprise!'), behavior: SnackBarBehavior.floating),
                                );
                              },
                              child: const Text('Cliks Enterprise (\$79/mo) • Unlimited seats & priority support'),
                            ),
                            SimpleDialogOption(
                              onPressed: () {
                                setState(() {
                                  _subPlanName = 'Cliks Business';
                                  _subPrice = '\$29/month';
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text('Cliks Business (\$29/mo) • Standard business tier'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                    label: const Text('Upgrade Plan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandBlue,
                      side: BorderSide(color: _brandBlue.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Billing History'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                ListTile(
                                  leading: Icon(Icons.receipt_long_rounded, color: _brandBlue),
                                  title: Text('Invoice #BNX-9942'),
                                  subtitle: Text('Jul 15, 2026 • \$29.00 (Paid)'),
                                ),
                                Divider(),
                                ListTile(
                                  leading: Icon(Icons.receipt_long_rounded, color: _brandBlue),
                                  title: Text('Invoice #BNX-8821'),
                                  subtitle: Text('Jun 15, 2026 • \$29.00 (Paid)'),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Billing History'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── 3. COMPANY ENVIRONMENT APPS ──
        const Text(
          'Company Apps & Products',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Authorized apps & services configured in your company ecosystem',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),

        // List of all Company Apps
        _buildCompanyAppTile(
          name: 'BNX Mail',
          category: 'Communication & secure email app',
          status: 'Active (Primary)',
          icon: Icons.mark_email_read_rounded,
          iconBg: const Color(0xFF195BAC),
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 10),
        _buildCompanyAppTile(
          name: 'Cliks Business',
          category: 'Billing app',
          status: 'Subscribed (\$29/mo)',
          icon: Icons.business_center_rounded,
          iconBg: const Color(0xFF2563EB),
          isSubscribedProduct: true,
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 10),
        _buildCompanyAppTile(
          name: 'Cliks',
          category: 'Personal expenses monitoring app',
          status: 'Active (Free Tier)',
          icon: Icons.account_balance_wallet_rounded,
          iconBg: const Color(0xFF0EA5E9),
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 10),
        _buildCompanyAppTile(
          name: 'B2 Auth',
          category: 'Security provider app',
          status: 'Active (Connected)',
          icon: Icons.security_rounded,
          iconBg: const Color(0xFF8B5CF6),
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 10),
        _buildCompanyAppTile(
          name: 'Bit Tool',
          category: 'Developer toolkit & API suite',
          status: 'Active (Connected)',
          icon: Icons.build_circle_rounded,
          iconBg: const Color(0xFFF59E0B),
          isDark: isDark,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSubDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyAppTile({
    required String name,
    required String category,
    required String status,
    required IconData icon,
    required Color iconBg,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    bool isSubscribedProduct = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSubscribedProduct
              ? _brandBlue.withValues(alpha: 0.5)
              : borderColor,
          width: isSubscribedProduct ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isSubscribedProduct) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _brandBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SUBSCRIPTION PRODUCT',
                      style: TextStyle(
                        color: _brandBlue,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isSubscribedProduct ? _brandBlue : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════

class _TabItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  const _TabItem({
    required this.title,
    required this.icon,
    required this.selectedIcon,
  });
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
