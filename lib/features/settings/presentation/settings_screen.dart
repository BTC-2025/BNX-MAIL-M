import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/neumorphic.dart';
import '../../../data/app_state_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // State variables for settings
  bool _conversationView = true;
  bool _hideBottomNavOnScroll = true;
  bool _autoFitMessages = true;
  bool _openWebLinks = true;
  bool _confirmDelete = false;
  bool _confirmArchive = false;
  bool _confirmSend = false;

  // Fully workable new settings states
  String _defaultNotificationAction = 'Archive';
  bool _pushNotificationsEnabled = true;
  bool _notificationSoundEnabled = true;
  String _conversationDensity = 'Default';
  String _swipeLeftAction = 'Delete';
  String _swipeRightAction = 'Archive';
  String _defaultReplyAction = 'Reply';
  String _autoAdvance = 'Conversation list';

  void _showChoiceDialog({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = ref.read(appUiProvider).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: NeumorphicContainer(
          width: 320,
          borderRadius: 20,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final isSelected = opt == currentValue;
                return InkWell(
                  onTap: () {
                    onSelected(opt);
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected 
                                ? (isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationSettingsDialog() {
    final isDark = ref.read(appUiProvider).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: NeumorphicContainer(
            width: 320,
            borderRadius: 20,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable notifications',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  value: _pushNotificationsEnabled,
                  onChanged: (val) {
                    setState(() => _pushNotificationsEnabled = val);
                    setDialogState(() {});
                  },
                  activeColor: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Play sound',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  value: _notificationSoundEnabled,
                  onChanged: _pushNotificationsEnabled
                      ? (val) {
                          setState(() => _notificationSoundEnabled = val);
                          setDialogState(() {});
                        }
                      : null,
                  activeColor: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: NeumorphicButton(
                    onPressed: () => Navigator.pop(ctx),
                    borderRadius: 12,
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white70 : BNXColors.lightPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSwipeActionsDialog() {
    final isDark = ref.read(appUiProvider).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: NeumorphicContainer(
            width: 320,
            borderRadius: 20,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure Swipe Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Swipe Left Action',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _swipeLeftAction,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      items: ['Delete', 'Archive', 'Snooze', 'None'].map((val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _swipeLeftAction = val!);
                        setDialogState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Swipe Right Action',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _swipeRightAction,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      items: ['Delete', 'Archive', 'Snooze', 'None'].map((val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _swipeRightAction = val!);
                        setDialogState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: NeumorphicButton(
                    onPressed: () => Navigator.pop(ctx),
                    borderRadius: 12,
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white70 : BNXColors.lightPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(appUiProvider.notifier).selectFolder('Inbox');
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightBg,
        appBar: AppBar(
          backgroundColor: isDark ? BNXColors.darkBg : BNXColors.lightBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              ref.read(appUiProvider.notifier).selectFolder('Inbox');
              context.go('/');
            },
          ),
          title: Text(
            'General settings',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87),
              onPressed: () {},
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Group 1: General Preferences
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: NeumorphicContainer(
                borderRadius: 16,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Column(
                  children: [
                    _buildSettingsTile(
                      title: 'Theme',
                      subtitle: isDark ? 'Dark' : 'System default',
                      onTap: () => ref.read(appUiProvider.notifier).toggleDarkMode(),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      title: 'Default notification action',
                      subtitle: _defaultNotificationAction,
                      onTap: () => _showChoiceDialog(
                        title: 'Default notification action',
                        options: ['Archive', 'Delete', 'Mark as read'],
                        currentValue: _defaultNotificationAction,
                        onSelected: (val) => setState(() => _defaultNotificationAction = val),
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      title: 'Manage notifications',
                      subtitle: _pushNotificationsEnabled
                          ? 'Enabled${_notificationSoundEnabled ? ' (Sound)' : ' (Silent)'}'
                          : 'Disabled',
                      onTap: _showNotificationSettingsDialog,
                    ),
                  ],
                ),
              ),
            ),

            // Group 2: View and Density
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: NeumorphicContainer(
                borderRadius: 16,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Column(
                  children: [
                    _buildCheckboxTile(
                      title: 'Conversation view',
                      subtitle: 'Group emails in the same conversation for IMAP, POP3 and Exchange accounts',
                      value: _conversationView,
                      onChanged: (val) => setState(() => _conversationView = val!),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      title: 'Conversation list density',
                      subtitle: _conversationDensity,
                      onTap: () => _showChoiceDialog(
                        title: 'Conversation list density',
                        options: ['Default', 'Comfortable', 'Compact'],
                        currentValue: _conversationDensity,
                        onSelected: (val) => setState(() => _conversationDensity = val),
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildCheckboxTile(
                      title: 'Hide bottom navigation on scroll',
                      value: _hideBottomNavOnScroll,
                      onChanged: (val) => setState(() => _hideBottomNavOnScroll = val!),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      title: 'Swipe actions',
                      subtitle: 'Left: $_swipeLeftAction | Right: $_swipeRightAction',
                      onTap: _showSwipeActionsDialog,
                    ),
                  ],
                ),
              ),
            ),

            // Group 3: Reply and Advanced Reading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: NeumorphicContainer(
                borderRadius: 16,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Column(
                  children: [
                    _buildSettingsTile(
                      title: 'Default reply action',
                      subtitle: _defaultReplyAction,
                      onTap: () => _showChoiceDialog(
                        title: 'Default reply action',
                        options: ['Reply', 'Reply all'],
                        currentValue: _defaultReplyAction,
                        onSelected: (val) => setState(() => _defaultReplyAction = val),
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildCheckboxTile(
                      title: 'Auto-fit messages',
                      subtitle: 'Shrink messages to fit the screen',
                      value: _autoFitMessages,
                      onChanged: (val) => setState(() => _autoFitMessages = val!),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildSettingsTile(
                      title: 'Auto-advance',
                      subtitle: _autoAdvance,
                      onTap: () => _showChoiceDialog(
                        title: 'Auto-advance',
                        options: ['Newer conversation', 'Older conversation', 'Conversation list'],
                        currentValue: _autoAdvance,
                        onSelected: (val) => setState(() => _autoAdvance = val),
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildCheckboxTile(
                      title: 'Open web links in BNXMail',
                      subtitle: 'Turn on for faster browsing',
                      value: _openWebLinks,
                      onChanged: (val) => setState(() => _openWebLinks = val!),
                    ),
                  ],
                ),
              ),
            ),

            // Group 4: Action Confirmations
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Action confirmations',
                style: TextStyle(
                  color: isDark ? BNXColors.darkPrimary : BNXColors.lightPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: NeumorphicContainer(
                borderRadius: 16,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Column(
                  children: [
                    _buildCheckboxTile(
                      title: 'Confirm before deleting',
                      value: _confirmDelete,
                      onChanged: (val) => setState(() => _confirmDelete = val!),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildCheckboxTile(
                      title: 'Confirm before archiving',
                      value: _confirmArchive,
                      onChanged: (val) => setState(() => _confirmArchive = val!),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _buildCheckboxTile(
                      title: 'Confirm before sending',
                      value: _confirmSend,
                      onChanged: (val) => setState(() => _confirmSend = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({required String title, String? subtitle, VoidCallback? onTap}) {
    final isDark = ref.read(appUiProvider).isDarkMode;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    final isDark = ref.read(appUiProvider).isDarkMode;
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: BNXColors.lightPrimary,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}

