import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
import '../../../models/account_model.dart';
import '../../../dummy/dummy_data.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final activeAccount = ref.watch(activeAccountProvider);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Large Avatar
                Center(
                  child: Hero(
                    tag: 'profile-avatar',
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: activeAccount.avatarColor,
                      child: Text(
                        activeAccount.avatarLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Name & Email
                Text(
                  activeAccount.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeAccount.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                if (activeAccount.designation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activeAccount.designation,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Feature 5: Linked Accounts Switcher using ExpansionTile
                NeumorphicContainer(
                  borderRadius: 16,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: GlobalKey(), // Ensures rebuild when switching active accounts
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: activeAccount.avatarColor,
                        child: Text(
                          activeAccount.avatarLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        activeAccount.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        activeAccount.email,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Icon(
                        Icons.expand_more_rounded,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      children: [
                        const Divider(),
                        ...accounts.where((acc) => acc.id != activeAccount.id).map((acc) {
                          return ListTile(
                            onTap: () {
                              ref.read(accountsProvider.notifier).switchAccount(acc.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: acc.avatarColor,
                                        child: Text(
                                          acc.avatarLetter,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('Switched to ${acc.email}'),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: acc.avatarColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            contentPadding: EdgeInsets.zero,
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: acc.avatarColor,
                                  child: Text(
                                    acc.avatarLetter,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (acc.unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 12,
                                        minHeight: 12,
                                      ),
                                      child: Text(
                                        '${acc.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              acc.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              acc.email,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: isDark ? Colors.white24 : Colors.grey.shade400,
                            ),
                          );
                        }),
                        const Divider(),
                        ListTile(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Add Account feature coming soon!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'Add another account',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Divider(),
                const SizedBox(height: 16),
                
                // Profile Actions List
                _buildActionTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Manage Account',
                  isDark: isDark,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Manage Account clicked.')),
                    );
                  },
                ),
                _buildActionTile(
                  icon: Icons.person_pin_outlined,
                  title: 'My Profile',
                  isDark: isDark,
                  onTap: () {
                    _showEditProfileDialog(context, ref, activeAccount, isDark);
                  },
                ),
                _buildActionTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  isDark: isDark,
                  onTap: () {
                    ref.read(appUiProvider.notifier).selectFolder('Settings');
                    context.go('/settings');
                  },
                ),
                
                // Dark Mode Switch Tile
                NeumorphicContainer(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  borderRadius: 12,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.dark_mode_outlined,
                        color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (val) {
                        ref.read(appUiProvider.notifier).toggleDarkMode();
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Logout Button
                _buildActionTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  color: Colors.redAccent,
                  isDark: isDark,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logout clicked (Mock).')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary);
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
          child: Icon(
            icon,
            color: themeColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: color ?? Colors.grey,
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, AccountModel account, bool isDark) {
    final nameController = TextEditingController(text: account.name);
    final designationController = TextEditingController(text: account.designation);
    final experienceController = TextEditingController(text: account.experience);
    DateTime? selectedDob = account.dob;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String dobText = selectedDob == null
                ? 'Select DOB'
                : '${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}';
            
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Personal Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BNXColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter name...',
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: BNXColors.lightPrimary, width: 2),
                          ),
                        ),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Designation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: designationController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Flutter Developer...',
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: BNXColors.lightPrimary, width: 2),
                          ),
                        ),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Professional Experience',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: experienceController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe your professional experience...',
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: BNXColors.lightPrimary, width: 2),
                          ),
                        ),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Date of Birth',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : BNXColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDob ?? DateTime(1995, 1, 1),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDob = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dobText,
                                style: TextStyle(
                                  color: selectedDob == null
                                      ? Colors.grey
                                      : (isDark ? Colors.white : Colors.black87),
                                  fontSize: 14,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BNXColors.lightPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              ref.read(accountsProvider.notifier).updateProfile(
                                    account.id,
                                    name: nameController.text.trim(),
                                    designation: designationController.text.trim(),
                                    experience: experienceController.text.trim(),
                                    dob: selectedDob,
                                  );
                              
                              Navigator.of(context).pop();
                            },
                            child: const Text('Save Details', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
