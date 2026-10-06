import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/account_provider.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../../data/repositories/subscription_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/settings_provider.dart';
import '../../../models/account_model.dart';
import '../../../models/two_factor_model.dart';

class ManageAccountScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const ManageAccountScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ManageAccountScreen> createState() =>
      _ManageAccountScreenState();
}

class _ManageAccountScreenState extends ConsumerState<ManageAccountScreen> {
  late int _selectedTab;
  int _homeSubPage = 0; // 0 = Overview grid, 1 = Emails & Identities, 2 = Data & Privacy, 3 = Signing in to BNX
  bool _isLoading = false;

  // Personal Info local state
  String? _lastLoadedEmail;
  String _nickname = 'Not set';
  String _displayName = 'Not set';
  String _gender = 'Rather not say';
  String _homeAddress = 'None added';
  String _workAddress = 'None added';
  String _occupation = 'None added';
  String _bio = 'Write a brief description about yourself';
  bool _isProfileMenuOpen = false;

  // Section 2.2: Storage Quota state
  StorageQuota? _storageQuota;
  bool _isLoadingStorageQuota = false;

  // Section 6.1: Active Cliks Business Subscription state
  Map<String, dynamic>? _subscriptionData;
  bool _isLoadingSubscription = false;

  // Section 3: 2FA & Security state
  bool _is2faLoading = false;
  bool _isVerifyingEmail = false;

  // Section 5.1 & 5.3: Connected Mail Accounts state
  List<Map<String, dynamic>> _connectedEmails = [];
  bool _isLoadingEmails = false;

  // Section 5.5: Sub-IDs state
  List<Map<String, dynamic>> _apiSubIds = [];
  bool _isLoadingSubIds = false;

  // Sub-IDs fallback state
  final List<Map<String, String>> _subIds = [
    {
      'username': 'sales.ravinew2004',
      'name': 'ravi kumar',
      'type': 'BUSINESS',
    },
  ];

  final List<_TabItem> _tabs = const [
    _TabItem(
      title: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_outlined,
    ),
    _TabItem(
      title: 'Personal info',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_outline_rounded,
    ),
    _TabItem(
      title: 'Payment &\nsubscription',
      icon: Icons.credit_card_outlined,
      selectedIcon: Icons.credit_card_outlined,
    ),
    _TabItem(
      title: 'Team & Sub-IDs',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_outline_rounded,
    ),
    _TabItem(
      title: 'Account storage',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_outlined,
    ),
    _TabItem(
      title: 'B2Auth',
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, _tabs.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccountData();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5 API INTEGRATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadAccountData([String? accountEmail]) async {
    final email = accountEmail ?? ref.read(activeAccountProvider).email;
    _lastLoadedEmail = email.trim().toLowerCase();
    _loadProfileSettings(email);
    _loadConnectedEmails();
    _loadSubIds();
    _loadStorageQuota();
    _loadSubscriptionData(email);
    ref.read(settingsProvider.notifier).loadAllSettings();
  }

  /// 2.2 Storage Quota (GET /api/mail/storage-quota)
  Future<void> _loadStorageQuota() async {
    if (!mounted) return;
    setState(() => _isLoadingStorageQuota = true);
    try {
      final quota = await StorageRepository.fetchStorageQuota();
      if (mounted) {
        setState(() {
          _storageQuota = quota;
          _isLoadingStorageQuota = false;
        });
      }
    } catch (e) {
      print('[MANAGE_ACCOUNT] loadStorageQuota error: $e');
      if (mounted) setState(() => _isLoadingStorageQuota = false);
    }
  }

  /// 6.1 Cliks Business Subscription (GET https://cliks.beta-softnet.com/api/v1/business/subscription/{userEmail})
  Future<void> _loadSubscriptionData([String? accountEmail]) async {
    if (!mounted) return;
    setState(() => _isLoadingSubscription = true);
    try {
      final email = accountEmail ?? ref.read(activeAccountProvider).email;
      final sub = await SubscriptionRepository.getBusinessSubscription(email);
      if (mounted) {
        setState(() {
          _subscriptionData = sub;
          _isLoadingSubscription = false;
        });
      }
    } catch (e) {
      print('[MANAGE_ACCOUNT] loadSubscriptionData error: $e');
      if (mounted) setState(() => _isLoadingSubscription = false);
    }
  }

  /// 5. Initiate Email Verification (GET /api/verification/initiate/{emailId})
  Future<void> _initiateEmailVerification(
    dynamic emailId,
    String emailStr,
  ) async {
    if (_isVerifyingEmail) return;
    setState(() => _isVerifyingEmail = true);
    try {
      final success = await UserRepository.initiateEmailVerification(emailId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification link sent to $emailStr. Please check your inbox.'),
              backgroundColor: const Color(0xFF1E8E3E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initiate verification for $emailStr'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingEmail = false);
    }
  }

  /// Open Change Password Dialog (POST /api/auth/change-password)
  void _openChangePasswordDialog(bool isDark) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surfaceColor = isDark ? const Color(0xFF23262B) : Colors.white;
          final borderColor =
              isDark ? const Color(0xFF383C44) : const Color(0xFFE2E4E8);

          return Dialog(
            backgroundColor: surfaceColor,
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: 1),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF202124),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your current password and a new password to keep your account secure.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPassController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final oldP = currentPassController.text;
                                  final newP = newPassController.text;
                                  if (oldP.isEmpty || newP.isEmpty) {
                                    setDialogState(() {
                                      errorMessage = 'Please fill both password fields.';
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    isSubmitting = true;
                                    errorMessage = null;
                                  });
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await UserRepository.changePassword(oldP, newP);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Password updated successfully!'),
                                          backgroundColor: Color(0xFF1E8E3E),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                      errorMessage = 'Failed to update password: $e';
                                    });
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Update Password'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Open 2FA Setup or Management Dialog (POST /api/users/2fa/setup, POST /api/users/2fa/disable)
  void _open2FAManagement(bool isDark, bool is2Fa) async {
    if (is2Fa) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF24272B) : Colors.white,
          title: const Text('Two-Factor Authentication'),
          content: const Text(
            'Two-factor authentication is currently enabled for your account. Would you like to disable it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Disable 2FA'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _is2faLoading = true);
        try {
          final res = await ref.read(settingsProvider.notifier).disable2FA();
          if (mounted) {
            if (res.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Two-factor authentication disabled.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message ?? 'Failed to disable 2FA'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } finally {
          if (mounted) setState(() => _is2faLoading = false);
        }
      }
    } else {
      setState(() => _is2faLoading = true);
      try {
        final res = await ref.read(settingsProvider.notifier).setup2FA();
        if (mounted) {
          setState(() => _is2faLoading = false);
          if (res.success && res.data != null) {
            _show2FASetupDialog(isDark, res.data!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.message ?? 'Failed to initialize 2FA setup'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _is2faLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initializing 2FA: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _show2FASetupDialog(bool isDark, TwoFactorSetupData data) {
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
            final surfaceColor =
                isDark ? const Color(0xFF1E293B) : Colors.white;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: surfaceColor,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.security_rounded,
                              color: Color(0xFF1A73E8),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Set Up 2-Step Verification',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF202124),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(
                          'Add your BNX Mail account to an authenticator app (such as Google Authenticator or Authy) using the secret key below:',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (data.secret != null && data.secret!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    data.secret!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF1A73E8)),
                                  tooltip: 'Copy Key',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: data.secret!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Secret key copied to clipboard'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        Text(
                          'Enter the 6-digit code from your authenticator app:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (i) {
                                return Container(
                                  width: 44,
                                  height: 52,
                                  margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: focusNodes[i].hasFocus
                                          ? const Color(0xFF1A73E8)
                                          : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                      width: focusNodes[i].hasFocus ? 2.0 : 1.0,
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF202124),
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
                                        setDialogState(() => errorMessage = null);
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
                              color: Colors.redAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isVerifying
                                ? null
                                : () async {
                                    final code = controllers.map((c) => c.text).join();
                                    if (code.length < 6) {
                                      setDialogState(() {
                                        errorMessage = 'Please enter the full 6-digit code';
                                      });
                                      return;
                                    }
                                    setDialogState(() {
                                      isVerifying = true;
                                      errorMessage = null;
                                    });
                                    final res = await ref.read(settingsProvider.notifier).verify2FA(code);
                                    if (res.success) {
                                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Two-factor authentication enabled successfully!'),
                                            backgroundColor: Color(0xFF1E8E3E),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } else {
                                      setDialogState(() {
                                        isVerifying = false;
                                        errorMessage = res.message ?? 'Verification failed';
                                      });
                                    }
                                  },
                            child: isVerifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Verify & Enable'),
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
    );
  }

  Future<void> _loadProfileSettings([String? accountEmail]) async {
    try {
      final email = accountEmail ?? ref.read(activeAccountProvider).email;
      final settings = await UserRepository.getProfileData(email: email);
      if (settings != null && mounted) {
        setState(() {
          if (settings['nickname'] != null &&
              settings['nickname'].toString().isNotEmpty) {
            _nickname = settings['nickname'].toString();
          } else {
            _nickname = 'Not set';
          }
          if (settings['displayName'] != null &&
              settings['displayName'].toString().isNotEmpty) {
            _displayName = settings['displayName'].toString();
          } else {
            _displayName = 'Not set';
          }
          if (settings['gender'] != null &&
              settings['gender'].toString().isNotEmpty) {
            _gender = settings['gender'].toString();
          } else {
            _gender = 'Rather not say';
          }
          if (settings['homeAddress'] != null &&
              settings['homeAddress'].toString().isNotEmpty) {
            _homeAddress = settings['homeAddress'].toString();
          } else {
            _homeAddress = 'None added';
          }
          if (settings['workAddress'] != null &&
              settings['workAddress'].toString().isNotEmpty) {
            _workAddress = settings['workAddress'].toString();
          } else {
            _workAddress = 'None added';
          }
          if (settings['occupation'] != null &&
              settings['occupation'].toString().isNotEmpty) {
            _occupation = settings['occupation'].toString();
          } else {
            _occupation = 'None added';
          }
          if (settings['bio'] != null &&
              settings['bio'].toString().isNotEmpty) {
            _bio = settings['bio'].toString();
          } else {
            _bio = 'Write a brief description about yourself';
          }
        });

        // Also sync active account model fields if returned in settings
        final activeAcc = ref.read(activeAccountProvider);
        final phone =
            (settings['phoneNumber'] ?? settings['phone'])?.toString();
        final recEmail = settings['recoveryEmail']?.toString();
        DateTime? dob;
        final rawDob = settings['dob'] ?? settings['birthday'];
        if (rawDob != null) {
          dob = DateTime.tryParse(rawDob.toString());
        }
        final name = (settings['fullName'] ?? settings['name'])?.toString();
        if ((phone != null && phone.isNotEmpty) ||
            (recEmail != null && recEmail.isNotEmpty) ||
            dob != null ||
            (name != null && name.isNotEmpty)) {
          ref.read(accountsProvider.notifier).updateAccountFields(
                activeAcc.id,
                phone: phone,
                recoveryEmail: recEmail,
                dob: dob,
                name: name,
              );
        }
      }
    } catch (e) {
      print('[MANAGE_ACCOUNT] loadProfileSettings error: $e');
    }
  }

  /// 5.1 List Connected Mail Accounts (GET /api/emails/list)
  Future<void> _loadConnectedEmails() async {
    if (!mounted) return;
    setState(() => _isLoadingEmails = true);
    try {
      final list = await UserRepository.getConnectedEmails();
      if (mounted) {
        setState(() {
          _connectedEmails = list;
          _isLoadingEmails = false;
        });
      }
    } catch (e) {
      print('[MANAGE_ACCOUNT] loadConnectedEmails error: $e');
      if (mounted) setState(() => _isLoadingEmails = false);
    }
  }

  /// 5.3 Switch Primary Mailbox (POST /api/emails/{emailId}/set-primary)
  Future<void> _switchPrimaryEmail(dynamic emailId) async {
    setState(() => _isLoadingEmails = true);
    final success = await UserRepository.switchPrimaryMailbox(emailId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Primary email switched successfully'),
            backgroundColor: Color(0xFF1E8E3E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadConnectedEmails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to switch primary email'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoadingEmails = false);
      }
    }
  }

  /// 5.2 Create New Mailbox / Alias (POST /api/emails/create)
  void _openCreateMailboxDialog(bool isDark) {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surfaceColor = isDark ? const Color(0xFF23262B) : Colors.white;
          final borderColor =
              isDark ? const Color(0xFF383C44) : const Color(0xFFE2E4E8);

          return Dialog(
            backgroundColor: surfaceColor,
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: 1),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Create New Mailbox / Alias',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.white : const Color(0xFF202124),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new linked mailbox identity for your account.',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mailbox Name / Prefix',
                        hintText: 'e.g. support or ashwin_work',
                        suffixText: '@bnxmail.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter secure password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  final pass = passCtrl.text.trim();
                                  if (name.isEmpty || pass.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please fill all fields'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                  setDialogState(() => isSubmitting = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await UserRepository.createMailbox(
                                      emailName: name,
                                      password: pass,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Mailbox "$name@bnxmail.com" created successfully'),
                                          backgroundColor:
                                              const Color(0xFF1E8E3E),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      await _loadConnectedEmails();
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSubmitting = false);
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Failed to create mailbox: $e'),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Create Mailbox'),
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
      ),
    );
  }

  /// 5.5 List Sub-ID Accounts (GET /api/subid/list)
  Future<void> _loadSubIds() async {
    if (!mounted) return;
    setState(() => _isLoadingSubIds = true);
    try {
      final list = await UserRepository.listSubIds();
      if (mounted) {
        setState(() {
          _apiSubIds = list;
          _isLoadingSubIds = false;
        });
      }
    } catch (e) {
      print('[MANAGE_ACCOUNT] loadSubIds error: $e');
      if (mounted) setState(() => _isLoadingSubIds = false);
    }
  }

  /// 5.6 Parent Approval for Child Accounts (PATCH /api/users/{id}/approve)
  Future<void> _approveChildAccount(dynamic subId) async {
    final success = await UserRepository.approveChildAccount(subId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Child account approved successfully'),
            backgroundColor: Color(0xFF1E8E3E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadSubIds();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve child account'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHOTO UPLOAD & REMOVE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isLoading = true);
        final file = result.files.first;
        Uint8List? fileBytes = file.bytes;
        final filePath = file.path;

        if (fileBytes == null && filePath != null) {
          try {
            final f = File(filePath);
            if (f.existsSync()) {
              fileBytes = await f.readAsBytes();
            }
          } catch (e) {
            print('[FILE READ ERROR] $e');
          }
        }

        if (fileBytes != null || (filePath != null && filePath.isNotEmpty)) {
          final activeAccount = ref.read(activeAccountProvider);
          final accountId = activeAccount.email.isNotEmpty
              ? activeAccount.email
              : activeAccount.id;
          final ext = (file.extension ?? 'jpg').toLowerCase();
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          final localPreviewUri = fileBytes != null
              ? 'data:$mime;base64,${base64Encode(fileBytes)}'
              : (filePath ?? '');

          await ref.read(accountsProvider.notifier).updateAvatar(
                accountId,
                localPreviewUri,
                bytes: fileBytes,
                filePath: filePath,
                filename: file.name,
              );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removePhoto() async {
    final activeAccount = ref.read(activeAccountProvider);
    final accountId = activeAccount.email.isNotEmpty
        ? activeAccount.email
        : activeAccount.id;
    if (activeAccount.avatarUrl == null || activeAccount.avatarUrl!.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text(
          'Are you sure you want to remove your profile photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(accountsProvider.notifier)
            .removeAvatar(accountId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo removed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove photo: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD ENTRY POINT
  // ═══════════════════════════════════════════════════════════════════════════
  void _handleBackNavigation() {
    if (_homeSubPage != 0) {
      setState(() => _homeSubPage = 0);
    } else if (_selectedTab != 0) {
      setState(() => _selectedTab = 0);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    final currentEmail = account.email.trim().toLowerCase();
    if (_lastLoadedEmail != currentEmail && currentEmail.isNotEmpty) {
      _lastLoadedEmail = currentEmail;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAccountData(currentEmail);
      });
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileDevice = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final isMobile = isMobileDevice ||
        (screenWidth < 800 &&
            defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.windows);

    final bgColor = isDark ? const Color(0xFF1E2022) : Colors.white;

    return PopScope(
      canPop: !isMobile ||
          (_homeSubPage == 0 &&
              _selectedTab == 0 &&
              Navigator.of(context).canPop()),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Top Google Account Style Bar (Exact match to screenshots)
              _buildTopAppBar(account, isDark, isMobile),

              // Mobile Horizontal Tab Bar (For responsive screens)
              if (isMobile) _buildMobileTabBar(isDark),

              // Content Area (Split Sidebar + Body on Desktop)
              Expanded(
                child: isMobile
                    ? _buildScrollableContent(account, isDark, isMobile)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Sidebar
                          _buildDesktopSidebar(isDark),

                          // Vertical Divider
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark
                                ? const Color(0xFF3C4043)
                                : const Color(0xFFE8EAED),
                          ),

                          // Main Scrollable Area
                          Expanded(
                            child: _buildScrollableContent(
                              account,
                              isDark,
                              isMobile,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP BAR (Screenshots 1-5: [B BETA] Account  ...  (?) [:::] [Avatar Ravi v])
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTopAppBar(AccountModel account, bool isDark, bool isMobile) {
    final displayName = account.name.isNotEmpty ? account.name : 'Ravi Kumar C';

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24272B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3C4043) : const Color(0xFFE8EAED),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // On mobile, show back button
          if (isMobile) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Back',
              onPressed: _handleBackNavigation,
            ),
            const SizedBox(width: 4),
          ],

          // Logo (B Beta) + "Account" title
          InkWell(
            onTap: _handleBackNavigation,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/beta_logo.jpg',
                      height: 32,
                      width: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.account_circle,
                        size: 32,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          if (!isMobile) ...[
            // Help Icon (?)
            IconButton(
              icon: Icon(
                Icons.help_outline_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                size: 22,
              ),
              tooltip: 'Help',
              onPressed: () {},
            ),

            // Apps Launcher Icon (3x3 grid)
            IconButton(
              icon: Icon(
                Icons.apps_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                size: 22,
              ),
              tooltip: 'BNX Apps',
              onPressed: () {},
            ),

            const SizedBox(width: 6),
          ],

          // User Profile Dropdown Pill
          _buildUserProfilePill(account, displayName, isDark, isMobile),
        ],
      ),
    );
  }

  Widget _buildUserProfilePill(
    AccountModel account,
    String displayName,
    bool isDark,
    bool isMobile,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Account Info',
      offset: const Offset(0, 52),
      elevation: 6,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
        ),
      ),
      color: isDark ? const Color(0xFF24272B) : Colors.white,
      onOpened: () => setState(() => _isProfileMenuOpen = true),
      onCanceled: () => setState(() => _isProfileMenuOpen = false),
      onSelected: (value) {
        setState(() => _isProfileMenuOpen = false);
        if (value == 'sign_out') {
          _handleSignOut();
        } else if (value == 'add_account') {
          context.go('/auth/login');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 270,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Center Avatar
                AvatarWidget(
                  name: displayName,
                  avatarUrl: account.avatarUrl,
                  size: 64,
                  fontSize: 26,
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                // Email
                Text(
                  account.email.isNotEmpty
                      ? account.email
                      : 'ravinew2004@bnxmail.com',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF3C4043)
                      : const Color(0xFFE8EAED),
                ),
                const SizedBox(height: 14),

                // Action 1: Add another account
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/auth/login');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add,
                          size: 19,
                          color: isDark ? Colors.white : const Color(0xFF202124),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Add another account',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF202124),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Action 2: Sign out of all accounts
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _handleSignOut();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 19,
                          color: isDark ? Colors.white : const Color(0xFF202124),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign out of all accounts',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF202124),
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
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
          ),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(
              name: displayName,
              avatarUrl: account.avatarUrl,
              size: 30,
              fontSize: 12,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF3C4043),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isProfileMenuOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isDark ? Colors.white54 : const Color(0xFF5F6368),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LEFT SIDEBAR (Exact match to Screenshots 1-5)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopSidebar(bool isDark) {
    return Container(
      width: 250,
      color: isDark ? const Color(0xFF1E2022) : Colors.white,
      padding: const EdgeInsets.only(top: 16, bottom: 20, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Tabs
          ...List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final isSelected = _selectedTab == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () {
                  if (index == 4) {
                    context.push('/storage');
                    return;
                  }
                  setState(() {
                    _selectedTab = index;
                    if (index == 0) _homeSubPage = 0;
                  });
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? const Color(0xFF1A73E8).withValues(alpha: 0.15)
                            : const Color(0xFFE8F0FE))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: isSelected
                        ? Border.all(
                            color: const Color(0xFF1A73E8),
                            width: 1.5,
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? tab.selectedIcon : tab.icon,
                        size: 20,
                        color: isSelected
                            ? const Color(0xFF1A73E8)
                            : (isDark
                                ? Colors.white60
                                : const Color(0xFF5F6368)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          tab.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected
                                ? const Color(0xFF1A73E8)
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF3C4043)),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Bottom Sign out button (Exact match to Screenshots)
          InkWell(
            onTap: _handleSignOut,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Sign out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color:
                          isDark ? Colors.white70 : const Color(0xFF3C4043),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE TAB BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileTabBar(bool isDark) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24272B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3C4043) : const Color(0xFFE8EAED),
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isSelected = _selectedTab == index;
          // Flatten multi-line title for horizontal tab
          final singleLineTitle = tab.title.replaceAll('\n', ' ');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                if (index == 4) {
                  context.push('/storage');
                  return;
                }
                setState(() {
                  _selectedTab = index;
                  if (index == 0) _homeSubPage = 0;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFF1A73E8).withValues(alpha: 0.2)
                          : const Color(0xFFE8F0FE))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF1A73E8), width: 1.5)
                      : Border.all(
                          color: isDark
                              ? const Color(0xFF3C4043)
                              : const Color(0xFFE8EAED),
                        ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? tab.selectedIcon : tab.icon,
                      size: 16,
                      color: isSelected
                          ? const Color(0xFF1A73E8)
                          : (isDark
                              ? Colors.white60
                              : const Color(0xFF5F6368)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      singleLineTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF1A73E8)
                            : (isDark
                                ? Colors.white70
                                : const Color(0xFF3C4043)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN SCROLLABLE CONTENT (Zero overflow on all OSs & screens)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildScrollableContent(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 36,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: _buildActiveTabContent(account, isDark, isMobile),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildHomeTab(account, isDark, isMobile);
      case 1:
        return _buildPersonalInfoTab(account, isDark, isMobile);
      case 2:
        return _buildPaymentAndSubscriptionTab(account, isDark, isMobile);
      case 3:
        return _buildTeamAndSubIdsTab(account, isDark, isMobile);
      case 4:
        return _buildAccountStorageTab(account, isDark, isMobile);
      case 5:
        return _buildB2AuthTab(account, isDark, isMobile);
      default:
        return _buildHomeTab(account, isDark, isMobile);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. HOME TAB (Screenshots 1 & 2)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab(AccountModel account, bool isDark, bool isMobile) {
    if (_homeSubPage == 1) {
      return _buildEmailIdentitiesView(account, isDark, isMobile);
    } else if (_homeSubPage == 2) {
      return _buildDataAndPrivacyView(account, isDark, isMobile);
    } else if (_homeSubPage == 3) {
      return _buildSigningInToBnxView(account, isDark, isMobile);
    }

    final emailAddress = account.email.isNotEmpty
        ? account.email
        : 'ravinew2004@bnxmail.com';

    // Card 1: Emails & Identities -> Navigates to Screenshot 1 ("Your Email Identities")
    final card1 = _buildHomeCard(
      isDark: isDark,
      icon: Icons.mail_outline_rounded,
      title: 'Emails & Identities',
      subtitle:
          'Manage your primary and secondary email addresses associated with this account',
      middleWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2124) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF1E8E3E),
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                emailAddress,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF3C4043),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actionLabel: 'Manage your emails',
      onAction: () => setState(() => _homeSubPage = 1),
    );

    // Card 2: Privacy & personalization -> Navigates to Screenshot 2 ("Data & privacy")
    final card2 = _buildHomeCard(
      isDark: isDark,
      icon: Icons.shield_outlined,
      title: 'Privacy & personalization',
      subtitle:
          'See the data in your BNX Account and choose what activity is saved to personalize your BNX experience',
      middleWidget: const SizedBox(height: 38),
      actionLabel: 'Manage your data & privacy',
      onAction: () => setState(() => _homeSubPage = 2),
    );

    // Card 3: Account & Security -> Navigates to Screenshot 3 ("Signing in to BNX")
    final card3 = _buildHomeCard(
      isDark: isDark,
      icon: Icons.verified_user_outlined,
      title: 'Account & Security',
      subtitle:
          'Security checkup and recommendations for your ${(account.accountType.isNotEmpty ? account.accountType : "BUSINESS").toUpperCase()} account.',
      middleWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2A4A) : const Color(0xFFE8F0FE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.language_rounded,
              color: Color(0xFF1A73E8),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '${(account.accountType.isNotEmpty ? account.accountType : "BUSINESS").toUpperCase()} Account',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A73E8),
              ),
            ),
          ],
        ),
      ),
      actionLabel: 'Protect your account',
      onAction: () => setState(() => _homeSubPage = 3),
    );

    // Card 4: Account storage -> Navigates to "Account storage" tab (Storage page)
    final card4 = _buildHomeCard(
      isDark: isDark,
      icon: Icons.inventory_2_outlined,
      title: 'Account storage',
      subtitle:
          'Your account storage is shared across BNX services, like BNX Mail and Drive',
      middleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.05,
              minHeight: 4,
              backgroundColor: isDark
                  ? const Color(0xFF3C4043)
                  : const Color(0xFFE8EAED),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1A73E8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '8.88 MB of 5 GB used',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF5F6368),
            ),
          ),
        ],
      ),
      actionLabel: 'Manage storage',
      onAction: () => context.push('/storage'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHomeHeader(account, isDark, showBackButton: false),

        // 2x2 Grid of Cards (or 1-column on mobile)
        if (isMobile) ...[
          card1,
          const SizedBox(height: 20),
          card2,
          const SizedBox(height: 20),
          card3,
          const SizedBox(height: 20),
          card4,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    card1,
                    const SizedBox(height: 24),
                    card3,
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    card2,
                    const SizedBox(height: 24),
                    card4,
                  ],
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared Home Header (Avatar + Welcome Text)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHomeHeader(
    AccountModel account,
    bool isDark, {
    bool showBackButton = false,
  }) {
    final firstName =
        account.name.isNotEmpty ? account.name.split(' ').first : 'Ravi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBackButton) ...[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _homeSubPage = 0),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF5F6368),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Back to Home overview',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
        ],

        // Large Profile Avatar (Screenshot 1, 2, 3)
        AvatarWidget(
          name: account.name.isNotEmpty ? account.name : 'Ravi Kumar C',
          avatarUrl: account.avatarUrl,
          size: 84,
          fontSize: 34,
        ),
        const SizedBox(height: 16),

        // Welcome Header
        Text(
          'Welcome, $firstName',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF202124),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Manage your info, privacy, and security to make B2Auth work better for you.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : const Color(0xFF5F6368),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // SUBPAGE 1: Your Email Identities (Section 5.1, 5.2, 5.3 API Integrated)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEmailIdentitiesView(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    final fallbackEmail = account.email.isNotEmpty
        ? account.email
        : 'ravinew2004@bnxmail.com';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHomeHeader(account, isDark, showBackButton: true),

        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 780),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24272B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3C4043)
                    : const Color(0xFFDADCE0),
              ),
            ),
            padding: EdgeInsets.all(isMobile ? 18 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Add Mailbox action row
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Email Identities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF202124),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your primary email is used for account-related notifications and as your default identity.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openCreateMailboxDialog(isDark),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add Mailbox',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Email Identities',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF202124),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your primary email is used for account-related notifications and as your default identity.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _openCreateMailboxDialog(isDark),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add Mailbox',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),

                if (_isLoadingEmails)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),

                // Connected emails list from Section 5.1
                if (_connectedEmails.isNotEmpty) ...[
                  ..._connectedEmails.map((item) {
                    final isPrimary = item['isPrimary'] == true;
                    final emailStr = item['email']?.toString() ??
                        item['emailName']?.toString() ??
                        fallbackEmail;
                    final emailId = item['id'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? (isDark
                                  ? const Color(0xFF1B2A4A)
                                  : const Color(0xFFE8F2FD))
                              : (isDark
                                  ? const Color(0xFF1E2124)
                                  : const Color(0xFFF8F9FA)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: isPrimary
                                  ? const Color(0xFF1A73E8)
                                  : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                              width: isPrimary ? 4 : 1,
                            ),
                            top: BorderSide(
                              color: isPrimary
                                  ? (isDark ? const Color(0xFF2A3B5C) : const Color(0xFFD3E3FD))
                                  : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                            ),
                            right: BorderSide(
                              color: isPrimary
                                  ? (isDark ? const Color(0xFF2A3B5C) : const Color(0xFFD3E3FD))
                                  : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                            ),
                            bottom: BorderSide(
                              color: isPrimary
                                  ? (isDark ? const Color(0xFF2A3B5C) : const Color(0xFFD3E3FD))
                                  : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF24272B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3C4043)
                                      : const Color(0xFFDADCE0),
                                ),
                              ),
                              child: Icon(
                                Icons.mail_outline_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF5F6368),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emailStr,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF202124),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isPrimary ? 'Primary email' : 'Connected mailbox / alias',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF5F6368),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isPrimary)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF137333),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Primary',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (item['isVerified'] == false || item['verified'] == false)
                                    OutlinedButton(
                                      onPressed: emailId != null && !_isVerifyingEmail
                                          ? () => _initiateEmailVerification(emailId, emailStr)
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFE37400),
                                        side: const BorderSide(color: Color(0xFFE37400)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        'Verify',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  OutlinedButton(
                                    onPressed: emailId != null
                                        ? () => _switchPrimaryEmail(emailId)
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1A73E8),
                                      side: const BorderSide(color: Color(0xFF1A73E8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Set as Primary',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  // Fallback primary identity box
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1B2A4A)
                          : const Color(0xFFE8F2FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: const BorderSide(
                          color: Color(0xFF1A73E8),
                          width: 4,
                        ),
                        top: BorderSide(
                          color: isDark
                              ? const Color(0xFF2A3B5C)
                              : const Color(0xFFD3E3FD),
                        ),
                        right: BorderSide(
                          color: isDark
                              ? const Color(0xFF2A3B5C)
                              : const Color(0xFFD3E3FD),
                        ),
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(0xFF2A3B5C)
                              : const Color(0xFFD3E3FD),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF24272B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF3C4043)
                                  : const Color(0xFFDADCE0),
                            ),
                          ),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF5F6368),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fallbackEmail,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF202124),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Primary email',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF5F6368),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF137333),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Bottom note with info icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To add a new email address, you can create a mailbox alias above or register it through BNX Mail.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF3C4043),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBPAGE 2: Data & privacy (Exact match to Screenshot 2)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDataAndPrivacyView(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHomeHeader(account, isDark, showBackButton: true),

        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 780),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24272B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3C4043)
                    : const Color(0xFFDADCE0),
              ),
            ),
            padding: EdgeInsets.all(isMobile ? 18 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Data & privacy',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle
                Text(
                  'Key settings, and data from your use of BNX services',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                  ),
                ),
                const SizedBox(height: 24),

                // List container (Screenshot 2)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3C4043)
                          : const Color(0xFFDADCE0),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Row 1: Web & App Activity
                      InkWell(
                        onTap: () {},
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.language_rounded,
                                size: 22,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF5F6368),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Web & App Activity',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF202124),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Saves your activity on BNX sites and apps.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF5F6368),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'On',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF137333),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF5F6368),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? const Color(0xFF3C4043)
                            : const Color(0xFFE8EAED),
                      ),

                      // Row 2: Delete your account
                      InkWell(
                        onTap: () {},
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(11),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 22,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF5F6368),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delete your account',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF202124),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Permanently delete your B2Auth account and data.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF5F6368),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF5F6368),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBPAGE 3: Signing in to BNX (Exact match to Screenshot 3)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSigningInToBnxView(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHomeHeader(account, isDark, showBackButton: true),

        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 780),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24272B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3C4043)
                    : const Color(0xFFDADCE0),
              ),
            ),
            padding: EdgeInsets.all(isMobile ? 18 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Signing in to BNX',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle
                Text(
                  'Settings and recommendations to help you keep your account secure',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                  ),
                ),
                const SizedBox(height: 24),

                // List container (Screenshot 3)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3C4043)
                          : const Color(0xFFDADCE0),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Row 1: 2-Step Verification
                      InkWell(
                        onTap: () {
                          final is2Fa = ref.read(settingsProvider).settings?.twoFactorEnabled ?? false;
                          _open2FAManagement(isDark, is2Fa);
                        },
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 22,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF5F6368),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final is2Fa = ref.watch(settingsProvider).settings?.twoFactorEnabled ?? false;
                                        return Row(
                                          children: [
                                            Text(
                                              '2-Step Verification',
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF202124),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: is2Fa
                                                    ? const Color(0xFFE6F4EA)
                                                    : (isDark ? const Color(0xFF3C4043) : const Color(0xFFF1F3F4)),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                is2Fa ? 'On' : 'Off',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: is2Fa
                                                      ? const Color(0xFF137333)
                                                      : (isDark ? Colors.white70 : const Color(0xFF5F6368)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 3),
                                    Builder(
                                      builder: (context) {
                                        final is2Fa = ref.watch(settingsProvider).settings?.twoFactorEnabled ?? false;
                                        return Text(
                                          is2Fa
                                              ? 'Your account is protected with 2-step verification.'
                                              : 'Protect your account with an extra layer of security.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.white60
                                                : const Color(0xFF5F6368),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_is2faLoading)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Builder(
                                  builder: (context) {
                                    final is2Fa = ref.watch(settingsProvider).settings?.twoFactorEnabled ?? false;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF5F6368)
                                              : const Color(0xFFDADCE0),
                                        ),
                                      ),
                                      child: Text(
                                        is2Fa ? 'Manage' : 'Set up',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A73E8),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? const Color(0xFF3C4043)
                            : const Color(0xFFE8EAED),
                      ),

                      // Row 2: Password
                      InkWell(
                        onTap: () => _openChangePasswordDialog(isDark),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(11),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.vpn_key_outlined,
                                size: 22,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF5F6368),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF202124),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Change your account password',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF5F6368),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF5F6368),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHomeCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget middleWidget,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24272B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Icon
                Icon(icon, size: 30, color: const Color(0xFF1A73E8)),
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Middle Interactive Element
                middleWidget,
                const SizedBox(height: 20),

                // Divider
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF3C4043) : const Color(0xFFE8EAED),
                ),
                const SizedBox(height: 16),

                // Action Link
                Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A73E8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. PERSONAL INFO TAB (Screenshots 3, 4, 5)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPersonalInfoTab(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    final firstName =
        account.name.isNotEmpty ? account.name.split(' ').first : 'Ravi';

    final displayName = account.name.isNotEmpty ? account.name : 'Ravi Kumar C';

    final dobText = account.dob != null
        ? '${account.dob!.day}/${account.dob!.month}/${account.dob!.year}'
        : 'Not set';

    final primaryEmail = account.email.isNotEmpty
        ? account.email
        : 'ravinew2004@bnxmail.com';

    final recoveryEmail = (account.recoveryEmail != null &&
            account.recoveryEmail!.isNotEmpty)
        ? account.recoveryEmail!
        : 'chandran123@bnxmail.com';

    final phone = (account.phone != null && account.phone!.isNotEmpty)
        ? account.phone!
        : '8072909876';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Header (Screenshot 3: No avatar above title on Personal info)
        Center(
          child: Column(
            children: [
              Text(
                'Welcome, $firstName',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your info, privacy, and security to make B2Auth work better for you.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // CARD 1: Basic info (Screenshot 3)
        _buildInfoCard(
          isDark: isDark,
          title: 'Basic info',
          subtitle:
              'Some info may be visible to other people using BNX services. Click any row to update.',
          children: [
            // PHOTO ROW (Exact match to Screenshot 3)
            _buildPhotoRow(account, displayName, isDark),

            // NAME ROW
            _SettingRow(
              isDark: isDark,
              icon: Icons.person_outline_rounded,
              label: 'NAME',
              value: displayName,
              onTap: () => _editFullName(account),
            ),

            // NICKNAME ROW
            _SettingRow(
              isDark: isDark,
              icon: Icons.person_outline_rounded,
              label: 'NICKNAME',
              value: _nickname,
              onTap: () => _editNickname(account),
            ),

            // DISPLAY NAME ROW
            _SettingRow(
              isDark: isDark,
              icon: Icons.person_outline_rounded,
              label: 'DISPLAY NAME',
              value: _displayName,
              onTap: () => _editDisplayName(account),
            ),

            // BIRTHDAY ROW
            _SettingRow(
              isDark: isDark,
              icon: Icons.calendar_today_outlined,
              label: 'BIRTHDAY',
              value: dobText,
              onTap: () => _selectBirthday(account),
            ),

            // GENDER ROW
            _SettingRow(
              isDark: isDark,
              icon: Icons.sentiment_satisfied_outlined,
              label: 'GENDER',
              value: _gender,
              onTap: () => _selectGender(account),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // CARD 2: Contact info (Screenshot 4)
        _buildInfoCard(
          isDark: isDark,
          title: 'Contact info',
          subtitle:
              'Your contact information used for communication and recovery. Click to edit.',
          children: [
            // PRIMARY EMAIL (Screenshot 4: No chevron)
            _SettingRow(
              isDark: isDark,
              icon: Icons.mail_outline_rounded,
              label: 'PRIMARY EMAIL',
              showChevron: false,
              valueWidget: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    primaryEmail,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF133E24)
                          : const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Primary',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF137333),
                      ),
                    ),
                  ),
                ],
              ),
              showDivider: true,
            ),

            // RECOVERY EMAIL
            _SettingRow(
              isDark: isDark,
              icon: Icons.mail_outline_rounded,
              label: 'RECOVERY EMAIL',
              value: recoveryEmail,
              onTap: () => _editRecoveryEmail(account),
            ),

            // PHONE NUMBER
            _SettingRow(
              isDark: isDark,
              icon: Icons.phone_outlined,
              label: 'PHONE NUMBER',
              value: phone,
              onTap: () => _editPhone(account),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // CARD 3: Addresses (Screenshots 4 & 5)
        _buildInfoCard(
          isDark: isDark,
          title: 'Addresses',
          subtitle:
              'Your physical addresses for billing and shipping. Click to edit.',
          children: [
            // HOME ADDRESS (Screenshot 5: Hover turns circle solid blue & chevron blue)
            _SettingRow(
              isDark: isDark,
              icon: Icons.location_on_outlined,
              label: 'HOME ADDRESS',
              value: _homeAddress,
              onTap: () => _editAddress(true, account),
            ),

            // WORK ADDRESS
            _SettingRow(
              isDark: isDark,
              icon: Icons.location_on_outlined,
              label: 'WORK ADDRESS',
              value: _workAddress,
              onTap: () => _editAddress(false, account),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // CARD 4: About me (Screenshot 5)
        _buildInfoCard(
          isDark: isDark,
          title: 'About me',
          subtitle: 'Your profile description and occupation. Click to edit.',
          children: [
            // OCCUPATION
            _SettingRow(
              isDark: isDark,
              icon: Icons.work_outline_rounded,
              label: 'OCCUPATION',
              value: _occupation,
              onTap: () => _editOccupation(account),
            ),

            // BIO
            _SettingRow(
              isDark: isDark,
              icon: Icons.notes_rounded,
              label: 'BIO',
              value: _bio,
              onTap: () => _editBio(account),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHOTO ROW (Exact match to Screenshot 3)
  // Left: Camera circle | Column: "PHOTO" -> Row with [Avatar, CHANGE PHOTO, Remove]
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPhotoRow(AccountModel account, String displayName, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Light Blue Circle Icon Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2A4A)
                      : const Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF1A73E8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PHOTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF5F6368),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Avatar + CHANGE PHOTO + Remove Buttons
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        AvatarWidget(
                          name: displayName,
                          avatarUrl: account.avatarUrl,
                          size: 44,
                          fontSize: 18,
                        ),
                        OutlinedButton(
                          onPressed: _isLoading ? null : _pickAndUploadPhoto,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white70
                                : const Color(0xFF3C4043),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF5F6368)
                                  : const Color(0xFFDADCE0),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  (account.avatarUrl != null &&
                                          account.avatarUrl!.isNotEmpty)
                                      ? 'CHANGE PHOTO'
                                      : 'ADD PHOTO',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                        if (account.avatarUrl != null &&
                            account.avatarUrl!.isNotEmpty)
                          OutlinedButton(
                            onPressed: _isLoading ? null : _removePhoto,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD93025),
                              side: const BorderSide(
                                color: Color(0xFFF28B82),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? const Color(0xFF3C4043) : const Color(0xFFE8EAED),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD CONTAINER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInfoCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24272B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white60 : const Color(0xFF5F6368),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. PAYMENT & SUBSCRIPTION TAB (Image 1: Cliks Business Subscription)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaymentAndSubscriptionTab(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    final firstName =
        account.name.isNotEmpty ? account.name.split(' ').first : 'Ravi';
    final billedEmail = account.email.isNotEmpty
        ? account.email
        : 'ravinew2004@bnxmail.com';

    final planName = _subscriptionData?['plan_name']?.toString() ??
        (_isLoadingSubscription ? 'Loading plan...' : 'Free Plan');
    final rawDays = _subscriptionData?['subscription_days_remaining'];
    final int? daysRemaining = (rawDays is num) ? rawDays.toInt() : null;
    final isActive = daysRemaining != null && daysRemaining > 0;

    String subscribedDate = 'Not available';
    final rawSubDate = _subscriptionData?['when_subscribed'];
    if (rawSubDate != null) {
      final parsed = DateTime.tryParse(rawSubDate.toString());
      if (parsed != null) {
        subscribedDate = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      } else {
        subscribedDate = rawSubDate.toString();
      }
    }

    String nextDueDate = 'Not available';
    final rawDueDate = _subscriptionData?['next_due_date'];
    if (rawDueDate != null) {
      final parsed = DateTime.tryParse(rawDueDate.toString());
      if (parsed != null) {
        nextDueDate = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      } else {
        nextDueDate = rawDueDate.toString();
      }
    }

    final String daysRemainingText = isActive
        ? '$daysRemaining days remaining'
        : (daysRemaining == 0 ? 'Cycle expired' : 'No active cycle');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top Profile Avatar (Image 1)
        AvatarWidget(
          name: account.name.isNotEmpty ? account.name : 'Ravi Kumar C',
          avatarUrl: account.avatarUrl,
          size: 84,
          fontSize: 34,
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome, $firstName',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF202124),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your info, privacy, and security to make B2Auth work better for you.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : const Color(0xFF5F6368),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        // Main Subscription Card (Image 1)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24272B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cliks Business Subscription',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  if (_isLoadingSubscription)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your active Cliks Business subscriptions and billing details.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                ),
              ),
              const SizedBox(height: 20),

              // Nested Blue Container
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B2A4A)
                      : const Color(0xFFE8F2FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2B4272)
                        : const Color(0xFFD6E6F9),
                  ),
                ),
                child: Column(
                  children: [
                    // Top Section
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ACTIVE PLAN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A73E8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                planName,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF202124),
                                ),
                              ),
                            ],
                          ),
                          // Active / Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (isDark
                                      ? const Color(0xFF133E24)
                                      : Colors.white)
                                  : (isDark
                                      ? const Color(0xFF3C4043)
                                      : const Color(0xFFF1F3F4)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF1E8E3E)
                                    : (isDark
                                        ? const Color(0xFF5F6368)
                                        : const Color(0xFFDADCE0)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.info_outline_rounded,
                                  color: isActive
                                      ? const Color(0xFF1E8E3E)
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF5F6368)),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isActive
                                      ? 'Active'
                                      : (daysRemaining == 0 ? 'Expired' : 'Free'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? const Color(0xFF1E8E3E)
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF5F6368)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom White Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24272B) : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSubDetailItem(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'SUBSCRIBED ON',
                                  value: subscribedDate,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildSubDetailItem(
                                  icon: Icons.access_time_rounded,
                                  label: 'NEXT DUE DATE',
                                  value: nextDueDate,
                                  extra: daysRemainingText,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),
                                _buildSubDetailItem(
                                  label: 'BILLED TO',
                                  value: billedEmail,
                                  isDark: isDark,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildSubDetailItem(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'SUBSCRIBED ON',
                                    value: subscribedDate,
                                    isDark: isDark,
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubDetailItem(
                                    icon: Icons.access_time_rounded,
                                    label: 'NEXT DUE DATE',
                                    value: nextDueDate,
                                    extra: daysRemainingText,
                                    isDark: isDark,
                                  ),
                                ),
                                Expanded(
                                  child: _buildSubDetailItem(
                                    label: 'BILLED TO',
                                    value: billedEmail,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),

              if (!isActive) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2417)
                        : const Color(0xFFFEF7E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF6B4E17)
                          : const Color(0xFFFEEFC3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFE37400),
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upgrade your Cliks Business plan',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF202124),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unlock custom domains, multi-mailbox management, and team Sub-IDs.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Redirecting to Cliks Business billing portal...'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE37400),
                        ),
                        child: const Text('Upgrade'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSubDetailItem({
    IconData? icon,
    required String label,
    required String value,
    String? extra,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white60 : const Color(0xFF5F6368),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (extra != null) ...[
                const SizedBox(height: 2),
                Text(
                  extra,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD93025),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. TEAM & SUB-IDS TAB (Image 2: Table + "+ Create Sub-ID" button)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTeamAndSubIdsTab(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    final firstName =
        account.name.isNotEmpty ? account.name.split(' ').first : 'Ravi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top Avatar circle (Image 2)
        AvatarWidget(
          name: account.name.isNotEmpty ? account.name : 'Ravi Kumar C',
          avatarUrl: account.avatarUrl,
          size: 84,
          fontSize: 34,
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome, $firstName',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF202124),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your info, privacy, and security to make B2Auth work better for you.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : const Color(0xFF5F6368),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        // Header Row: Team & Sub-IDs + "+ Create Sub-ID" button
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team & Sub-IDs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage isolated Sub-IDs and delegate access.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openCreateSubIdDialog(account, isDark),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Create Sub-ID',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team & Sub-IDs',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage isolated Sub-IDs and delegate access.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _openCreateSubIdDialog(account, isDark),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Create Sub-ID',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),

        // Table Container (Image 2)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24272B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF3C4043) : const Color(0xFFE8EAED),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: () {
            final tableContent = Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2124)
                      : const Color(0xFFF8F9FA),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF3C4043)
                          : const Color(0xFFE8EAED),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Type',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 50,
                      child: Text(
                        'Actions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isLoadingSubIds)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

              // Rows
              if (!_isLoadingSubIds && _apiSubIds.isEmpty && _subIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No sub-IDs created yet.',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                    ),
                  ),
                )
              else if (!_isLoadingSubIds)
                ...() {
                  final activeList = _apiSubIds.isNotEmpty
                      ? _apiSubIds
                      : _subIds.map((e) => Map<String, dynamic>.from(e)).toList();

                  return List.generate(activeList.length, (index) {
                    final item = activeList[index];
                    final isLast = index == activeList.length - 1;
                    final username = item['username']?.toString() ??
                        item['email']?.toString() ??
                        '';
                    final name = item['name']?.toString() ??
                        ('${item['firstName'] ?? ''} ${item['lastName'] ?? ''}')
                            .trim();
                    final type = item['accountType']?.toString() ??
                        item['type']?.toString() ??
                        'MANAGED';
                    final isApproved = item['approved'] == true;
                    final subId = item['id'];

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF3C4043)
                                      : const Color(0xFFE8EAED),
                                ),
                              ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              username,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF202124),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              name.isNotEmpty ? name : 'Sub-Account',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF202124),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1A2A4A)
                                      : const Color(0xFFE8F0FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  type,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A73E8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: isApproved
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F4EA),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Approved',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF137333),
                                        ),
                                      ),
                                    )
                                  : (subId != null
                                      ? OutlinedButton(
                                          onPressed: () =>
                                              _approveChildAccount(subId),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            visualDensity:
                                                VisualDensity.compact,
                                            side: const BorderSide(
                                                color: Color(0xFF1A73E8)),
                                          ),
                                          child: const Text(
                                            'Approve',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A73E8),
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Active',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF137333),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: Color(0xFF5F6368),
                              ),
                              tooltip: 'Delete Sub-ID',
                              onPressed: () => _confirmDeleteSubId(item),
                            ),
                          ),
                        ],
                      ),
                    );
                  });
                }(),
              ],
            );
            return isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: 580,
                      child: tableContent,
                    ),
                  )
                : tableContent;
          }(),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  void _openCreateSubIdDialog(AccountModel account, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateSubIdDialog(
        account: account,
        isDark: isDark,
        onCreated: (newSubId) {
          _loadSubIds();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Sub-ID ${newSubId['username']} created successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E8E3E),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteSubId(Map<String, dynamic> item) async {
    final rawId = item['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final username = item['username']?.toString() ??
        item['email']?.toString() ??
        'this Sub-ID';

    print('[SUBID DELETE] Selected Sub-ID: $item');
    print('[SUBID DELETE] ID: $id');
    print('[SUBID DELETE] Username: $username');

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to delete this Sub-ID because its ID is missing.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sub-ID'),
        content: Text('Are you sure you want to delete $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('[SUBID DELETE] Calling DELETE endpoint for ID: $id');
        await UserRepository.deleteSubId(id);
        print('[SUBID DELETE] Successfully deleted Sub-ID ID: $id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sub-ID $username deleted successfully'),
              backgroundColor: const Color(0xFF1E8E3E),
              behavior: SnackBarBehavior.floating,
            ),
          );
          print('[SUBID DELETE] Refreshing Sub-ID list:');
          await _loadSubIds();
        }
      } catch (e) {
        print('[SUBID DELETE ERROR] $e');
        if (mounted) {
          final errorMessage = e is ApiException ? e.message : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete Sub-ID: $errorMessage'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. ACCOUNT STORAGE TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAccountStorageTab(
    AccountModel account,
    bool isDark,
    bool isMobile,
  ) {
    final quota = _storageQuota;
    final fraction = quota != null ? quota.fraction : 0.0;
    final usedText = quota != null
        ? '${quota.usedFormatted} of ${quota.limitFormatted} used (${quota.percentageFormatted})'
        : (_isLoadingStorageQuota ? 'Loading storage quota...' : 'Storage details unavailable');
    final mailValue = quota != null ? quota.usedFormatted : '0 MB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          isDark: isDark,
          title: 'Account storage',
          subtitle:
              'Storage used across BNX services like Mail, Drive, and Media.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _isLoadingStorageQuota ? null : fraction,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? const Color(0xFF3C4043)
                          : const Color(0xFFE8EAED),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        quota != null ? quota.statusColor : const Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        usedText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF202124),
                        ),
                      ),
                      if (quota != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: quota.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            quota.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: quota.statusColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            _SettingRow(
              isDark: isDark,
              icon: Icons.mail_outline_rounded,
              label: 'BNX MAIL',
              value: mailValue,
            ),
            _SettingRow(
              isDark: isDark,
              icon: Icons.cloud_outlined,
              label: 'BNX DRIVE',
              value: '0 MB',
            ),
            _SettingRow(
              isDark: isDark,
              icon: Icons.perm_media_outlined,
              label: 'MEDIA & BACKUPS',
              value: '0 MB',
              showDivider: false,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/storage'),
              icon: const Icon(Icons.storage_rounded, size: 18),
              label: const Text('Open Storage Manager'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. B2AUTH TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildB2AuthTab(AccountModel account, bool isDark, bool isMobile) {
    final is2Fa = ref.watch(settingsProvider).settings?.twoFactorEnabled ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          isDark: isDark,
          title: 'Account & Security',
          subtitle: 'Security checkup and recommendations for your account.',
          children: [
            _SettingRow(
              isDark: isDark,
              icon: Icons.security_rounded,
              label: '2-STEP VERIFICATION',
              valueWidget: Row(
                children: [
                  Text(is2Fa ? 'On' : 'Off'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: is2Fa
                          ? const Color(0xFFE6F4EA)
                          : (isDark ? const Color(0xFF3C4043) : const Color(0xFFF1F3F4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      is2Fa ? 'Secured' : 'Recommended',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: is2Fa
                            ? const Color(0xFF137333)
                            : const Color(0xFFE37400),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => _open2FAManagement(isDark, is2Fa),
            ),
            _SettingRow(
              isDark: isDark,
              icon: Icons.key_rounded,
              label: 'PASSKEYS & SECURITY KEYS',
              value: '1 passkey registered',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passkeys are synchronized with your device security settings.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _SettingRow(
              isDark: isDark,
              icon: Icons.password_rounded,
              label: 'PASSWORD',
              value: 'Change password',
              onTap: () => _openChangePasswordDialog(isDark),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS & ACTION HANDLERS (Safe frontend data updates)
  // ═══════════════════════════════════════════════════════════════════════════
  void _editFullName(AccountModel account) {
    final controller = TextEditingController(text: account.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Full Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                final parts = newName.split(' ');
                final first = parts.first;
                final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                await UserRepository.updateProfile({
                  'firstName': first,
                  'lastName': last,
                  'name': newName,
                  'fullName': newName,
                }, email: account.email);
                await ref
                    .read(accountsProvider.notifier)
                    .updateAccountFields(account.id, name: newName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editNickname([AccountModel? account]) {
    final targetEmail = account?.email ?? ref.read(activeAccountProvider).email;
    final controller = TextEditingController(
      text: _nickname == 'Not set' ? '' : _nickname,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Nickname'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = controller.text.trim();
              setState(() {
                _nickname = val.isEmpty ? 'Not set' : val;
              });
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'nickname': val},
                  email: targetEmail);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editDisplayName([AccountModel? account]) {
    final targetEmail = account?.email ?? ref.read(activeAccountProvider).email;
    final controller = TextEditingController(
      text: _displayName == 'Not set' ? '' : _displayName,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = controller.text.trim();
              setState(() {
                _displayName = val.isEmpty ? 'Not set' : val;
              });
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'displayName': val},
                  email: targetEmail);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _selectBirthday(AccountModel account) async {
    final initialDate = account.dob ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await UserRepository.updateProfile(
        {'dob': picked.toIso8601String(), 'birthday': picked.toIso8601String()},
        email: account.email,
      );
      await ref
          .read(accountsProvider.notifier)
          .updateAccountFields(account.id, dob: picked);
    }
  }

  void _selectGender([AccountModel? account]) {
    final targetEmail = account?.email ?? ref.read(activeAccountProvider).email;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Gender'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              setState(() => _gender = 'Female');
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'gender': 'Female'},
                  email: targetEmail);
            },
            child: const Text('Female'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              setState(() => _gender = 'Male');
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'gender': 'Male'},
                  email: targetEmail);
            },
            child: const Text('Male'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              setState(() => _gender = 'Non-binary');
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'gender': 'Non-binary'},
                  email: targetEmail);
            },
            child: const Text('Non-binary'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              setState(() => _gender = 'Rather not say');
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'gender': 'Rather not say'},
                  email: targetEmail);
            },
            child: const Text('Rather not say'),
          ),
        ],
      ),
    );
  }

  void _editRecoveryEmail(AccountModel account) {
    final controller = TextEditingController(
      text: account.recoveryEmail ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Recovery Email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Recovery Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newEmail = controller.text.trim();
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'recoveryEmail': newEmail}, email: account.email);
              await ref
                  .read(accountsProvider.notifier)
                  .updateAccountFields(account.id, recoveryEmail: newEmail);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editPhone(AccountModel account) {
    final controller = TextEditingController(
      text: account.phone ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Phone Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newPhone = controller.text.trim();
              Navigator.pop(ctx);
              await UserRepository.updateProfile({
                'phoneNumber': newPhone,
                'phone': newPhone,
              }, email: account.email);
              await ref
                  .read(accountsProvider.notifier)
                  .updateAccountFields(account.id, phone: newPhone);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editAddress(bool isHome, [AccountModel? account]) {
    final targetEmail = account?.email ?? ref.read(activeAccountProvider).email;
    final controller = TextEditingController(
      text: isHome
          ? (_homeAddress == 'None added' ? '' : _homeAddress)
          : (_workAddress == 'None added' ? '' : _workAddress),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHome ? 'Update Home Address' : 'Update Work Address'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isHome ? 'Home Address' : 'Work Address',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = controller.text.trim();
              setState(() {
                if (isHome) {
                  _homeAddress = val.isEmpty ? 'None added' : val;
                } else {
                  _workAddress = val.isEmpty ? 'None added' : val;
                }
              });
              Navigator.pop(ctx);
              await UserRepository.updateProfile({
                isHome ? 'homeAddress' : 'workAddress': val,
              }, email: targetEmail);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editOccupation([AccountModel? account]) {
    final targetEmail = account?.email ?? ref.read(activeAccountProvider).email;
    final controller = TextEditingController(
      text: _occupation == 'None added' ? '' : _occupation,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Occupation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Occupation',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = controller.text.trim();
              setState(() {
                _occupation = val.isEmpty ? 'None added' : val;
              });
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'occupation': val},
                  email: targetEmail);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editBio([AccountModel? account]) {
    final targetEmail = account?.email ?? ref.read(activeAccountProvider).email;
    final controller = TextEditingController(
      text: _bio == 'Write a brief description about yourself' ? '' : _bio,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Bio'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Bio',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = controller.text.trim();
              setState(() {
                _bio = val.isEmpty
                    ? 'Write a brief description about yourself'
                    : val;
              });
              Navigator.pop(ctx);
              await UserRepository.updateProfile({'bio': val},
                  email: targetEmail);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'Are you sure you want to sign out of this account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final activeAccount = ref.read(activeAccountProvider);
      final activeEmail = activeAccount.email.isNotEmpty
          ? activeAccount.email
          : activeAccount.id;
      await ref.read(accountsProvider.notifier).signOutSingleAccount(
            targetEmail: activeEmail,
            ref: ref,
            context: context,
          );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// INTERACTIVE SETTING ROW WITH HOVER SUPPORT (Screenshots 3, 4, 5)
// In Screenshot 5: Hover turns circle badge solid blue with white icon & blue chevron
// ═════════════════════════════════════════════════════════════════════════════
class _SettingRow extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool showDivider;

  const _SettingRow({
    required this.isDark,
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.onTap,
    this.showChevron = true,
    this.showDivider = true,
  });

  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasClick = widget.onTap != null;

    final badgeBgColor = _isHovered && hasClick
        ? const Color(0xFF1A73E8)
        : (widget.isDark ? const Color(0xFF1A2A4A) : const Color(0xFFE8F0FE));

    final badgeIconColor = _isHovered && hasClick
        ? Colors.white
        : const Color(0xFF1A73E8);

    final chevronColor = _isHovered && hasClick
        ? const Color(0xFF1A73E8)
        : (widget.isDark ? Colors.white38 : const Color(0xFF5F6368));

    return Column(
      children: [
        MouseRegion(
          cursor: hasClick ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) {
            if (hasClick) setState(() => _isHovered = true);
          },
          onExit: (_) {
            if (hasClick) setState(() => _isHovered = false);
          },
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: _isHovered && hasClick
                    ? (widget.isDark
                        ? const Color(0xFF2E3238)
                        : const Color(0xFFF8F9FA))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Icon Circle Badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: badgeIconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Content Column (Upper Label, Lower Value)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white60
                                : const Color(0xFF5F6368),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (widget.valueWidget != null)
                          widget.valueWidget!
                        else
                          Text(
                            widget.value ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF202124),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Trailing Chevron
                  if (widget.showChevron && hasClick)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: chevronColor,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            color: widget.isDark
                ? const Color(0xFF3C4043)
                : const Color(0xFFE8EAED),
          ),
      ],
    );
  }
}

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

// ═════════════════════════════════════════════════════════════════════════════
// CREATE SUB-ID MODAL DIALOG (Modern & Professional)
// ═════════════════════════════════════════════════════════════════════════════
class _CreateSubIdDialog extends StatefulWidget {
  final AccountModel account;
  final bool isDark;
  final ValueChanged<Map<String, String>> onCreated;

  const _CreateSubIdDialog({
    required this.account,
    required this.isDark,
    required this.onCreated,
  });

  @override
  State<_CreateSubIdDialog> createState() => _CreateSubIdDialogState();
}

class _CreateSubIdDialogState extends State<_CreateSubIdDialog> {
  String _accountType = 'Business (Employee / Team)';
  final _prefixController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  final List<_CategoryData> _categories = [
    _CategoryData(
      title: 'Finance',
      icon: Icons.attach_money_rounded,
      subItems: const [
        _SubItemData(title: 'Accounting', id: 201),
        _SubItemData(title: 'Expenses', id: 202),
        _SubItemData(title: 'Tax', id: 203),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'Sales',
      icon: Icons.shopping_cart_outlined,
      subItems: const [
        _SubItemData(title: 'Sales Invoice', id: 210),
        _SubItemData(title: 'Customers', id: 211),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'Purchases',
      icon: Icons.shopping_cart_outlined,
      subItems: const [
        _SubItemData(title: 'Purchase Invoice', id: 212),
        _SubItemData(title: 'Suppliers', id: 213),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'Inventory',
      icon: Icons.inventory_2_outlined,
      subItems: const [
        _SubItemData(title: 'Products', id: 214),
        _SubItemData(title: 'Stock', id: 215),
        _SubItemData(title: 'Warehouse', id: 216),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'HR',
      icon: Icons.people_outline_rounded,
      subItems: const [
        _SubItemData(title: 'Staff', id: 220),
        _SubItemData(title: 'Attendance', id: 221),
        _SubItemData(title: 'Payroll', id: 222),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'POS Billing',
      icon: Icons.desktop_windows_outlined,
      subItems: const [
        _SubItemData(title: 'POS Billing', id: 223),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'Reports',
      icon: Icons.description_outlined,
      subItems: const [
        _SubItemData(title: 'Reports', id: 224),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'Barcode Gen',
      icon: Icons.local_offer_outlined,
      subItems: const [
        _SubItemData(title: 'Barcode Gen', id: 225),
      ],
      isExpanded: true,
    ),
    _CategoryData(
      title: 'Marketing',
      icon: Icons.local_offer_outlined,
      subItems: const [
        _SubItemData(title: 'Marketing', id: 226),
      ],
      isExpanded: true,
    ),
  ];

  final Set<int> _checkedSubItems = {};

  @override
  void dispose() {
    _prefixController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isCategoryChecked(_CategoryData cat) {
    if (cat.subItems.isEmpty) return false;
    return cat.subItems.every((item) => _checkedSubItems.contains(item.id));
  }

  void _toggleCategory(_CategoryData cat) {
    final allChecked = _isCategoryChecked(cat);
    setState(() {
      for (final item in cat.subItems) {
        if (allChecked) {
          _checkedSubItems.remove(item.id);
        } else {
          _checkedSubItems.add(item.id);
        }
      }
    });
  }

  void _toggleSubItem(_SubItemData item) {
    setState(() {
      if (_checkedSubItems.contains(item.id)) {
        _checkedSubItems.remove(item.id);
      } else {
        _checkedSubItems.add(item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final suffixEmail = widget.account.email.isNotEmpty
        ? widget.account.email
        : 'chandran123@bnxmail.com';

    final surfaceColor = isDark ? const Color(0xFF23262B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF383C44) : const Color(0xFFE2E4E8);

    return Dialog(
      backgroundColor: surfaceColor,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 750,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row with Title and Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Sub-ID',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF1E2124),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Configure account access and assign isolated permissions.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                      ),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, thickness: 1, color: borderColor),
                const SizedBox(height: 18),

                // Main Content (Two Columns Layout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLeftFields(suffixEmail, isDark),
                          const SizedBox(height: 20),
                          _buildRightPermissions(isDark, 310),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column Form
                        Expanded(
                          flex: 11,
                          child: _buildLeftFields(suffixEmail, isDark),
                        ),
                        const SizedBox(width: 20),

                        // Right Column: Big Centre Sub Tab (330px height)
                        Expanded(
                          flex: 12,
                          child: _buildRightPermissions(isDark, 330),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),
                Divider(height: 1, thickness: 1, color: borderColor),
                const SizedBox(height: 16),

                // Bottom Action Buttons (Directly below content, zero blank gap!)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : const Color(0xFF5F6368),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Sub-ID',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftFields(String suffixEmail, bool isDark) {
    final borderSide = BorderSide(
      color: isDark ? const Color(0xFF383C44) : const Color(0xFFD1D5DB),
      width: 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account Type
        _buildFieldLabel('Account Type', isDark),
        const SizedBox(height: 6),
        PopupMenuButton<String>(
          tooltip: 'Select Account Type',
          offset: const Offset(0, 42),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isDark ? const Color(0xFF383C44) : const Color(0xFFD1D5DB),
            ),
          ),
          color: isDark ? const Color(0xFF24272B) : Colors.white,
          onSelected: (val) {
            setState(() => _accountType = val);
          },
          itemBuilder: (context) => [
            _buildAccountTypeItem(
              title: 'Business (Employee / Team)',
              isSelected: _accountType == 'Business (Employee / Team)',
              isDark: isDark,
            ),
            _buildAccountTypeItem(
              title: 'Personal (Assistant / Family)',
              isSelected: _accountType == 'Personal (Assistant / Family)',
              isDark: isDark,
            ),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1E22) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF383C44) : const Color(0xFFD1D5DB),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _accountType,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E2124),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 19,
                  color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Username Prefix
        _buildFieldLabel('Username Prefix', isDark),
        const SizedBox(height: 6),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1E22) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF383C44) : const Color(0xFFD1D5DB),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prefixController,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF1E2124),
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. hr',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : const Color(0xFF9AA0A6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181A1D) : const Color(0xFFF1F3F5),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                    border: Border(left: borderSide),
                  ),
                  child: Text(
                    '.$suffixEmail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // First Name & Last Name (Side by Side)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('First Name', isDark),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _firstNameController,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E2124),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1B1E22) : Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: borderSide,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: borderSide,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Last Name', isDark),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _lastNameController,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E2124),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1B1E22) : Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: borderSide,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: borderSide,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Temporary Password (with toggle visibility)
        _buildFieldLabel('Temporary Password', isDark),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF1E2124),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF1B1E22) : Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: isDark ? Colors.white54 : const Color(0xFF757575),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                splashRadius: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: borderSide,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: borderSide,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildAccountTypeItem({
    required String title,
    required bool isSelected,
    required bool isDark,
  }) {
    return PopupMenuItem<String>(
      value: title,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: isDark ? Colors.white : const Color(0xFF1A73E8),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isDark ? Colors.white : const Color(0xFF1E2124),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BIG CENTRE SUB-TAB: ACCESS PERMISSIONS (330px height, modern scroll list)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRightPermissions(bool isDark, double height) {
    final borderColor = isDark ? const Color(0xFF383C44) : const Color(0xFFD1D5DB);
    final boxBgColor = isDark ? const Color(0xFF1B1E22) : const Color(0xFFFAFBFD);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel('Access Permissions', isDark),
            if (_checkedSubItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2A4A) : const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_checkedSubItems.length} selected',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A73E8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: boxBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? const Color(0xFF2C3036) : const Color(0xFFEDEFF2),
              ),
              itemBuilder: (context, catIndex) {
                final cat = _categories[catIndex];
                final isCatChecked = _isCategoryChecked(cat);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header
                    InkWell(
                      onTap: () {
                        setState(() {
                          cat.isExpanded = !cat.isExpanded;
                        });
                      },
                      hoverColor: isDark ? const Color(0xFF252930) : const Color(0xFFF1F5F9),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: isCatChecked,
                                activeColor: const Color(0xFF1A73E8),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (_) => _toggleCategory(cat),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              cat.icon,
                              size: 17,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            Icon(
                              cat.isExpanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_right_rounded,
                              size: 19,
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sub Items
                    if (cat.isExpanded)
                      ...cat.subItems.map((subItem) {
                        final isSubChecked = _checkedSubItems.contains(subItem.id);

                        return Padding(
                          padding: const EdgeInsets.only(left: 28, right: 6, top: 1, bottom: 1),
                          child: InkWell(
                            onTap: () => _toggleSubItem(subItem),
                            hoverColor: isDark ? const Color(0xFF282D36) : const Color(0xFFEBF3FE),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSubChecked
                                    ? (isDark
                                        ? const Color(0xFF1A2A4A).withValues(alpha: 0.3)
                                        : const Color(0xFFEBF3FE).withValues(alpha: 0.6))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: isSubChecked,
                                      activeColor: const Color(0xFF1A73E8),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                      onChanged: (_) => _toggleSubItem(subItem),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subItem.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSubChecked ? FontWeight.w500 : FontWeight.w400,
                                        color: isSubChecked
                                            ? const Color(0xFF1A73E8)
                                            : (isDark ? Colors.white70 : const Color(0xFF374151)),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: isDark ? Colors.white70 : const Color(0xFF374151),
      ),
    );
  }

  Future<void> _submit() async {
    final prefix = _prefixController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = ('$firstName $lastName').trim();

    final baseEmail = widget.account.email.isNotEmpty
        ? widget.account.email
        : 'chandran123@bnxmail.com';

    final username = prefix.isNotEmpty
        ? '$prefix.$baseEmail'
        : 'sales.${baseEmail.split('@').first}';

    if (prefix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Sub-ID prefix'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final perms = _checkedSubItems.toList();

      final res = await UserRepository.createSubId(
        prefix: prefix,
        password: password.isNotEmpty ? password : 'TempPassword123!',
        firstName: firstName.isNotEmpty ? firstName : 'Sub',
        lastName: lastName.isNotEmpty ? lastName : 'User',
        accountType: _accountType.contains('Personal') ? 'PERSONAL' : 'BUSINESS',
        permissions: perms,
      );

      final createdUsername = res?['username']?.toString() ??
          res?['subUsername']?.toString() ??
          username;
      widget.onCreated({
        'username': createdUsername,
        'name': fullName.isNotEmpty ? fullName : 'Sub User',
        'type': _accountType.contains('Personal') ? 'PERSONAL' : 'BUSINESS',
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMessage = e is ApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create Sub-ID: $errorMessage'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SubItemData {
  final String title;
  final int id;

  const _SubItemData({required this.title, required this.id});
}

class _CategoryData {
  final String title;
  final IconData icon;
  final List<_SubItemData> subItems;
  bool isExpanded;

  _CategoryData({
    required this.title,
    required this.icon,
    required this.subItems,
    this.isExpanded = true,
  });
}
