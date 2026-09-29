import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
import '../../auth/presentation/notifiers/auth_notifier.dart';
import '../../../data/email_provider.dart';
import '../../../data/all_inboxes_provider.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isExpanded = false;

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

          // Update Riverpod account state immediately (handles server upload & settings synchronization)
          await ref
              .read(accountsProvider.notifier)
              .updateAvatar(activeAccount.id, base64String);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully!'),
                backgroundColor: Color(0xFF195bac),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final activeAccount = ref.watch(activeAccountProvider);
    final accounts = ref.watch(accountsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF195bac),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? BNXColors.darkBg : const Color(0xFFE9F4FF),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF195bac),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.of(context).padding.top + 4,
                  8,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () {
                            ref
                                .read(appUiProvider.notifier)
                                .selectFolder('Settings');
                            context.go('/settings');
                          },
                          tooltip: 'Settings',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.manage_accounts_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () {
                            context.push('/manage-account');
                          },
                          tooltip: 'Manage Account',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Large circular profile/avatar with R logo / custom photo & camera upload icon
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickAndUploadPhoto,
                          child: Container(
                            width: 94,
                            height: 94,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 3,
                              ),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: AvatarWidget(
                              name: activeAccount.name,
                              avatarUrl: activeAccount.avatarUrl,
                              size: 82,
                              fontSize: 34,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF195bac),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Color(0xFF195bac),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Username with dropdown arrow — tap to expand inline
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeAccount.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Email Address
                    Text(
                      activeAccount.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    // Inline expandable account switcher
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 280),
                      crossFadeState: _isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                          children: [
                            // Divider
                            Divider(
                              color: Colors.white.withValues(alpha: 0.2),
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            // Account rows
                            ...accounts.map((acc) {
                              final isSelected = acc.id == activeAccount.id;
                              return GestureDetector(
                                onTap: () async {
                                  if (!isSelected) {
                                    // Close dropdown immediately for instant visual feedback
                                    setState(() => _isExpanded = false);

                                    final targetId = acc.email.isNotEmpty
                                        ? acc.email
                                        : acc.id;
                                    // Switch account — updates tokens & all provider caches
                                    await ref
                                        .read(accountsProvider.notifier)
                                        .switchAccount(targetId, ref);

                                    if (context.mounted) {
                                      // Navigate directly to /home (inside DashboardShell).
                                      // NEVER go to '/' — that is the SplashScreen and causes
                                      // a double-navigation black screen (/ → splash → /home).
                                      context.go('/home');
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Switched to ${acc.email.isNotEmpty ? acc.email : acc.name}',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  } else {
                                    setState(() => _isExpanded = false);
                                  }
                                },

                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.45)
                                          : Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      AvatarWidget(
                                        name: acc.name,
                                        avatarUrl: acc.avatarUrl,
                                        size: 32,
                                        fontSize: 13,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              acc.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              acc.email,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.65,
                                                ),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            // Add another account
                            GestureDetector(
                              onTap: () {
                                setState(() => _isExpanded = false);
                                context.push('/login');
                              },
                              child: Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Add another account',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Location badge — only when collapsed
                    if (!_isExpanded) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'IN India',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Profile Actions List
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Add another account
                  _buildActionTile(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Add another account',
                    isDark: isDark,
                    onTap: () {
                      context.push('/login');
                    },
                  ),

                  // Sign out of this account
                  _buildActionTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign out of this account',
                    color: Colors.orangeAccent,
                    isDark: isDark,
                    onTap: () async {
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
                  _buildActionTile(
                    icon: Icons.power_settings_new_rounded,
                    title: 'Sign out of all accounts',
                    color: Colors.redAccent,
                    isDark: isDark,
                    onTap: () async {
                      // Wipe all session tokens & saved account registries completely
                      await AuthRepository.logout();

                      // Clear local state providers AFTER await (not during build)
                      ref.read(emailProvider.notifier).clear();
                      ref.read(accountsProvider.notifier).clear();
                      ref.read(allInboxesProvider.notifier).clear();
                      ref.read(authProvider.notifier).logout();

                      if (context.mounted) {
                        // Navigate to login directly — no splash bounce
                        context.go('/login');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Logged out of all accounts successfully.',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required bool isDark,
    VoidCallback? onTap,
    Color? color,
    Widget? trailing,
  }) {
    final themeColor =
        color ?? (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary);
    return NeumorphicContainer(
      margin: const EdgeInsets.symmetric(vertical: 6),
      borderRadius: 12,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: themeColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
        trailing:
            trailing ??
            Icon(Icons.chevron_right_rounded, color: color ?? Colors.grey),
      ),
    );
  }

}
