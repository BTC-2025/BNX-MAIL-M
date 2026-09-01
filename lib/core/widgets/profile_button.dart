import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'avatar_widget.dart';
import '../../data/app_state_provider.dart';
import '../../data/account_provider.dart';
import '../../data/email_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../theme/colors.dart';
import '../constants/constants.dart';

class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final user = ref.watch(activeAccountProvider);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BNXConstants.borderRadiusL),
          side: BorderSide(
            color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
            width: 1,
          ),
        ),
        color: isDark ? BNXColors.darkSurface : BNXColors.lightSurface,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? BNXColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? BNXColors.darkBorder : BNXColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWidget(
                name: user.name,
                avatarUrl: user.avatarUrl,
                size: 28,
                fontSize: 12,
              ),
              const SizedBox(width: 8),
              // Hide email on small screens for responsiveness
              if (MediaQuery.of(context).size.width > 700) ...[
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? BNXColors.darkTextPrimary
                        : BNXColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: isDark
                    ? BNXColors.darkTextSecondary
                    : BNXColors.lightTextSecondary,
              ),
            ],
          ),
        ),
        onSelected: (value) async {
          if (value == 'account') {
            context.push('/manage-account');
          } else if (value == 'profile') {
            ref.read(appUiProvider.notifier).selectFolder('Profile');
            context.go('/profile');
          } else if (value == 'settings') {
            ref.read(appUiProvider.notifier).selectFolder('Settings');
            context.go('/settings');
          } else if (value == 'theme') {
            ref.read(appUiProvider.notifier).toggleDarkMode();
          } else if (value == 'logout') {
            final activeAccount = ref.read(accountsProvider.notifier).activeAccount;
            final activeEmail = activeAccount.email.isNotEmpty ? activeAccount.email : activeAccount.id;
            await ref.read(accountsProvider.notifier).signOutSingleAccount(
              targetEmail: activeEmail,
              ref: ref,
              context: context,
            );
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 16),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'account',
            child: Row(
              children: [
                Icon(Icons.manage_accounts_outlined, size: 20),
                SizedBox(width: 12),
                Text('Manage Account'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person_pin_outlined, size: 20),
                SizedBox(width: 12),
                Text('My Profile'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings_outlined, size: 20),
                SizedBox(width: 12),
                Text('Settings'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'theme',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Dark Mode'),
                  ],
                ),
                Switch(
                  value: isDark,
                  onChanged: (val) {
                    ref.read(appUiProvider.notifier).toggleDarkMode();
                    Navigator.pop(context);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                SizedBox(width: 12),
                Text('Logout', style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
