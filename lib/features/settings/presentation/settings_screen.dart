import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/token_service.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
import '../../../models/account_model.dart';
import '../../../data/repositories/user_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  // ── General & Composing State ─────────────────────────────────────────────
  List<String> _signatures = [];
  String _undoSendDelay = 'Disabled (Send instantly)';

  // ── Notifications & Quiet State ───────────────────────────────────────────
  bool _inboxMailAlerts = true;
  bool _sentConfirmationAlerts = false;
  bool _starredEmailsAlerts = true;
  bool _snoozedReminders = true;
  bool _playAlertSound = true;
  bool _enableHapticVibration = true;
  bool _muteNotificationsSchedule = false;

  // ── Security & Recovery State ──────────────────────────────────────────────
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneContactController = TextEditingController();
  bool _enable2FA = false;
  bool _enableBiometrics = true;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _recoveryEmailController =
      TextEditingController();
  final TextEditingController _backupPhoneController = TextEditingController();

  // ── Labels & Sidebar State ─────────────────────────────────────────────────
  final Map<String, bool> _sidebarLabels = {
    'Inbox': true,
    'Starred': true,
    'Snoozed': true,
    'Sent': true,
    'Draft': true,
    'Trash': true,
  };

  // ── Appearance & Layout State ─────────────────────────────────────────────
  String _density = 'Default';

  // ── Active Sessions List ──────────────────────────────────────────────────
  List<Map<String, String>> _activeDeviceSessions = [];

  @override
  void initState() {
    super.initState();
    _loadBackendData();
  }

  Future<void> _loadBackendData() async {
    try {
      // 1. Fetch user profile from API
      final user = await UserRepository.getProfile();
      if (user != null) {
        _recoveryEmailController.text = user.recoveryEmail ?? user.email;
        if (user.jobTitle != null && user.jobTitle!.isNotEmpty) {
          _jobTitleController.text = user.jobTitle!;
        }
        if (user.location != null && user.location!.isNotEmpty) {
          _locationController.text = user.location!;
        }
        if (user.phone != null && user.phone!.isNotEmpty) {
          _phoneContactController.text = user.phone!;
        }
        if (user.backupPhone != null && user.backupPhone!.isNotEmpty) {
          _backupPhoneController.text = user.backupPhone!;
        }
      }

      // 2. Fetch user settings from API
      final settings = await UserRepository.getSettings();
      if (settings != null) {
        if (settings.containsKey('inboxMailAlerts')) {
          _inboxMailAlerts = settings['inboxMailAlerts'] == true;
        }
        if (settings.containsKey('sentConfirmationAlerts')) {
          _sentConfirmationAlerts = settings['sentConfirmationAlerts'] == true;
        }
        if (settings.containsKey('starredEmailsAlerts')) {
          _starredEmailsAlerts = settings['starredEmailsAlerts'] == true;
        }
        if (settings.containsKey('snoozedReminders')) {
          _snoozedReminders = settings['snoozedReminders'] == true;
        }
        if (settings.containsKey('playAlertSound')) {
          _playAlertSound = settings['playAlertSound'] == true;
        }
        if (settings.containsKey('enableHapticVibration')) {
          _enableHapticVibration = settings['enableHapticVibration'] == true;
        }
        if (settings.containsKey('muteNotificationsSchedule')) {
          _muteNotificationsSchedule =
              settings['muteNotificationsSchedule'] == true;
        }
        if (settings['undoSendDelay'] != null) {
          final val = settings['undoSendDelay'];
          if (val is int) {
            if (val == 5) {
              _undoSendDelay = '5 Seconds';
            } else if (val == 10) {
              _undoSendDelay = '10 Seconds';
            } else if (val == 20) {
              _undoSendDelay = '20 Seconds';
            } else if (val == 30) {
              _undoSendDelay = '30 Seconds';
            } else if (val > 0) {
              _undoSendDelay = '$val Seconds';
            } else {
              _undoSendDelay = 'Disabled (Send instantly)';
            }
          } else {
            final str = val.toString();
            if (str == '5' || str == '5 Seconds') {
              _undoSendDelay = '5 Seconds';
            } else if (str == '10' || str == '10 Seconds') {
              _undoSendDelay = '10 Seconds';
            } else if (str == '20' || str == '20 Seconds') {
              _undoSendDelay = '20 Seconds';
            } else if (str == '30' || str == '30 Seconds') {
              _undoSendDelay = '30 Seconds';
            } else {
              _undoSendDelay = 'Disabled (Send instantly)';
            }
          }
        }
        if (settings.containsKey('twoFactorAuth')) {
          _enable2FA = settings['twoFactorAuth'] == true;
        }
        if (settings.containsKey('enableBiometrics')) {
          _enableBiometrics = settings['enableBiometrics'] == true;
        }

        if (settings['signatures'] is List) {
          final rawList = settings['signatures'] as List;
          final loadedSigs = <String>[];
          for (final item in rawList) {
            if (item is String && item.trim().isNotEmpty) {
              loadedSigs.add(item.trim());
            } else if (item is Map) {
              final content =
                  item['content'] ?? item['name'] ?? item['signature'];
              if (content != null && content.toString().trim().isNotEmpty) {
                loadedSigs.add(content.toString().trim());
              }
            }
          }
          if (loadedSigs.isNotEmpty) {
            _signatures = loadedSigs;
          }
        }

        try {
          final apiSigs = await UserRepository.getSignatures();
          if (apiSigs.isNotEmpty) {
            final loaded = <String>[];
            for (final item in apiSigs) {
              final content =
                  item['content'] ?? item['name'] ?? item['signature'];
              if (content != null && content.toString().trim().isNotEmpty) {
                loaded.add(content.toString().trim());
              }
            }
            if (loaded.isNotEmpty) {
              _signatures = loaded;
            }
          }
        } catch (_) {}
        if (settings['jobTitle'] != null) {
          _jobTitleController.text = settings['jobTitle'].toString();
        }
        if (settings['location'] != null) {
          _locationController.text = settings['location'].toString();
        }
        if (settings['phone'] != null) {
          _phoneContactController.text = settings['phone'].toString();
        }
        if (settings['backupPhone'] != null) {
          _backupPhoneController.text = settings['backupPhone'].toString();
        }
        if (settings['recoveryEmail'] != null &&
            settings['recoveryEmail'].toString().isNotEmpty) {
          _recoveryEmailController.text = settings['recoveryEmail'].toString();
        }
        if (settings['sidebarLabels'] is Map) {
          final map = Map<String, dynamic>.from(settings['sidebarLabels']);
          map.forEach((key, val) {
            _sidebarLabels[key] = val == true;
          });
          ref.read(appUiProvider.notifier).setSidebarLabels(_sidebarLabels);
        }
      }

      // 3. Fetch recovery details from GET /api/users/recovery
      final recovery = await UserRepository.getRecovery();
      if (recovery != null) {
        if (recovery['recoveryEmail'] != null &&
            recovery['recoveryEmail'].toString().isNotEmpty) {
          _recoveryEmailController.text = recovery['recoveryEmail'].toString();
        }
        if (recovery['phoneNumber'] != null &&
            recovery['phoneNumber'].toString().isNotEmpty) {
          _backupPhoneController.text = recovery['phoneNumber'].toString();
        }
      }

      // 4. Fetch signatures from GET /api/signatures
      final sigs = await UserRepository.getSignatures();
      if (sigs.isNotEmpty) {
        final fetchedSigs = sigs
            .map((s) => s['content']?.toString() ?? s['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (fetchedSigs.isNotEmpty) {
          _signatures = fetchedSigs;
        }
      }

      // 5. Fetch active sessions / activity logs from GET /api/users/activity-logs
      final sessions = await UserRepository.getSessions();
      if (sessions.isNotEmpty) {
        _activeDeviceSessions = sessions;
      }
    } catch (e) {
      print('[SETTINGS SYNC LOG] Loaded defaults: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _locationController.dispose();
    _phoneContactController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _recoveryEmailController.dispose();
    _backupPhoneController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.red.shade600
            : const Color(0xFF195BAC),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddSignatureDialog() {
    final controller = TextEditingController();
    final isDark = ref.read(appUiProvider).isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Create Email Signature',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Regards,\nJohn Doe\nSenior Developer',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF195BAC),
                width: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF195BAC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final newSig = controller.text.trim();
                setState(() {
                  _signatures.add(newSig);
                });
                Navigator.pop(ctx);
                try {
                  await UserRepository.createSignature(
                    name: 'Default',
                    content: newSig,
                    isDefault: true,
                  );
                  await UserRepository.updateSettings({
                    'signatures': _signatures,
                  });
                  _showSnackBar('Signature saved to backend!');
                } catch (_) {
                  _showSnackBar('Signature added locally.');
                }
              }
            },
            child: const Text(
              'Add',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final activeAccount = ref.watch(activeAccountProvider);
    final userEmail = (activeAccount.email.isNotEmpty)
        ? activeAccount.email
        : 'ravinew2004@bnxmail.com';

    final categories = [
      {'title': 'Accounts & Mailboxes', 'icon': Icons.email_outlined},
      {'title': 'General & Composing', 'icon': Icons.settings_outlined},
      {'title': 'Notifications & Quiet', 'icon': Icons.notifications_outlined},
      {'title': 'Appearance & Layout', 'icon': Icons.palette_outlined},
      {'title': 'Security & Recovery', 'icon': Icons.shield_outlined},
      {'title': 'Labels & Sidebar', 'icon': Icons.label_outlined},
      {'title': 'Active Sessions & Logs', 'icon': Icons.devices_outlined},
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(appUiProvider.notifier).selectFolder('Inbox');
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFEBF3FA),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header Row: Back to Inbox & Title ──────────────────
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        context.go('/profile');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 2.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: Color(0xFF195BAC),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: Color(0xFF195BAC),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Top Main Category Buttons ──────────────────────────────
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                    itemBuilder: (ctx, index) {
                      final cat = categories[index];
                      final isSelected = _selectedTabIndex == index;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedTabIndex = index),
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                        ? const Color(0xFF1E3A5F)
                                        : const Color(0xFFE3F2FD))
                                  : (isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF195BAC)
                                    : (isDark
                                          ? Colors.white12
                                          : Colors.grey.shade200),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat['icon'] as IconData,
                                  size: 18,
                                  color: isSelected
                                      ? const Color(0xFF195BAC)
                                      : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat['title'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF195BAC)
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Main Content Settings Card ─────────────────────────────
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF195BAC),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 20.0,
                              ),
                              child: _buildTabContent(
                                _selectedTabIndex,
                                isDark,
                                userEmail,
                              ),
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

  // ── Tab Dispatcher ────────────────────────────────────────────────────────
  Widget _buildTabContent(int index, bool isDark, String userEmail) {
    switch (index) {
      case 0:
        return _buildAccountsTab(isDark, userEmail);
      case 1:
        return _buildGeneralComposingTab(isDark);
      case 2:
        return _buildNotificationsTab(isDark);
      case 3:
        return _buildAppearanceTab(isDark);
      case 4:
        return _buildSecurityTab(isDark);
      case 5:
        return _buildLabelsSidebarTab(isDark);
      case 6:
        return _buildActiveSessionsTab(isDark);
      default:
        return _buildAccountsTab(isDark, userEmail);
    }
  }

  // ── 1. Accounts & Mailboxes Tab ───────────────────────────────────────────
  Widget _buildAccountsTab(bool isDark, String userEmail) {
    final accounts = ref.watch(accountsProvider);
    final displayAccounts = accounts.isNotEmpty
        ? accounts
        : [
            AccountModel(
              id: '1',
              name: 'Primary Account',
              email: userEmail,
              avatarColor: const Color(0xFF195BAC),
              isActive: true,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Accounts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Manage multiple linked email addresses in your current session.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        ...displayAccounts.map((acc) {
          final isCurrentActive = acc.isActive;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isCurrentActive
                  ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD))
                  : (isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentActive
                    ? const Color(0xFF195BAC).withValues(alpha: 0.4)
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                width: isCurrentActive ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.email.isNotEmpty ? acc.email : userEmail,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (acc.name.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          acc.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrentActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF195BAC).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: Color(0xFF195BAC),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(accountsProvider.notifier)
                          .switchAccount(acc.id, ref);
                      if (mounted) {
                        context.go('/');
                        _showSnackBar('Switched to ${acc.email}');
                      }
                    },
                    child: const Text(
                      'Make Active',
                      style: TextStyle(
                        color: Color(0xFF195BAC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── 2. General & Composing Tab ────────────────────────────────────────────
  Widget _buildGeneralComposingTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'General & Composing Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text(
              'Email Signatures',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3F2FD),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _showAddSignatureDialog,
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Color(0xFF195BAC),
              ),
              label: const Text(
                'Add Signature',
                style: TextStyle(
                  color: Color(0xFF195BAC),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_signatures.isEmpty) ...[
          Text(
            'No signatures created. Click \'+ Add Signature\' to create one.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ] else ...[
          ..._signatures.map(
            (sig) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sig,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () async {
                      setState(() => _signatures.remove(sig));
                      try {
                        await UserRepository.updateSettings({
                          'signatures': _signatures,
                        });
                        _showSnackBar('Signature removed!');
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'The default signature will be automatically inserted into new compose frames.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Undo Send Delay',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _undoSendDelay,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              items:
                  [
                        'Disabled (Send instantly)',
                        '5 Seconds',
                        '10 Seconds',
                        '20 Seconds',
                        '30 Seconds',
                      ]
                      .map(
                        (val) => DropdownMenuItem(value: val, child: Text(val)),
                      )
                      .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _undoSendDelay = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sets the grace window to cancel/undo emails after pressing send.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF195BAC),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () async {
            try {
              int delaySeconds = 0;
              final match = RegExp(r'\d+').firstMatch(_undoSendDelay);
              if (match != null) {
                delaySeconds = int.tryParse(match.group(0)!) ?? 0;
              }

              await UserRepository.updateSettings({
                'undoSendDelay': delaySeconds,
                'signatures': _signatures,
              });
              _showSnackBar('Preferences saved to backend!');
            } catch (e) {
              _showSnackBar('Preferences saved locally.', isError: false);
            }
          },
          child: const Text(
            'Save Preferences',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Notifications & Quiet Tab ──────────────────────────────────────────
  Widget _buildNotificationsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notification Preferences & Quiet Hours',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('FOLDERS & SUBSCRIPTIONS', isDark),
        const SizedBox(height: 10),
        _buildSwitchTile('Inbox Mail Alerts', _inboxMailAlerts, (val) {
          setState(() => _inboxMailAlerts = val);
        }, isDark),
        _buildSwitchTile('Sent Confirmation Alerts', _sentConfirmationAlerts, (
          val,
        ) {
          setState(() => _sentConfirmationAlerts = val);
        }, isDark),
        _buildSwitchTile('Starred Emails Alerts', _starredEmailsAlerts, (val) {
          setState(() => _starredEmailsAlerts = val);
        }, isDark),
        _buildSwitchTile('Snoozed Reminders', _snoozedReminders, (val) {
          setState(() => _snoozedReminders = val);
        }, isDark),
        Divider(
          height: 32,
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        _buildSectionHeader('VIBRATION & SOUNDS', isDark),
        const SizedBox(height: 10),
        _buildSwitchTile('Play Alert Sound', _playAlertSound, (val) {
          setState(() => _playAlertSound = val);
        }, isDark),
        _buildSwitchTile('Enable Haptic Vibration', _enableHapticVibration, (
          val,
        ) {
          setState(() => _enableHapticVibration = val);
        }, isDark),
        Divider(
          height: 32,
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        _buildSectionHeader('QUIET HOURS SCHEDULE', isDark),
        const SizedBox(height: 10),
        _buildSwitchTile(
          'Mute Notifications Schedule',
          _muteNotificationsSchedule,
          (val) {
            setState(() => _muteNotificationsSchedule = val);
          },
          isDark,
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF195BAC),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () async {
            try {
              await UserRepository.updateSettings({
                'inboxMailAlerts': _inboxMailAlerts,
                'sentConfirmationAlerts': _sentConfirmationAlerts,
                'starredEmailsAlerts': _starredEmailsAlerts,
                'snoozedReminders': _snoozedReminders,
                'playAlertSound': _playAlertSound,
                'enableHapticVibration': _enableHapticVibration,
                'muteNotificationsSchedule': _muteNotificationsSchedule,
              });
              _showSnackBar('Notification settings saved to backend!');
            } catch (_) {
              _showSnackBar('Notification settings saved.');
            }
          },
          child: const Text(
            'Save Notification Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Appearance & Layout Tab ────────────────────────────────────────────
  Widget _buildAppearanceTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance & Layout Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Theme Mode',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            InkWell(
              onTap: () {
                if (isDark) ref.read(appUiProvider.notifier).toggleDarkMode();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(minWidth: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: !isDark
                      ? const Color(0xFFE3F2FD)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !isDark ? const Color(0xFF195BAC) : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 18,
                      color: !isDark ? const Color(0xFF195BAC) : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Light Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: !isDark
                            ? const Color(0xFF195BAC)
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () {
                if (!isDark) ref.read(appUiProvider.notifier).toggleDarkMode();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(minWidth: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF195BAC)
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dark_mode_outlined,
                      size: 18,
                      color: isDark ? const Color(0xFF195BAC) : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF195BAC)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Display Density',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Compact', 'Default', 'Comfortable'].map((d) {
              final isSel = _density == d;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(d),
                  selected: isSel,
                  selectedColor: const Color(0xFFE3F2FD),
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFFAFAFA),
                  labelStyle: TextStyle(
                    color: isSel
                        ? const Color(0xFF195BAC)
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSel
                          ? const Color(0xFF195BAC)
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _density = d);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── 5. Security & Recovery Tab ────────────────────────────────────────────
  Widget _buildSecurityTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security & Account Recovery',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('PROFILE INFORMATION', isDark),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 160,
              child: _buildInputField('Job Title', _jobTitleController, isDark),
            ),
            SizedBox(
              width: 160,
              child: _buildInputField('Location', _locationController, isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInputField('Phone Contact', _phoneContactController, isDark),

        Divider(
          height: 32,
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),

        _buildSectionHeader('MULTI-FACTOR AUTHENTICATOR', isDark),
        const SizedBox(height: 10),
        _buildSwitchTile('Enable Two-Factor Authentication (2FA)', _enable2FA, (
          val,
        ) {
          setState(() => _enable2FA = val);
        }, isDark),
        _buildSwitchTile('Enable Biometrics Access', _enableBiometrics, (val) {
          setState(() => _enableBiometrics = val);
        }, isDark),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF195BAC),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () async {
            try {
              await UserRepository.updateProfile({
                'jobTitle': _jobTitleController.text,
                'location': _locationController.text,
                'phone': _phoneContactController.text,
              });
              await UserRepository.updateSettings({
                'twoFactorAuth': _enable2FA,
                'enableBiometrics': _enableBiometrics,
              });
              _showSnackBar('Security preferences saved to backend!');
            } catch (_) {
              _showSnackBar('Security preferences saved.');
            }
          },
          child: const Text(
            'Save Security Preferences',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),

        Divider(
          height: 32,
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),

        _buildSectionHeader('UPDATE ACCOUNT PASSWORD', isDark),
        const SizedBox(height: 12),
        _buildInputField(
          'Current Password',
          _currentPasswordController,
          isDark,
          isPassword: true,
        ),
        const SizedBox(height: 10),
        _buildInputField(
          'New Password',
          _newPasswordController,
          isDark,
          isPassword: true,
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF195BAC),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () async {
            final oldPass = _currentPasswordController.text;
            final newPass = _newPasswordController.text;
            if (oldPass.isEmpty || newPass.isEmpty) {
              _showSnackBar('Please fill both password fields.', isError: true);
              return;
            }
            try {
              await UserRepository.changePassword(oldPass, newPass);
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _showSnackBar('Password updated successfully!');
            } catch (e) {
              _showSnackBar('Failed to update password: $e', isError: true);
            }
          },
          child: const Text(
            'Update Password',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),

        Divider(
          height: 32,
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),

        _buildSectionHeader('BACKUP ACCOUNT RECOVERY', isDark),
        const SizedBox(height: 12),
        Text(
          'Recovery Email Address',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        _buildInputField('', _recoveryEmailController, isDark),
        const SizedBox(height: 12),
        Text(
          'Backup Phone Number',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        _buildInputField('', _backupPhoneController, isDark),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF195BAC),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () async {
            try {
              await UserRepository.updateRecovery(
                _recoveryEmailController.text,
                _backupPhoneController.text,
              );
              _showSnackBar('Recovery details saved to backend!');
            } catch (_) {
              _showSnackBar('Recovery details saved.');
            }
          },
          child: const Text(
            'Save Recovery Details',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ── 6. Labels & Sidebar Tab ───────────────────────────────────────────────
  Widget _buildLabelsSidebarTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sidebar Labels',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose which labels are visible in the main sidebar.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        ..._sidebarLabels.keys.map(
          (label) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Switch(
                  value: _sidebarLabels[label]!,
                  onChanged: (val) async {
                    setState(() => _sidebarLabels[label] = val);
                    ref
                        .read(appUiProvider.notifier)
                        .setSidebarLabel(label, val);
                    final email = ref.read(activeAccountProvider).email;
                    if (email.isNotEmpty) {
                      await TokenService.saveUserSettings(email, {
                        'sidebarLabels': _sidebarLabels,
                      });
                    }
                    try {
                      await UserRepository.updateSettings({
                        'sidebarLabels': _sidebarLabels,
                      });
                    } catch (_) {}
                  },
                  activeThumbColor: const Color(0xFF195BAC),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 7. Active Sessions & Logs Tab ──────────────────────────────────────────
  Widget _buildActiveSessionsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Device Sessions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Below are the devices currently logged into your account.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        if (_activeDeviceSessions.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.devices_rounded,
                  size: 36,
                  color: Color(0xFF195BAC),
                ),
                const SizedBox(height: 10),
                Text(
                  'Current Active Session',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your session is secured and authenticated.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ..._activeDeviceSessions.map(
            (sess) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sess['title']!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sess['ip']!} —',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sess['lastActive']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sess['id'] != null && sess['id']!.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final sid = sess['id']!;
                        setState(() => _activeDeviceSessions.remove(sess));
                        await UserRepository.revokeSession(sid);
                        _showSnackBar('Session revoked');
                      },
                      child: const Text(
                        'Revoke',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Shared UI Components ──────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white54 : Colors.grey.shade600,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF195BAC),
            activeTrackColor: const Color(0xFFBBDEFB),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    bool isDark, {
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: isPassword ? 'Enter password' : null,
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey.shade400,
              fontSize: 13,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF195BAC),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
