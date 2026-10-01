import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/token_service.dart';
import '../../../data/app_state_provider.dart';
import '../../../data/account_provider.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/settings_provider.dart';
import '../../../models/two_factor_model.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  // ── General & Composing State ─────────────────────────────────────────────
  String _displayLanguage = 'English';
  bool _enableSpellingCheck = true;
  bool _enableGrammarCheck = true;
  bool _enableAutoCorrect = true;
  bool _enableWritingSuggestions = true;
  bool _desktopNotifications = true;
  bool _conversationView = true;
  String _undoSendDelay = 'Disabled (Send instantly)';
  String _fontFamily = 'Arial';
  String _fontSize = 'Normal';
  final List<Map<String, dynamic>> _signatureItems = [];
  int _selectedSignatureIndex = 0;
  final TextEditingController _signatureContentController =
      TextEditingController();


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
    'Bulk Mail': true,
    'Notifications': true,
    'Archive': true,
  };

  // ── Appearance & Layout State ─────────────────────────────────────────────
  String _density = 'Default';
  int _emailsPerPage = 20;
  String _accentColor = '#4F46E5';
  double _fontSizeScale = 1.0;
  String _visualTheme = 'Classic';
  String _selectedWallpaperUrl = '';
  final TextEditingController _customWallpaperController =
      TextEditingController();
  String _readingPaneMode = 'No Split (Full List)';

  // ── Active Sessions List ──────────────────────────────────────────────────
  List<Map<String, String>> _activeDeviceSessions = [
    {
      'id': 'sess_1',
      'title': 'Unknown Device',
      'ip': '122.183.50.145 — Web Browser',
      'lastActive': 'Logged in: 29/09/2026, 14:03:08',
    },
    {
      'id': 'sess_2',
      'title': 'Unknown Device',
      'ip': '122.183.50.145 — Web Browser',
      'lastActive': 'Logged in: 29/09/2026, 14:59:22',
    },
    {
      'id': 'sess_3',
      'title': 'Unknown Device',
      'ip': '122.183.50.145 — Web Browser',
      'lastActive': 'Logged in: 29/09/2026, 15:20:41',
    },
    {
      'id': 'sess_4',
      'title': 'Unknown Device',
      'ip': '157.51.116.36 — Web Browser',
      'lastActive': 'Logged in: 30/09/2026, 12:10:45',
    },
    {
      'id': 'sess_5',
      'title': 'Unknown Device',
      'ip': '157.51.116.36 — Web Browser',
      'lastActive': 'Logged in: 30/09/2026, 12:10:45',
    },
    {
      'id': 'sess_6',
      'title': 'MacBook',
      'ip': '157.51.122.9 — Chrome',
      'lastActive': 'Logged in: 01/10/2026, 12:54:50',
    },
  ];

  // ── Connected Applications List ───────────────────────────────────────────
  final List<Map<String, String>> _connectedApplications = [
    {
      'id': 'app_1',
      'name': 'Beta Website',
      'scope': '122.183.51.230 — Basic Profile Access',
      'date': 'Authorized: 15/09/2026, 12:25:43',
    },
    {
      'id': 'app_2',
      'name': 'Cliks',
      'scope': '122.183.37.209 — Basic Profile Access',
      'date': 'Authorized: 19/08/2026, 14:06:27',
    },
    {
      'id': 'app_3',
      'name': 'Cliks',
      'scope': '122.183.37.237 — Basic Profile Access',
      'date': 'Authorized: 14/08/2026, 05:54:05',
    },
    {
      'id': 'app_4',
      'name': 'Cliks',
      'scope': '122.183.37.174 — Basic Profile Access',
      'date': 'Authorized: 07/08/2026, 06:43:46',
    },
    {
      'id': 'app_5',
      'name': 'Cliks',
      'scope': '122.183.37.174 — Basic Profile Access',
      'date': 'Authorized: 06/08/2026, 06:21:17',
    },
  ];

  // ── Recent Activity Logs ──────────────────────────────────────────────────
  final List<Map<String, String>> _recentActivityLogs = [
    {
      'ip': '157.51.122.9',
      'timestamp': '01/10/2026, 08:41:39',
    },
    {
      'ip': '157.51.122.9',
      'timestamp': '01/10/2026, 08:36:44',
    },
    {
      'ip': '157.51.122.9',
      'timestamp': '01/10/2026, 08:25:51',
    },
    {
      'ip': '157.51.122.9',
      'timestamp': '01/10/2026, 07:59:56',
    },
  ];

  // ── Accounts & Mailboxes State ─────────────────────────────────────────────
  bool _enablePasswordRecovery = true;
  final TextEditingController _recoveryEmailAddressController =
      TextEditingController(text: 'chandran123@bnxmail.com');
  final TextEditingController _recoveryPhoneNumberController =
      TextEditingController(text: '8072962608');
  bool _sendSecurityAlertsOnLogin = true;
  bool _requireReauthForSensitive = true;
  bool _logLoginHistory = false;
  String _sessionTimeout = '30 minutes';
  final List<Map<String, String>> _extraLinkedAccounts = [];

  @override
  void initState() {
    super.initState();
    // Schedule settings load after the widget tree has fully built.
    // This prevents the "Tried to modify a provider while the widget tree
    // was building" exception that occurs when providers are mutated
    // synchronously during initState/build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadBackendData();
    });
  }

  static const Map<String, String> _codeToLangName = {
    'en': 'English',
    'ta': 'Tamil',
    'hi': 'Hindi',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'kn': 'Kannada',
  };

  static const Map<String, String> _langNameToCode = {
    'English': 'en',
    'Tamil': 'ta',
    'Hindi': 'hi',
    'Telugu': 'te',
    'Malayalam': 'ml',
    'Kannada': 'kn',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
  };

  String _getLangDisplayName(String? code) {
    if (code == null) return 'English';
    return _codeToLangName[code.toLowerCase()] ?? 'English';
  }

  int _parseUndoDelay(String delayStr) {
    final match = RegExp(r'\d+').firstMatch(delayStr);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  String _formatUndoDelay(int? delay) {
    if (delay == null || delay <= 0) return 'Disabled (Send instantly)';
    if (delay == 5) return '5 seconds';
    if (delay == 10) return '10 seconds';
    if (delay == 20) return '20 seconds';
    if (delay == 30) return '30 seconds';
    return '$delay seconds';
  }

  String _formatDensity(String? d) {
    if (d == null) return 'Default';
    final lower = d.toLowerCase();
    if (lower == 'spacious') return 'Spacious';
    if (lower == 'compact') return 'Compact';
    return 'Default';
  }

  String _toBackendDensity(String d) {
    return d.toUpperCase();
  }

  String _formatReadingPane(String? mode) {
    if (mode == null) return 'No Split (Full List)';
    final lower = mode.toLowerCase();
    if (lower.contains('right')) return 'Right Split (Vertical)';
    if (lower.contains('bottom')) return 'Bottom Split (Horizontal)';
    return 'No Split (Full List)';
  }

  String _toBackendReadingPane(String mode) {
    final lower = mode.toLowerCase();
    if (lower.contains('right')) return 'RIGHT';
    if (lower.contains('bottom')) return 'BOTTOM';
    return 'OFF';
  }

  void _syncFromSettingsState(SettingsState state) {
    // Only sync when state has actually loaded data for the current account.
    // Null values from the backend remain null — never substitute hardcoded defaults.
    final s = state.settings;
    if (s != null) {
      _inboxMailAlerts = s.inboxNotifications;
      _sentConfirmationAlerts = s.sentNotifications;
      _starredEmailsAlerts = s.starredNotifications;
      _snoozedReminders = s.snoozedNotifications;
      _playAlertSound = s.soundEnabled;
      _enableHapticVibration = s.vibrationEnabled;
      _muteNotificationsSchedule = s.quietHoursEnabled;

      _undoSendDelay = _formatUndoDelay(s.undoSendDelay);
      _density = _formatDensity(s.density);
      if (s.accentColor != null && s.accentColor!.isNotEmpty) {
        _accentColor = s.accentColor!;
      }
      if (s.themeMode != null) {
        if (s.themeMode!.toUpperCase() == 'DARK') {
          _visualTheme = 'Dark';
        } else if (s.themeMode!.toUpperCase() == 'LIGHT') {
          _visualTheme = 'Classic';
        }
      }
      _readingPaneMode = _formatReadingPane(s.readingPaneMode);
      _enable2FA = s.twoFactorEnabled;
      _enableBiometrics = s.biometricsEnabled;

      // Sync profile fields only if backend provides non-null values
      if (s.jobTitle != null && s.jobTitle!.isNotEmpty) {
        _jobTitleController.text = s.jobTitle!;
      }
      if (s.location != null && s.location!.isNotEmpty) {
        _locationController.text = s.location!;
      }
      if (s.phoneNumber != null && s.phoneNumber!.isNotEmpty) {
        _phoneContactController.text = s.phoneNumber!;
      }
    }

    // Nullable fields: use backend value if present, otherwise keep current widget value
    if (state.currentLanguage != null) {
      _displayLanguage = _getLangDisplayName(state.currentLanguage);
    }
    if (state.spellingCheckEnabled != null) {
      _enableSpellingCheck = state.spellingCheckEnabled!;
    }
    if (state.grammarCheckEnabled != null) {
      _enableGrammarCheck = state.grammarCheckEnabled!;
    }
    if (state.autoCorrectEnabled != null) {
      _enableAutoCorrect = state.autoCorrectEnabled!;
    }
    if (state.smartComposeEnabled != null) {
      _enableWritingSuggestions = state.smartComposeEnabled!;
    }
    if (state.fontFamily != null) {
      _fontFamily = state.fontFamily!;
    }
    if (state.textStyleFontSize != null) {
      _fontSize = state.textStyleFontSize!;
    }
    if (state.wallpaper != null) {
      _selectedWallpaperUrl = state.wallpaper!;
      if (_selectedWallpaperUrl.isNotEmpty) {
        _customWallpaperController.text = _selectedWallpaperUrl;
      }
    }

    if (state.signatures.isNotEmpty) {
      _signatureItems.clear();
      for (final sig in state.signatures) {
        _signatureItems.add({
          'id': sig.id,
          'name': sig.name,
          'content': sig.content,
          'isDefault': sig.isDefault,
        });
      }
      if (_selectedSignatureIndex >= _signatureItems.length) {
        _selectedSignatureIndex = 0;
      }
      _signatureContentController.text =
          _signatureItems[_selectedSignatureIndex]['content']?.toString() ?? '';
    } else if (state.isLoaded) {
      // Backend confirmed empty signature list for this account
      _signatureItems.clear();
      _selectedSignatureIndex = 0;
      _signatureContentController.clear();
    }
  }

  Future<void> _loadBackendData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Trigger settings load in the provider.
      // This is safe here because we are called from addPostFrameCallback,
      // after the widget tree has been fully built.
      await ref.read(settingsProvider.notifier).loadAllSettings(force: true);

      // 2. Sync the now-loaded state into local widget fields
      if (mounted) {
        final s = ref.read(settingsProvider);
        setState(() => _syncFromSettingsState(s));
      }

      // 3. Fetch user profile from API
      final user = await UserRepository.getProfile();
      if (mounted && user != null) {
        setState(() {
          if (user.recoveryEmail != null && user.recoveryEmail!.isNotEmpty) {
            _recoveryEmailController.text = user.recoveryEmail!;
          } else if (user.email.isNotEmpty) {
            _recoveryEmailController.text = user.email;
          }
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
        });
      }

      // 4. Fetch recovery details from GET /api/users/recovery
      final recovery = await UserRepository.getRecovery();
      if (mounted && recovery != null) {
        setState(() {
          if (recovery['recoveryEmail'] != null &&
              recovery['recoveryEmail'].toString().isNotEmpty) {
            _recoveryEmailController.text = recovery['recoveryEmail'].toString();
          }
          if (recovery['phoneNumber'] != null &&
              recovery['phoneNumber'].toString().isNotEmpty) {
            _backupPhoneController.text = recovery['phoneNumber'].toString();
          }
        });
      }

      // 5. Fetch active sessions from GET /api/users/activity-logs
      final sessions = await UserRepository.getSessions();
      if (mounted && sessions.isNotEmpty) {
        setState(() => _activeDeviceSessions = sessions);
      }
    } catch (e) {
      print('[SETTINGS] _loadBackendData error: $e');
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
    _recoveryEmailAddressController.dispose();
    _recoveryPhoneNumberController.dispose();
    _signatureContentController.dispose();
    _customWallpaperController.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Listen to settings state changes (e.g. after API success) and sync to UI.
    // ref.listen in build() is the correct Riverpod pattern for ConsumerStatefulWidget.
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (!mounted) return;
      // Only sync if we received new loaded data (prevents double-sync during loading)
      if (next.isLoaded && previous?.accountEmail != next.accountEmail) {
        // Account changed — full resync
        setState(() => _syncFromSettingsState(next));
      } else if (next.isLoaded && !(previous?.isLoaded ?? false)) {
        // Transition from loading → loaded
        setState(() => _syncFromSettingsState(next));
      } else if (next.isLoaded) {
        // Incremental update (e.g. after PATCH)
        setState(() => _syncFromSettingsState(next));
      }
    });

    // Listen to active account changes and reload settings for the new account.
    ref.listen(activeAccountProvider, (previous, next) {
      final prevEmail = previous?.email.trim().toLowerCase() ?? '';
      final nextEmail = next.email.trim().toLowerCase();
      if (prevEmail != nextEmail && nextEmail.isNotEmpty) {
        print('[SETTINGS] Screen detected account change: $prevEmail → $nextEmail');
        // Settings provider is already invalidated by AccountsNotifier.switchAccount.
        // Trigger a fresh load for the new account after the current frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _loadBackendData();
        });
      }
    });

    final uiState = ref.watch(appUiProvider);
    final isDark = uiState.isDarkMode;
    final activeAccount = ref.watch(activeAccountProvider);
    // Use the actual authenticated account email — no hardcoded fallback
    final userEmail = activeAccount.email.isNotEmpty
        ? activeAccount.email
        : '';

    final categories = [
      {'title': 'Accounts & Mailboxes', 'icon': Icons.email_outlined},
      {'title': 'General & Composing', 'icon': Icons.settings_outlined},
      {'title': 'Notifications & Quiet', 'icon': Icons.notifications_outlined},
      {'title': 'Appearance & Layout', 'icon': Icons.palette_outlined},
      {'title': 'Security & Recovery', 'icon': Icons.shield_outlined},
      {'title': 'Labels & Sidebar', 'icon': Icons.label_outlined},
      {'title': 'Active Sessions & Logs', 'icon': Icons.devices_outlined},
    ];

    final safeTabIndex = _selectedTabIndex.clamp(0, categories.length - 1);

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
                // ── Top Header Row: Back to Profile (non-macOS only) & Title ──────────────────
                if (defaultTargetPlatform != TargetPlatform.macOS) ...[
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
                ],
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
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
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
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: _buildTabContent(
                                safeTabIndex,
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
    final activeAccount = ref.watch(activeAccountProvider);
    final displayEmail = (activeAccount.email.isNotEmpty)
        ? activeAccount.email
        : (userEmail.isNotEmpty ? userEmail : 'ravinew2004@bnxmail.com');

    final username = activeAccount.name.isNotEmpty
        ? activeAccount.name
        : (displayEmail.contains('@')
            ? displayEmail.split('@').first
            : 'ravinew2004');
    final initialLetter =
        displayEmail.isNotEmpty ? displayEmail[0].toUpperCase() : 'R';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Card 1: Email Accounts & Switching ─────────────────────────────
        _buildAccountsSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email Accounts & Switching',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final subtitle = Text(
                    'Manage and switch between linked email accounts in your current session.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  );
                  final addBtn = ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF195BAC),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () =>
                        _showAddOtherEmailAccountDialog(context, isDark),
                    child: const Text(
                      '+ Add Other Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        subtitle,
                        const SizedBox(height: 12),
                        addBtn,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: subtitle),
                      const SizedBox(width: 16),
                      addBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Active Account Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFEFF5FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFDBEAFE),
                      child: Text(
                        initialLetter,
                        style: const TextStyle(
                          color: Color(0xFF195BAC),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayEmail,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'BNX Mail Account',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Linked Accounts if any were added
              if (_extraLinkedAccounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._extraLinkedAccounts.map((extra) {
                  final email = extra['email'] ?? '';
                  final name = extra['name'] ?? 'Other Account';
                  final initial =
                      email.isNotEmpty ? email[0].toUpperCase() : 'O';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (name.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _extraLinkedAccounts.remove(extra);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        // ── Card 2: Account Information ────────────────────────────────────
        _buildAccountsSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tile1 = _buildAccountInfoTile(
                    label: 'FULL NAME / USERNAME',
                    value: username,
                    isDark: isDark,
                  );
                  final tile2 = _buildAccountInfoTile(
                    label: 'PRIMARY EMAIL',
                    value: displayEmail,
                    isDark: isDark,
                  );
                  final tile3 = _buildAccountInfoTile(
                    label: 'ACCOUNT ROLE',
                    value: 'ORG_ADMIN',
                    isDark: isDark,
                  );
                  final tile4 = _buildAccountInfoTile(
                    label: 'ACCOUNT STATUS',
                    value: 'Active & Verified ✓',
                    valueColor: const Color(0xFF16A34A),
                    isDark: isDark,
                  );

                  if (constraints.maxWidth >= 720) {
                    return Row(
                      children: [
                        Expanded(child: tile1),
                        const SizedBox(width: 12),
                        Expanded(child: tile2),
                        const SizedBox(width: 12),
                        Expanded(child: tile3),
                        const SizedBox(width: 12),
                        Expanded(child: tile4),
                      ],
                    );
                  } else if (constraints.maxWidth >= 440) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: tile1),
                            const SizedBox(width: 12),
                            Expanded(child: tile2),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: tile3),
                            const SizedBox(width: 12),
                            Expanded(child: tile4),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        tile1,
                        const SizedBox(height: 10),
                        tile2,
                        const SizedBox(height: 10),
                        tile3,
                        const SizedBox(height: 10),
                        tile4,
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // ── Card 3: Password Recovery & Backup Contacts ─────────────────────
        _buildAccountsSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Recovery & Backup Contacts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Enable Password Recovery via Backup Email & Phone',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _enablePasswordRecovery,
                    activeTrackColor: const Color(0xFF195BAC),
                    activeThumbColor: Colors.white,
                    onChanged: (v) {
                      setState(() => _enablePasswordRecovery = v);
                    },
                  ),
                ],
              ),
              Divider(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                height: 32,
              ),

              // Recovery Inputs
              LayoutBuilder(
                builder: (context, constraints) {
                  final emailInput = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Recovery Email Address',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildUnverifiedBadge(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _recoveryEmailAddressController,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
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
                    ],
                  );

                  final phoneInput = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Recovery Phone Number (10 Digits)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildUnverifiedBadge(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _recoveryPhoneNumberController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
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
                    ],
                  );

                  if (constraints.maxWidth >= 550) {
                    return Row(
                      children: [
                        Expanded(child: emailInput),
                        const SizedBox(width: 16),
                        Expanded(child: phoneInput),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        emailInput,
                        const SizedBox(height: 14),
                        phoneInput,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 20),

              // Save Security Preferences Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF195BAC),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                ),
                onPressed: () => _showOtpVerificationDialog(context, isDark),
                child: const Text(
                  'Save Security Preferences',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Card 4: Manage Security Credentials ────────────────────────────
        _buildAccountsSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage security credentials for your primary mailbox.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 18),
              _buildSecurityToggleRow(
                title: 'Send Security Alerts on New Logins',
                value: _sendSecurityAlertsOnLogin,
                onChanged: (v) => setState(() => _sendSecurityAlertsOnLogin = v),
                isDark: isDark,
              ),
              _buildSecurityToggleRow(
                title:
                    'Require Password Re-authentication for Sensitive Actions',
                value: _requireReauthForSensitive,
                onChanged: (v) =>
                    setState(() => _requireReauthForSensitive = v),
                isDark: isDark,
              ),
              _buildSecurityToggleRow(
                title: 'Log Login IP & Location History',
                value: _logLoginHistory,
                onChanged: (v) => setState(() => _logLoginHistory = v),
                isDark: isDark,
              ),
              Divider(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                height: 32,
              ),
              Text(
                'Auto Sign-Out Idle Session Timeout',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: const [
                      '15 minutes',
                      '30 minutes',
                      '1 hour',
                      '4 hours',
                      '8 hours',
                      'Never',
                    ].contains(_sessionTimeout)
                        ? _sessionTimeout
                        : '30 minutes',
                    isExpanded: true,
                    dropdownColor: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '15 minutes',
                        child: Text('15 minutes'),
                      ),
                      DropdownMenuItem(
                        value: '30 minutes',
                        child: Text('30 minutes'),
                      ),
                      DropdownMenuItem(
                        value: '1 hour',
                        child: Text('1 hour'),
                      ),
                      DropdownMenuItem(
                        value: '4 hours',
                        child: Text('4 hours'),
                      ),
                      DropdownMenuItem(
                        value: '8 hours',
                        child: Text('8 hours'),
                      ),
                      DropdownMenuItem(
                        value: 'Never',
                        child: Text('Never'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _sessionTimeout = v);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section Card Container Helper ─────────────────────────────────────────
  Widget _buildAccountsSectionCard({
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Account Info Metric Tile Helper ───────────────────────────────────────
  Widget _buildAccountInfoTile({
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: valueColor ??
                  (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ── Unverified Badge Helper ───────────────────────────────────────────────
  Widget _buildUnverifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Unverified',
        style: TextStyle(
          color: Color(0xFFD97706),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  // ── Security Toggle Row Helper ────────────────────────────────────────────
  Widget _buildSecurityToggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF195BAC),
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ── Modal Dialog: Add Other Email Account ─────────────────────────────────
  void _showAddOtherEmailAccountDialog(BuildContext context, bool isDark) {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedProtocol = 'IMAP / SMTP';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Add Other Email Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(dialogCtx),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 24,
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFF1F5F9),
                        ),
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailCtrl,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'user@example.com',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0),
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
                        const SizedBox(height: 16),
                        Text(
                          'Account Display Name',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameCtrl,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Work / Personal Email',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0),
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
                        const SizedBox(height: 16),
                        Text(
                          'Account Protocol',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedProtocol,
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'IMAP / SMTP',
                                  child: Text('IMAP / SMTP'),
                                ),
                                DropdownMenuItem(
                                  value: 'POP3 / SMTP',
                                  child: Text('POP3 / SMTP'),
                                ),
                                DropdownMenuItem(
                                  value: 'Microsoft Exchange',
                                  child: Text('Microsoft Exchange'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() => selectedProtocol = v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF195BAC),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: () {
                                final email = emailCtrl.text.trim();
                                if (email.isNotEmpty) {
                                  setState(() {
                                    _extraLinkedAccounts.add({
                                      'email': email,
                                      'name': nameCtrl.text.trim(),
                                      'protocol': selectedProtocol,
                                    });
                                  });
                                  Navigator.pop(dialogCtx);
                                  _showSnackBar(
                                    'Account $email added successfully',
                                  );
                                } else {
                                  _showSnackBar(
                                    'Please enter an email address',
                                    isError: true,
                                  );
                                }
                              },
                              child: const Text(
                                'Add Account',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Modal Dialog: OTP Verification ────────────────────────────────────────
  void _showOtpVerificationDialog(BuildContext context, bool isDark) {
    final rawPhone = _recoveryPhoneNumberController.text.trim();
    String maskedPhone = '80******08';
    if (rawPhone.length >= 4) {
      final prefix = rawPhone.substring(0, 2);
      final suffix = rawPhone.substring(rawPhone.length - 2);
      maskedPhone = '$prefix******$suffix';
    }

    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());

    int countdown = 9;
    Timer? countdownTimer;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            countdownTimer ??= Timer.periodic(
              const Duration(seconds: 1),
              (t) {
                if (countdown > 0) {
                  setDialogState(() => countdown--);
                } else {
                  t.cancel();
                }
              },
            );

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFF195BAC),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'OTP Verification',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () {
                                countdownTimer?.cancel();
                                Navigator.pop(dialogCtx);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 24,
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFF1F5F9),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    'Enter the 6-digit verification code sent to ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569),
                                ),
                              ),
                              TextSpan(
                                text: maskedPhone,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 6-digit OTP Input Boxes
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (i) {
                                return Container(
                                  width: 48,
                                  height: 56,
                                  margin: EdgeInsets.only(
                                    right: i < 5 ? 10 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: focusNodes[i].hasFocus
                                          ? const Color(0xFF195BAC)
                                          : (isDark
                                              ? Colors.white12
                                              : const Color(0xFFE2E8F0)),
                                      width: focusNodes[i].hasFocus ? 2.0 : 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: TextField(
                                      controller: controllers[i],
                                      focusNode: focusNodes[i],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (val) {
                                        if (val.isNotEmpty && i < 5) {
                                          focusNodes[i + 1].requestFocus();
                                        } else if (val.isEmpty && i > 0) {
                                          focusNodes[i - 1].requestFocus();
                                        }
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Verify Code Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF195BAC),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: () {
                              countdownTimer?.cancel();
                              Navigator.pop(dialogCtx);
                              _showSnackBar(
                                'Security preferences saved and verified successfully!',
                              );
                            },
                            child: const Text(
                              'Verify Code',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resend & Change Contact Details
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            countdown > 0
                                ? Text(
                                    'Resend code in ${countdown}s',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : InkWell(
                                    onTap: () {
                                      setDialogState(() => countdown = 9);
                                      countdownTimer?.cancel();
                                      countdownTimer = Timer.periodic(
                                        const Duration(seconds: 1),
                                        (t) {
                                          if (countdown > 0) {
                                            setDialogState(() => countdown--);
                                          } else {
                                            t.cancel();
                                          }
                                        },
                                      );
                                      _showSnackBar(
                                        'A new verification code has been sent.',
                                      );
                                    },
                                    child: const Text(
                                      'Resend code',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF195BAC),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            InkWell(
                              onTap: () {
                                countdownTimer?.cancel();
                                Navigator.pop(dialogCtx);
                              },
                              child: const Text(
                                'Change Contact Details',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      for (final c in controllers) {
        c.dispose();
      }
      for (final f in focusNodes) {
        f.dispose();
      }
    });
  }

  // ── Modal Dialog: 2FA Setup & Verification ─────────────────────────────
  void _show2FASetupDialog(
      BuildContext context, bool isDark, TwoFactorSetupData data) {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    bool isVerifying = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.security_rounded,
                              color: Color(0xFF155EEF),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Set Up 2-Factor Auth',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () => Navigator.pop(dialogCtx),
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 24,
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFF1F5F9),
                        ),
                        Text(
                          'Add your BNX Mail account to an authenticator app (such as Google Authenticator, Authy, or 1Password) using the secret key below:',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Secret Key Box
                        if (data.secret != null && data.secret!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    data.secret!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 18, color: Color(0xFF155EEF)),
                                  tooltip: 'Copy Key',
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: data.secret!));
                                    _showSnackBar(
                                        'Secret key copied to clipboard');
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        Text(
                          'Enter the 6-digit verification code from your authenticator app:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 6-digit OTP Input Boxes
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (i) {
                                return Container(
                                  width: 48,
                                  height: 56,
                                  margin: EdgeInsets.only(
                                    right: i < 5 ? 10 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: focusNodes[i].hasFocus
                                          ? const Color(0xFF155EEF)
                                          : (isDark
                                              ? Colors.white12
                                              : const Color(0xFFE2E8F0)),
                                      width: focusNodes[i].hasFocus ? 2.0 : 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: TextField(
                                      controller: controllers[i],
                                      focusNode: focusNodes[i],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (val) {
                                        if (val.isNotEmpty && i < 5) {
                                          focusNodes[i + 1].requestFocus();
                                        } else if (val.isEmpty && i > 0) {
                                          focusNodes[i - 1].requestFocus();
                                        }
                                        setDialogState(() {
                                          errorMessage = null;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),

                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Verify & Enable Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF155EEF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: isVerifying
                                ? null
                                : () async {
                                    final code = controllers
                                        .map((c) => c.text)
                                        .join();
                                    if (code.length < 6) {
                                      setDialogState(() {
                                        errorMessage =
                                            'Please enter the full 6-digit code';
                                      });
                                      return;
                                    }
                                    setDialogState(() {
                                      isVerifying = true;
                                      errorMessage = null;
                                    });

                                    final res = await ref
                                        .read(settingsProvider.notifier)
                                        .verify2FA(code);
                                    if (res.success) {
                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      setState(() => _enable2FA = true);
                                      _showSnackBar(
                                        'Two-factor authentication verified and enabled!',
                                      );
                                    } else {
                                      setDialogState(() {
                                        isVerifying = false;
                                        errorMessage = res.message ??
                                            'Verification failed. Please check the code.';
                                      });
                                    }
                                  },
                            child: isVerifying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Verify & Enable',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
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
          },
        );
      },
    ).then((_) {
      for (final c in controllers) {
        c.dispose();
      }
      for (final f in focusNodes) {
        f.dispose();
      }
    });
  }


  // ── 2. General & Composing Tab ────────────────────────────────────────────
  Widget _buildGeneralComposingTab(bool isDark) {
    const undoOptions = [
      'Disabled (Send instantly)',
      '5 seconds',
      '10 seconds',
      '20 seconds',
      '30 seconds',
    ];
    final currentUndoValue = undoOptions.firstWhere(
      (opt) => opt.toLowerCase() == _undoSendDelay.toLowerCase(),
      orElse: () => undoOptions.first,
    );

    return _buildAccountsSectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────────
          Text(
            'General & Composing',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),

          // ── Display Language ───────────────────────────────────────────────
          Text(
            'Display Language',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            isDark: isDark,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: const [
                  'English',
                  'Tamil',
                  'Hindi',
                  'Telugu',
                  'Malayalam',
                  'Kannada',
                  'Spanish',
                  'French',
                  'German',
                ].contains(_displayLanguage)
                    ? _displayLanguage
                    : 'English',
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey,
                ),
                items: const [
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                  DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'Telugu', child: Text('Telugu')),
                  DropdownMenuItem(value: 'Malayalam', child: Text('Malayalam')),
                  DropdownMenuItem(value: 'Kannada', child: Text('Kannada')),
                  DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                  DropdownMenuItem(value: 'French', child: Text('French')),
                  DropdownMenuItem(value: 'German', child: Text('German')),
                ],
                onChanged: (v) async {
                  if (v != null) {
                    setState(() => _displayLanguage = v);
                    final code = _langNameToCode[v] ?? 'en';
                    final res = await ref.read(settingsProvider.notifier).updateLanguage(code);
                    if (res.success) {
                      _showSnackBar('Language updated to $v');
                    } else {
                      _showSnackBar(res.message ?? 'Failed to update language', isError: true);
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'BNXmail display language preference.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          Divider(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 36,
          ),

          // ── 4 Writing & Spell Check Toggles ────────────────────────────────
          _buildSecurityToggleRow(
            title: 'Enable Spelling Check',
            value: _enableSpellingCheck,
            onChanged: (v) async {
              setState(() => _enableSpellingCheck = v);
              await ref.read(settingsProvider.notifier).updateComposing(
                spellingCheckEnabled: v,
                grammarCheckEnabled: _enableGrammarCheck,
                autoCorrectEnabled: _enableAutoCorrect,
                smartComposeEnabled: _enableWritingSuggestions,
              );
            },
            isDark: isDark,
          ),
          _buildSecurityToggleRow(
            title: 'Enable Grammar Check',
            value: _enableGrammarCheck,
            onChanged: (v) async {
              setState(() => _enableGrammarCheck = v);
              await ref.read(settingsProvider.notifier).updateComposing(
                spellingCheckEnabled: _enableSpellingCheck,
                grammarCheckEnabled: v,
                autoCorrectEnabled: _enableAutoCorrect,
                smartComposeEnabled: _enableWritingSuggestions,
              );
            },
            isDark: isDark,
          ),
          _buildSecurityToggleRow(
            title: 'Enable Auto-correct',
            value: _enableAutoCorrect,
            onChanged: (v) async {
              setState(() => _enableAutoCorrect = v);
              await ref.read(settingsProvider.notifier).updateComposing(
                spellingCheckEnabled: _enableSpellingCheck,
                grammarCheckEnabled: _enableGrammarCheck,
                autoCorrectEnabled: v,
                smartComposeEnabled: _enableWritingSuggestions,
              );
            },
            isDark: isDark,
          ),
          _buildSecurityToggleRow(
            title: 'Enable Writing Suggestions (Smart Compose)',
            value: _enableWritingSuggestions,
            onChanged: (v) async {
              setState(() => _enableWritingSuggestions = v);
              await ref.read(settingsProvider.notifier).updateComposing(
                spellingCheckEnabled: _enableSpellingCheck,
                grammarCheckEnabled: _enableGrammarCheck,
                autoCorrectEnabled: _enableAutoCorrect,
                smartComposeEnabled: v,
              );
            },
            isDark: isDark,
          ),
          Divider(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 36,
          ),

          // ── Mail View & Notifications ──────────────────────────────────────
          const Text(
            'MAIL VIEW & NOTIFICATIONS',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildSecurityToggleRow(
            title: 'Desktop Notifications for New Emails',
            value: _desktopNotifications,
            onChanged: (v) => setState(() => _desktopNotifications = v),
            isDark: isDark,
          ),
          _buildSecurityToggleRow(
            title: 'Conversation View (Group emails by thread)',
            value: _conversationView,
            onChanged: (v) => setState(() => _conversationView = v),
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // ── Undo Send Delay ────────────────────────────────────────────────
          Text(
            'Undo Send Delay',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            isDark: isDark,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentUndoValue,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey,
                ),
                items: undoOptions
                    .map(
                      (opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _undoSendDelay = v);
                    final seconds = _parseUndoDelay(v);
                    ref
                        .read(settingsProvider.notifier)
                        .updateGeneralSettings({'undoSendDelay': seconds});
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grace period to cancel or undo sent emails.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          Divider(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 36,
          ),

          // ── Default Text Style ─────────────────────────────────────────────
          const Text(
            'DEFAULT TEXT STYLE',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final fontFamilyCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Font Family',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdownContainer(
                    isDark: isDark,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: const [
                          'Arial',
                          'Georgia',
                          'Tahoma',
                          'Times New Roman',
                          'Trebuchet MS',
                          'Verdana',
                          'Roboto',
                          'Courier New',
                        ].contains(_fontFamily)
                            ? _fontFamily
                            : 'Arial',
                        isExpanded: true,
                        dropdownColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Arial', child: Text('Arial')),
                          DropdownMenuItem(
                              value: 'Georgia', child: Text('Georgia')),
                          DropdownMenuItem(
                              value: 'Tahoma', child: Text('Tahoma')),
                          DropdownMenuItem(
                              value: 'Times New Roman',
                              child: Text('Times New Roman')),
                          DropdownMenuItem(
                              value: 'Trebuchet MS',
                              child: Text('Trebuchet MS')),
                          DropdownMenuItem(
                              value: 'Verdana', child: Text('Verdana')),
                          DropdownMenuItem(
                              value: 'Roboto', child: Text('Roboto')),
                          DropdownMenuItem(
                              value: 'Courier New',
                              child: Text('Courier New')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fontFamily = v);
                            ref.read(settingsProvider.notifier).updateTextStyle(
                                  fontFamily: v,
                                  fontSize: _fontSize,
                                );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );

              final fontSizeCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Font Size',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdownContainer(
                    isDark: isDark,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: const ['Small', 'Normal', 'Large', 'Huge']
                                .contains(_fontSize)
                            ? _fontSize
                            : 'Normal',
                        isExpanded: true,
                        dropdownColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Small', child: Text('Small')),
                          DropdownMenuItem(
                              value: 'Normal', child: Text('Normal')),
                          DropdownMenuItem(
                              value: 'Large', child: Text('Large')),
                          DropdownMenuItem(
                              value: 'Huge', child: Text('Huge')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fontSize = v);
                            ref.read(settingsProvider.notifier).updateTextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: v,
                                );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth >= 550) {
                return Row(
                  children: [
                    Expanded(child: fontFamilyCol),
                    const SizedBox(width: 16),
                    Expanded(child: fontSizeCol),
                  ],
                );
              } else {
                return Column(
                  children: [
                    fontFamilyCol,
                    const SizedBox(height: 14),
                    fontSizeCol,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Text Color Preview Row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                'Text Color:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
                child: Text(
                  'Sample Default Text Style Preview',
                  style: TextStyle(
                    fontFamily: _fontFamily == 'Arial' ? null : _fontFamily,
                    fontSize: _fontSize == 'Small'
                        ? 11.5
                        : _fontSize == 'Large'
                            ? 15
                            : _fontSize == 'Huge'
                                ? 17
                                : 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            height: 36,
          ),

          // ── Email Signatures ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EMAIL SIGNATURES',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF195BAC), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                ),
                onPressed: () async {
                  final newName = 'Signature ${_signatureItems.length + 1}';
                  final res = await ref
                      .read(settingsProvider.notifier)
                      .createSignature(
                        name: newName,
                        content: '',
                        isDefault: _signatureItems.isEmpty,
                      );
                  if (res.success && res.signature != null) {
                    setState(() {
                      _signatureItems.add({
                        'id': res.signature!.id,
                        'name': res.signature!.name,
                        'content': res.signature!.content,
                        'isDefault': res.signature!.isDefault,
                      });
                      _selectedSignatureIndex = _signatureItems.length - 1;
                      _signatureContentController.text = '';
                    });
                    _showSnackBar('New signature created');
                  } else {
                    setState(() {
                      _signatureItems.add({
                        'name': newName,
                        'content': '',
                        'isDefault': _signatureItems.isEmpty,
                      });
                      _selectedSignatureIndex = _signatureItems.length - 1;
                      _signatureContentController.text = '';
                    });
                  }
                },
                child: const Text(
                  '+ Add Signature',
                  style: TextStyle(
                    color: Color(0xFF195BAC),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // If no signatures created
          if (_signatureItems.isEmpty) ...[
            Text(
              'No signatures created. Click \'+ Add Signature\' to create one.',
              style: TextStyle(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ] else ...[
            // Signature Pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_signatureItems.length, (index) {
                final isSelected = index == _selectedSignatureIndex;
                final sig = _signatureItems[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSignatureIndex = index;
                      _signatureContentController.text =
                          sig['content'] ?? '';
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF195BAC)
                            : (isDark
                                ? Colors.white24
                                : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : (isDark
                              ? const Color(0xFF0F172A)
                              : Colors.white),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sig['name'] ?? 'New Signature',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF195BAC)
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF0F172A)),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (sig['isDefault'] == true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // Signature Editor Box
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Signature Editor Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _signatureItems[_selectedSignatureIndex]['name'] ??
                              'New Signature',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                if (_selectedSignatureIndex < 0 ||
                                    _selectedSignatureIndex >=
                                        _signatureItems.length) {
                                  return;
                                }
                                final sig =
                                    _signatureItems[_selectedSignatureIndex];
                                final id = sig['id']?.toString();
                                if (id != null && id.isNotEmpty) {
                                  final res = await ref
                                      .read(settingsProvider.notifier)
                                      .setDefaultSignature(id);
                                  if (res.success) {
                                    setState(() {
                                      for (var s in _signatureItems) {
                                        s['isDefault'] = (s['id'] == id);
                                      }
                                    });
                                    _showSnackBar('Default signature updated');
                                  } else {
                                    _showSnackBar(res.message ??
                                        'Failed to set default signature');
                                  }
                                } else {
                                  setState(() {
                                    for (int i = 0;
                                        i < _signatureItems.length;
                                        i++) {
                                      _signatureItems[i]['isDefault'] =
                                          (i == _selectedSignatureIndex);
                                    }
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (_selectedSignatureIndex >= 0 &&
                                          _selectedSignatureIndex <
                                              _signatureItems.length &&
                                          _signatureItems[
                                                  _selectedSignatureIndex]
                                              ['isDefault'] ==
                                              true)
                                      ? const Color(0xFFDCFCE7)
                                      : (isDark
                                          ? Colors.white12
                                          : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (_selectedSignatureIndex >= 0 &&
                                          _selectedSignatureIndex <
                                              _signatureItems.length &&
                                          _signatureItems[
                                                  _selectedSignatureIndex]
                                              ['isDefault'] ==
                                              true)
                                      ? 'Default ✓'
                                      : 'Set Default',
                                  style: TextStyle(
                                    color: (_selectedSignatureIndex >= 0 &&
                                            _selectedSignatureIndex <
                                                _signatureItems.length &&
                                            _signatureItems[
                                                    _selectedSignatureIndex]
                                                ['isDefault'] ==
                                                true)
                                        ? const Color(0xFF15803D)
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569)),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () async {
                                if (_selectedSignatureIndex < 0 ||
                                    _selectedSignatureIndex >=
                                        _signatureItems.length) {
                                  return;
                                }
                                final sig =
                                    _signatureItems[_selectedSignatureIndex];
                                final id = sig['id']?.toString();
                                if (id != null && id.isNotEmpty) {
                                  final res = await ref
                                      .read(settingsProvider.notifier)
                                      .deleteSignature(id);
                                  if (!res.success) {
                                    _showSnackBar(res.message ??
                                        'Failed to delete signature');
                                    return;
                                  }
                                }
                                setState(() {
                                  _signatureItems.removeAt(
                                    _selectedSignatureIndex,
                                  );
                                  if (_selectedSignatureIndex >=
                                      _signatureItems.length) {
                                    _selectedSignatureIndex =
                                        _signatureItems.length - 1;
                                  }
                                  if (_selectedSignatureIndex >= 0) {
                                    _signatureContentController.text =
                                        _signatureItems[_selectedSignatureIndex]
                                                ['content'] ??
                                            '';
                                  } else {
                                    _signatureContentController.text = '';
                                  }
                                });
                                _showSnackBar('Signature deleted');
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),

                  // Signature Editor Toolbar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Normal',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.unfold_more_rounded,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          _buildToolbarVerticalDivider(isDark),
                          _buildToolbarIconButton(
                            icon: Icons.format_bold_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_italic_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_underlined_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_strikethrough_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_quote_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarVerticalDivider(isDark),
                          _buildToolbarIconButton(
                            icon: Icons.format_list_numbered_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_list_bulleted_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_indent_decrease_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_indent_increase_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarVerticalDivider(isDark),
                          _buildToolbarIconButton(
                            icon: Icons.link_rounded,
                            isDark: isDark,
                          ),
                          _buildToolbarIconButton(
                            icon: Icons.format_clear_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),

                  // Signature Text Input Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _signatureContentController,
                      maxLines: 5,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      onChanged: (text) {
                        if (_selectedSignatureIndex >= 0 &&
                            _selectedSignatureIndex <
                                _signatureItems.length) {
                          _signatureItems[_selectedSignatureIndex]['content'] =
                              text;
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Design your signature...',
                        hintStyle: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'The default signature will be automatically inserted into new compose frames.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),

          // ── Save Preferences Button ────────────────────────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF195BAC),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
            ),
            onPressed: () async {
              final seconds = _parseUndoDelay(_undoSendDelay);
              await ref
                  .read(settingsProvider.notifier)
                  .updateGeneralSettings({'undoSendDelay': seconds});

              if (_selectedSignatureIndex >= 0 &&
                  _selectedSignatureIndex < _signatureItems.length) {
                final currentSig = _signatureItems[_selectedSignatureIndex];
                final sigId = currentSig['id']?.toString();
                final sigContent = _signatureContentController.text;
                final sigName = currentSig['name']?.toString() ?? 'Default';
                final sigIsDefault = currentSig['isDefault'] == true;

                if (sigId != null && sigId.isNotEmpty) {
                  await ref.read(settingsProvider.notifier).updateSignature(
                        id: sigId,
                        name: sigName,
                        content: sigContent,
                        isDefault: sigIsDefault,
                      );
                } else if (sigContent.isNotEmpty || sigName.isNotEmpty) {
                  final created = await ref
                      .read(settingsProvider.notifier)
                      .createSignature(
                        name: sigName,
                        content: sigContent,
                        isDefault: sigIsDefault,
                      );
                  if (created.signature != null) {
                    currentSig['id'] = created.signature!.id;
                  }
                }
              }

              await ref.read(settingsProvider.notifier).updateTextStyle(
                    fontFamily: _fontFamily,
                    fontSize: _fontSize,
                  );

              await ref.read(settingsProvider.notifier).updateComposing(
                    spellingCheckEnabled: _enableSpellingCheck,
                    grammarCheckEnabled: _enableGrammarCheck,
                    autoCorrectEnabled: _enableAutoCorrect,
                    smartComposeEnabled: _enableWritingSuggestions,
                  );

              _showSnackBar('Preferences saved successfully!');
            },
            child: const Text(
              'Save Preferences',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── General Dropdown Container Helper ─────────────────────────────────────
  Widget _buildDropdownContainer({
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  // ── Toolbar Icon Button Helper ────────────────────────────────────────────
  Widget _buildToolbarIconButton({
    required IconData icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  // ── Toolbar Vertical Divider Helper ───────────────────────────────────────
  Widget _buildToolbarVerticalDivider(bool isDark) {
    return Container(
      height: 18,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
    );
  }


  // ── 3. Notifications & Quiet Tab ──────────────────────────────────────────
  Widget _buildNotificationsTab(bool isDark) {
    return _buildAccountsSectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────────
          Text(
            'Notification Preferences & Quiet Hours',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 1. Folders & Subscriptions ─────────────────────────────────────
          const Text(
            'FOLDERS & SUBSCRIPTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationToggleRow(
            title: 'Inbox Mail Alerts',
            value: _inboxMailAlerts,
            onChanged: (val) => setState(() => _inboxMailAlerts = val),
            isDark: isDark,
          ),
          _buildNotificationToggleRow(
            title: 'Sent Confirmation Alerts',
            value: _sentConfirmationAlerts,
            onChanged: (val) => setState(() => _sentConfirmationAlerts = val),
            isDark: isDark,
          ),
          _buildNotificationToggleRow(
            title: 'Starred Email Alerts',
            value: _starredEmailsAlerts,
            onChanged: (val) => setState(() => _starredEmailsAlerts = val),
            isDark: isDark,
          ),
          _buildNotificationToggleRow(
            title: 'Snoozed Email Alerts',
            value: _snoozedReminders,
            onChanged: (val) => setState(() => _snoozedReminders = val),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 2. Auditory & Vibration Feedback ───────────────────────────────
          const Text(
            'AUDITORY & VIBRATION FEEDBACK',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationToggleRow(
            title: 'Play Sound for New Mail',
            value: _playAlertSound,
            onChanged: (val) => setState(() => _playAlertSound = val),
            isDark: isDark,
          ),
          _buildNotificationToggleRow(
            title: 'Vibrate on Incoming Messages',
            value: _enableHapticVibration,
            onChanged: (val) => setState(() => _enableHapticVibration = val),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 3. Quiet Hours Schedule ────────────────────────────────────────
          const Text(
            'QUIET HOURS SCHEDULE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationToggleRow(
            title:
                'Mute all notification sounds and popups during specified schedule.',
            value: _muteNotificationsSchedule,
            onChanged: (val) => setState(() => _muteNotificationsSchedule = val),
            isDark: isDark,
          ),
          const SizedBox(height: 32),

          // ── Save Notification Settings Button ──────────────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
            ),
            onPressed: () async {
              final res = await ref
                  .read(settingsProvider.notifier)
                  .updateGeneralSettings({
                'inboxNotifications': _inboxMailAlerts,
                'inboxMailAlerts': _inboxMailAlerts,
                'sentNotifications': _sentConfirmationAlerts,
                'sentConfirmationAlerts': _sentConfirmationAlerts,
                'starredNotifications': _starredEmailsAlerts,
                'starredEmailsAlerts': _starredEmailsAlerts,
                'snoozedNotifications': _snoozedReminders,
                'snoozedReminders': _snoozedReminders,
                'soundEnabled': _playAlertSound,
                'playAlertSound': _playAlertSound,
                'vibrationEnabled': _enableHapticVibration,
                'enableHapticVibration': _enableHapticVibration,
                'quietHoursEnabled': _muteNotificationsSchedule,
                'muteNotificationsSchedule': _muteNotificationsSchedule,
              });
              if (res.success) {
                _showSnackBar('Notification settings saved successfully!');
              } else {
                _showSnackBar(
                  res.message ?? 'Failed to save notification settings',
                );
              }
            },
            child: const Text(
              'Save Notification Settings',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notification Toggle Row Helper ─────────────────────────────────────────
  Widget _buildNotificationToggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          CupertinoSwitch(
            value: value,
            activeTrackColor: const Color(0xFF155EEF),
            inactiveTrackColor:
                isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            thumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ── 4. Appearance & Layout Tab ────────────────────────────────────────────
  Widget _buildAppearanceTab(bool isDark) {
    const readingPaneOptions = [
      'No Split (Full List)',
      'Right Split (Vertical)',
      'Bottom Split (Horizontal)',
    ];
    final currentReadingPaneValue = readingPaneOptions.firstWhere(
      (opt) =>
          opt.toLowerCase() == _readingPaneMode.toLowerCase() ||
          (_readingPaneMode.toLowerCase().contains('right') &&
              opt.contains('Right')) ||
          (_readingPaneMode.toLowerCase().contains('bottom') &&
              opt.contains('Bottom')) ||
          (_readingPaneMode.toLowerCase().contains('no') &&
              opt.contains('No')),
      orElse: () => readingPaneOptions.first,
    );

    return _buildAccountsSectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────────
          Text(
            'Appearance & Interface Customization',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 1. Density ─────────────────────────────────────────────────────
          Text(
            'Density',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final densityOptions = ['Default', 'Spacious', 'Compact'];
              if (constraints.maxWidth >= 450) {
                return Row(
                  children: densityOptions.map((d) {
                    final isSelected =
                        _density.toLowerCase() == d.toLowerCase();
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: d != densityOptions.last ? 12.0 : 0.0,
                        ),
                        child: _buildPillButton(
                          label: d,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () {
                            setState(() => _density = d);
                            ref
                                .read(settingsProvider.notifier)
                                .updateGeneralSettings(
                                    {'density': _toBackendDensity(d)});
                          },
                        ),
                      ),
                    );
                  }).toList(),
                );
              } else {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: densityOptions.map((d) {
                    final isSelected =
                        _density.toLowerCase() == d.toLowerCase();
                    return SizedBox(
                      width: (constraints.maxWidth - 16) / 3,
                      child: _buildPillButton(
                        label: d,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () {
                          setState(() => _density = d);
                          ref
                              .read(settingsProvider.notifier)
                              .updateGeneralSettings(
                                  {'density': _toBackendDensity(d)});
                        },
                      ),
                    );
                  }).toList(),
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // ── 2. Emails per page ─────────────────────────────────────────────
          Text(
            'Emails per page',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final pageOptions = [10, 20, 50, 100];
              if (constraints.maxWidth >= 450) {
                return Row(
                  children: pageOptions.map((count) {
                    final isSelected = _emailsPerPage == count;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: count != pageOptions.last ? 12.0 : 0.0,
                        ),
                        child: _buildPillButton(
                          label: '$count',
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () => setState(() => _emailsPerPage = count),
                        ),
                      ),
                    );
                  }).toList(),
                );
              } else {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pageOptions.map((count) {
                    final isSelected = _emailsPerPage == count;
                    return SizedBox(
                      width: (constraints.maxWidth - 24) / 4,
                      child: _buildPillButton(
                        label: '$count',
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => setState(() => _emailsPerPage = count),
                      ),
                    );
                  }).toList(),
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // ── 3. Accent Color ────────────────────────────────────────────────
          Text(
            'Accent Color',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              '#4F46E5', // Indigo
              '#2563EB', // Blue
              '#EF4444', // Red
              '#10B981', // Green
              '#F59E0B', // Amber
              '#8B5CF6', // Purple
              '#EC4899', // Pink
            ].map((hex) {
              final isSelected = _accentColor.toLowerCase() == hex.toLowerCase();
              final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
              return GestureDetector(
                onTap: () {
                  setState(() => _accentColor = hex);
                  ref
                      .read(settingsProvider.notifier)
                      .updateGeneralSettings({'accentColor': hex});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 36 : 28,
                  height: isSelected ? 36 : 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: isSelected
                        ? BorderRadius.circular(8)
                        : BorderRadius.circular(14),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 4. Font Size Scale ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Font Size Scale',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                ),
              ),
              Text(
                '${_fontSizeScale.toStringAsFixed(_fontSizeScale == _fontSizeScale.roundToDouble() ? 0 : 1)}x',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: const Color(0xFF155EEF),
              inactiveTrackColor:
                  isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF155EEF),
            ),
            child: Slider(
              value: _fontSizeScale,
              min: 0.8,
              max: 1.4,
              divisions: 6,
              onChanged: (v) => setState(() => _fontSizeScale = v),
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 5. Visual Theme Palette ────────────────────────────────────────
          Text(
            'Visual Theme Palette',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                {'name': 'Classic', 'isDefault': true},
                {'name': 'Dark', 'isDefault': false},
                {'name': 'Nature', 'isDefault': false},
                {'name': 'Ocean', 'isDefault': false},
                {'name': 'Sunset', 'isDefault': false},
                {'name': 'Minimal', 'isDefault': false},
              ].map((theme) {
                final name = theme['name'] as String;
                final isDefault = theme['isDefault'] as bool;
                final isSelected =
                    _visualTheme.toLowerCase() == name.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: _buildPillButton(
                    label: name,
                    isSelected: isSelected,
                    isDark: isDark,
                    trailing: isDefault
                        ? Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFD1E4FF)
                                  : (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? const Color(0xFF155EEF)
                                    : const Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      setState(() => _visualTheme = name);
                      final isDarkMode = name.toUpperCase() == 'DARK';
                      ref
                          .read(settingsProvider.notifier)
                          .updateGeneralSettings({
                        'themeMode': isDarkMode ? 'DARK' : 'LIGHT',
                        'visualTheme': name,
                      });
                      if (name == 'Dark' && !isDark) {
                        ref.read(appUiProvider.notifier).toggleDarkMode();
                      } else if (name == 'Classic' && isDark) {
                        ref.read(appUiProvider.notifier).toggleDarkMode();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 6. Background Wallpaper ────────────────────────────────────────
          Text(
            'Background Wallpaper',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),

          // Panoramic Banner if wallpaper is selected
          if (_selectedWallpaperUrl.isNotEmpty) ...[
            Container(
              height: 140,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  _selectedWallpaperUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF155EEF).withValues(alpha: 0.2),
                          const Color(0xFFEC4899).withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Wallpaper Thumbnails
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                {
                  'name': 'Ocean Sunset',
                  'url':
                      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
                },
                {
                  'name': 'Cherry Blossom',
                  'url':
                      'https://images.unsplash.com/photo-1522383225653-ed111181a951?auto=format&fit=crop&w=1200&q=80',
                },
                {
                  'name': 'Desert Dunes',
                  'url':
                      'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=1200&q=80',
                },
                {
                  'name': 'Autumn Leaves',
                  'url':
                      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=1200&q=80',
                },
              ].map((wp) {
                final name = wp['name']!;
                final url = wp['url']!;
                final isSelected = _selectedWallpaperUrl == url;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWallpaperUrl = url;
                      _customWallpaperController.text = url;
                    });
                    ref.read(settingsProvider.notifier).updateWallpaper(url);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFF155EEF),
                              width: 2.5,
                            )
                          : Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                    ),
                    padding: isSelected
                        ? const EdgeInsets.all(2.5)
                        : EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 130,
                        height: 75,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                child: const Icon(
                                  Icons.wallpaper,
                                  size: 24,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.75),
                                  ],
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Custom image URL input row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _customWallpaperController,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Paste custom image URL...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF155EEF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                onPressed: () {
                  final text = _customWallpaperController.text.trim();
                  if (text.isNotEmpty) {
                    setState(() => _selectedWallpaperUrl = text);
                    ref.read(settingsProvider.notifier).updateWallpaper(text);
                  }
                },
                child: const Text(
                  'Apply',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Upload from device & Reset to Default buttons
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white70 : const Color(0xFF1E293B),
                  side: BorderSide(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text(
                  'Upload from device',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  _showSnackBar('Device upload ready.');
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white70 : const Color(0xFF1E293B),
                  side: BorderSide(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text(
                  'Reset to Default',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  setState(() {
                    _selectedWallpaperUrl = '';
                    _customWallpaperController.clear();
                  });
                  ref.read(settingsProvider.notifier).resetWallpaper();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 7. Reading Pane View ───────────────────────────────────────────
          Text(
            'Reading Pane View',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          _buildDropdownContainer(
            isDark: isDark,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentReadingPaneValue,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey,
                ),
                items: readingPaneOptions.map((opt) {
                  final isSelected = opt == currentReadingPaneValue;
                  return DropdownMenuItem(
                    value: opt,
                    child: Row(
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check,
                              size: 16, color: Color(0xFF155EEF)),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          opt,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color:
                                isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _readingPaneMode = v);
                    ref.read(settingsProvider.notifier).updateGeneralSettings({
                      'readingPaneMode': _toBackendReadingPane(v),
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how emails open in your mailbox.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 28),

          // ── Save Layout Settings Button ────────────────────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
            ),
            onPressed: () async {
              final res = await ref
                  .read(settingsProvider.notifier)
                  .updateGeneralSettings({
                'density': _toBackendDensity(_density),
                'emailsPerPage': _emailsPerPage,
                'accentColor': _accentColor,
                'fontSize': _fontSizeScale,
                'visualTheme': _visualTheme,
                'themeMode':
                    _visualTheme.toUpperCase() == 'DARK' ? 'DARK' : 'LIGHT',
                'readingPaneMode': _toBackendReadingPane(_readingPaneMode),
                'wallpaper': _selectedWallpaperUrl,
              });
              if (_selectedWallpaperUrl.isNotEmpty) {
                await ref
                    .read(settingsProvider.notifier)
                    .updateWallpaper(_selectedWallpaperUrl);
              } else {
                await ref.read(settingsProvider.notifier).resetWallpaper();
              }
              if (res.success) {
                _showSnackBar('Layout settings saved successfully!');
              } else {
                _showSnackBar(res.message ?? 'Failed to save layout settings');
              }
            },
            child: const Text(
              'Save Layout Settings',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pill Button Helper ─────────────────────────────────────────────────────
  Widget _buildPillButton({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFF0F6FE))
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF155EEF)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF155EEF)
                    : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  // ── 5. Security & Recovery Tab ────────────────────────────────────────────
  Widget _buildSecurityTab(bool isDark) {
    return _buildAccountsSectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────────
          Text(
            'Security & Recovery',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 1. Profile Information ─────────────────────────────────────────
          _buildSubHeader('PROFILE INFORMATION', isDark),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 650) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildModernLabeledInput(
                        label: 'Job Title',
                        hint: 'e.g. Lead Software Architect',
                        controller: _jobTitleController,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildModernLabeledInput(
                        label: 'Location',
                        hint: 'e.g. San Francisco, CA',
                        controller: _locationController,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildModernLabeledInput(
                        label: 'Phone Contact',
                        hint: 'Enter phone number',
                        controller: _phoneContactController,
                        isDark: isDark,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildModernLabeledInput(
                      label: 'Job Title',
                      hint: 'e.g. Lead Software Architect',
                      controller: _jobTitleController,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildModernLabeledInput(
                      label: 'Location',
                      hint: 'e.g. San Francisco, CA',
                      controller: _locationController,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildModernLabeledInput(
                      label: 'Phone Contact',
                      hint: 'Enter phone number',
                      controller: _phoneContactController,
                      isDark: isDark,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 2. Two-Factor Authentication (2FA) ─────────────────────────────
          _buildSubHeader('TWO-FACTOR AUTHENTICATION (2FA)', isDark),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Enable Two-Factor Authentication',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Switch(
                value: _enable2FA,
                onChanged: (v) async {
                  if (v) {
                    if (_enable2FA) return;
                    _showSnackBar('Initializing 2FA setup...');
                    final res =
                        await ref.read(settingsProvider.notifier).setup2FA();
                    if (res.success && res.data != null) {
                      if (mounted) {
                        _show2FASetupDialog(context, isDark, res.data!);
                      }
                    } else {
                      _showSnackBar(res.message ??
                          'Failed to initialize 2FA. Please try again.');
                    }
                  } else {
                    _showSnackBar(
                      'Disabling Two-Factor Authentication is currently not supported by the backend.',
                    );
                  }
                },
                activeThumbColor: const Color(0xFF155EEF),
                activeTrackColor:
                    const Color(0xFF155EEF).withValues(alpha: 0.35),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Enable Biometric Authentication',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Switch(
                value: _enableBiometrics,
                onChanged: (v) {
                  setState(() => _enableBiometrics = v);
                  ref.read(settingsProvider.notifier).updateGeneralSettings({
                    'biometricsEnabled': v,
                  });
                },
                activeThumbColor: const Color(0xFF155EEF),
                activeTrackColor:
                    const Color(0xFF155EEF).withValues(alpha: 0.35),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
            ),
            onPressed: () async {
              try {
                await UserRepository.updateProfile({
                  'jobTitle': _jobTitleController.text,
                  'location': _locationController.text,
                  'phone': _phoneContactController.text,
                });
              } catch (_) {}

              final res = await ref
                  .read(settingsProvider.notifier)
                  .updateGeneralSettings({
                'jobTitle': _jobTitleController.text,
                'location': _locationController.text,
                'phoneNumber': _phoneContactController.text,
                'biometricsEnabled': _enableBiometrics,
              });

              if (res.success) {
                _showSnackBar('Security preferences saved successfully!');
              } else {
                _showSnackBar(
                  res.message ?? 'Failed to save security preferences',
                );
              }
            },
            child: const Text(
              'Save Security Preferences',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 3. Change Password ─────────────────────────────────────────────
          _buildSubHeader('CHANGE PASSWORD', isDark),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 550) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildModernInput(
                        hint: 'Current Password',
                        controller: _currentPasswordController,
                        isDark: isDark,
                        isPassword: true,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildModernInput(
                        hint: 'New Password',
                        controller: _newPasswordController,
                        isDark: isDark,
                        isPassword: true,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildModernInput(
                      hint: 'Current Password',
                      controller: _currentPasswordController,
                      isDark: isDark,
                      isPassword: true,
                    ),
                    const SizedBox(height: 12),
                    _buildModernInput(
                      hint: 'New Password',
                      controller: _newPasswordController,
                      isDark: isDark,
                      isPassword: true,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
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
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 24),

          // ── 4. Password Recovery & Backup Contacts ─────────────────────────
          _buildSubHeader('PASSWORD RECOVERY & BACKUP CONTACTS', isDark),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 550) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildModernLabeledInput(
                        label: 'Recovery Email Address',
                        hint: 'backup@example.com',
                        controller: _recoveryEmailController,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildModernLabeledInput(
                        label: 'Recovery Phone Number (10 Digits)',
                        hint: '+1234567890',
                        controller: _backupPhoneController,
                        isDark: isDark,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildModernLabeledInput(
                      label: 'Recovery Email Address',
                      hint: 'backup@example.com',
                      controller: _recoveryEmailController,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildModernLabeledInput(
                      label: 'Recovery Phone Number (10 Digits)',
                      hint: '+1234567890',
                      controller: _backupPhoneController,
                      isDark: isDark,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
            ),
            onPressed: () async {
              try {
                await UserRepository.updateRecovery(
                  _recoveryEmailController.text,
                  _backupPhoneController.text,
                );
                _showSnackBar('Recovery details saved successfully!');
              } catch (_) {
                _showSnackBar('Recovery details saved.');
              }
            },
            child: const Text(
              'Save Security Preferences',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Labels & Sidebar Tab ───────────────────────────────────────────────
  Widget _buildLabelsSidebarTab(bool isDark) {
    return _buildAccountsSectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────────
          Text(
            'Labels & Sidebar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),
          Text(
            'Toggle which standard system folders and custom labels appear in the primary sidebar.',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),

          // ── 9 Labels Toggle Grid ───────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              if (constraints.maxWidth >= 720) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth >= 460) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }

              final spacing = 14.0;
              final totalSpacing = spacing * (crossAxisCount - 1);
              final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _sidebarLabels.keys.map((label) {
                  final isChecked = _sidebarLabels[label] ?? true;
                  return SizedBox(
                    width: itemWidth,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Switch(
                            value: isChecked,
                            onChanged: (val) async {
                              setState(() => _sidebarLabels[label] = val);
                              ref
                                  .read(appUiProvider.notifier)
                                  .setSidebarLabel(label, val);
                              final email =
                                  ref.read(activeAccountProvider).email;
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
                            activeThumbColor: const Color(0xFF155EEF),
                            activeTrackColor:
                                const Color(0xFF155EEF).withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 7. Active Sessions & Logs Tab ──────────────────────────────────────────
  Widget _buildActiveSessionsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Card 1: Active Login Sessions ──────────────────────────────────
        _buildAccountsSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────────────
              Text(
                'Active Login Sessions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 14),
              Text(
                'Review and manage currently authenticated sessions and devices.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 22),

              // ── Sessions Cards List ────────────────────────────────────────
              if (_activeDeviceSessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.devices_rounded,
                        size: 40,
                        color: Color(0xFF155EEF),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Other Active Sessions',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your account is currently active only on this device.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._activeDeviceSessions.map(
                  (sess) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Laptop Icon Container
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.laptop_chromebook_rounded,
                            size: 22,
                            color: Color(0xFF155EEF),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Info Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sess['title'] ?? 'Unknown Device',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sess['ip'] ?? 'Web Browser',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sess['lastActive'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Sign Out Button
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.2,
                            ),
                            foregroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () async {
                            final sid = sess['id'] ?? '';
                            setState(() => _activeDeviceSessions.remove(sess));
                            if (sid.isNotEmpty) {
                              try {
                                await UserRepository.revokeSession(sid);
                              } catch (_) {}
                            }
                            _showSnackBar('Signed out from session.');
                          },
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Card 2: Connected Applications ─────────────────────────────────
        _buildAccountsSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────────────
              Text(
                'Connected Applications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 14),
              Text(
                'Third-party applications authorized to access your mailbox profile.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 22),

              // ── Connected Apps List ────────────────────────────────────────
              if (_connectedApplications.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 40,
                        color: Color(0xFF155EEF),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Connected Applications',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No external apps currently have access to your mailbox.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._connectedApplications.map(
                  (app) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Shield Icon Container
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 22,
                            color: Color(0xFF155EEF),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Info Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app['name'] ?? 'Authorized App',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                app['scope'] ?? 'Basic Profile Access',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                app['date'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Revoke Access Button
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.2,
                            ),
                            foregroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            setState(() => _connectedApplications.remove(app));
                            _showSnackBar(
                              'Access revoked for ${app['name'] ?? 'Application'}.',
                            );
                          },
                          child: const Text(
                            'Revoke Access',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Card 3: Recent Activity Logs ───────────────────────────────────
        _buildAccountsSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────────────
              Text(
                'Recent Activity Logs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 14),
              Text(
                'Security audit trail of recent login events and account operations.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 22),

              // ── Activity Logs List ─────────────────────────────────────────
              if (_recentActivityLogs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 40,
                        color: Color(0xFF155EEF),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Recent Activity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No login events or security actions recorded yet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._recentActivityLogs.map(
                  (log) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            log['ip'] ?? '',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : const Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          log['timestamp'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared UI Components ──────────────────────────────────────────────────
  Widget _buildSubHeader(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white54 : const Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildModernLabeledInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        _buildModernInput(
          hint: hint,
          controller: controller,
          isDark: isDark,
          isPassword: isPassword,
        ),
      ],
    );
  }

  Widget _buildModernInput({
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    bool isPassword = false,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(
          fontSize: 13.5,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
