import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/auth_notifier.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/account_provider.dart';
import '../../../../data/email_provider.dart';

class RegisterAccountTypeScreen extends ConsumerStatefulWidget {
  const RegisterAccountTypeScreen({super.key});

  @override
  ConsumerState<RegisterAccountTypeScreen> createState() =>
      _RegisterAccountTypeScreenState();
}

class _RegisterAccountTypeScreenState
    extends ConsumerState<RegisterAccountTypeScreen> {
  int _step = 1; // 1, 2, or 3
  int _personalStep = 1; // 1, 2, or 3 (for personal details split flow)
  int _childStep = 1; // 1 to 4 (for child multi-step flow)
  int _businessStep = 1; // 1 or 2 (for business split flow)
  String _selectedType = 'personal'; // 'personal', 'business', 'child'

  // Validation errors (Personal)
  String? _firstNameError;
  String? _lastNameError;
  String? _usernameError;
  String? _dobError;
  String? _passwordError;
  String? _retypePasswordError;

  // Validation errors (Business)
  String? _businessNameError;
  String? _customDomainError;
  String? _ownerFirstNameError;
  String? _ownerLastNameError;
  String? _adminUsernameError;
  String? _adminPasswordError;
  String? _retypeAdminPasswordError;
  String? _phoneError;

  // Validation errors (Child)
  String? _childFirstNameError;
  String? _childLastNameError;
  String? _childUsernameError;
  String? _childDobError;
  String? _childPasswordError;
  String? _childRetypePasswordError;
  String? _parentEmailError;
  String? _securityAnswerError;

  bool _isRegistering = false;

  // Validation errors (Step 3)
  String? _emailHandleError;

  // Temporary Token & Suggestions State
  String? _tempToken;
  List<String> _usernameSuggestions = [];
  List<String> _emailHandleSuggestions = [];

  // Parent OTP State (Child)
  final _parentOtpController = TextEditingController();
  bool _isSendingParentOtp = false;
  bool _isVerifyingParentOtp = false;
  bool _parentOtpVerified = false;
  String? _parentOtpError;
  String? _parentOtpMessage;

  // Step 2 Controllers (Personal)
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();
  final _retypePasswordController = TextEditingController();
  final _personalPhoneController = TextEditingController();
  String? _personalPhoneError;

  // Step 2 Controllers (Business)
  final _businessNameController = TextEditingController();
  final _customDomainController = TextEditingController();
  final _ownerFirstNameController = TextEditingController();
  final _ownerLastNameController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _retypeAdminPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 2 Controllers (Child)
  final _childFirstNameController = TextEditingController();
  final _childLastNameController = TextEditingController();
  final _childUsernameController = TextEditingController();
  final _childDobController = TextEditingController();
  final _childPasswordController = TextEditingController();
  final _childRetypePasswordController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _securityAnswerController = TextEditingController();
  final String _securityQuestion = 'What is your favorite animal?';
  String _childGender = 'Male';
  String _personalGender = 'Male';

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  // Step 3 Controllers
  final _emailHandleController = TextEditingController();

  // Password visibility state
  bool _obscurePassword = true;
  bool _obscureRetypePassword = true;
  bool _obscureAdminPassword = true;
  bool _obscureRetypeAdminPassword = true;
  bool _obscureChildPassword = true;
  bool _obscureChildRetypePassword = true;

  final List<String> _securityQuestions = [
    'What is your favorite animal?',
    'What is the name of your first pet?',
    'What is your favorite book?',
    'What is the name of your school?',
    'What is your favorite game?',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _retypePasswordController.dispose();
    _personalPhoneController.dispose();

    _businessNameController.dispose();
    _customDomainController.dispose();
    _ownerFirstNameController.dispose();
    _ownerLastNameController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _retypeAdminPasswordController.dispose();
    _phoneController.dispose();

    _childFirstNameController.dispose();
    _childLastNameController.dispose();
    _childUsernameController.dispose();
    _childDobController.dispose();
    _childPasswordController.dispose();
    _childRetypePasswordController.dispose();
    _parentEmailController.dispose();
    _parentOtpController.dispose();
    _securityAnswerController.dispose();

    _emailHandleController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(
      String firstName, String lastName, String dob, bool isStep3) async {
    final suggestions = await AuthRepository.getUsernameSuggestions(
      firstName: firstName,
      lastName: lastName,
      dob: dob,
    );
    if (!mounted) return;
    setState(() {
      if (isStep3) {
        _emailHandleSuggestions = suggestions;
      } else {
        _usernameSuggestions = suggestions;
      }
    });
  }

  Future<void> _sendParentOtp() async {
    final parentEmail = _parentEmailController.text.trim();
    if (parentEmail.isEmpty) {
      setState(() => _parentEmailError = 'Parent Email is required');
      return;
    }
    setState(() {
      _isSendingParentOtp = true;
      _parentOtpError = null;
      _parentOtpMessage = null;
    });
    try {
      await AuthRepository.sendParentOtp(parentEmail);
      if (!mounted) return;
      setState(() {
        _isSendingParentOtp = false;
        _parentOtpMessage = 'OTP sent to $parentEmail';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingParentOtp = false;
        _parentOtpError = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException(400): ', '');
      });
    }
  }

  Future<void> _verifyParentOtp() async {
    final parentEmail = _parentEmailController.text.trim();
    final otp = _parentOtpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _parentOtpError = 'OTP is required');
      return;
    }
    setState(() {
      _isVerifyingParentOtp = true;
      _parentOtpError = null;
    });
    try {
      await AuthRepository.verifyParentOtp(parentEmail, otp);
      if (!mounted) return;
      setState(() {
        _isVerifyingParentOtp = false;
        _parentOtpVerified = true;
        _parentOtpMessage = 'Parent OTP verified successfully!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingParentOtp = false;
        _parentOtpError = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException(400): ', '');
      });
    }
  }

  Future<void> _submitStep2() async {
    final String password = _selectedType == 'business'
        ? _adminPasswordController.text
        : _selectedType == 'child'
            ? _childPasswordController.text
            : _passwordController.text;

    final String firstName = _selectedType == 'business'
        ? _ownerFirstNameController.text.trim()
        : _selectedType == 'child'
            ? _childFirstNameController.text.trim()
            : _firstNameController.text.trim();

    final String lastName = _selectedType == 'business'
        ? _ownerLastNameController.text.trim()
        : _selectedType == 'child'
            ? ''
            : _lastNameController.text.trim();

    final String username = _selectedType == 'business'
        ? _adminUsernameController.text.trim()
        : _selectedType == 'child'
            ? _childUsernameController.text.trim()
            : _usernameController.text.trim();

    final String dob = _selectedType == 'business'
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _selectedType == 'child'
            ? _childDobController.text.trim()
            : _dobController.text.trim();

    setState(() {
      _isRegistering = true;
      _usernameSuggestions = [];
    });

    try {
      final token = await AuthRepository.register(
        mode: _selectedType.toUpperCase(),
        firstName: firstName,
        lastName: lastName,
        username: username,
        password: password,
        dob: dob,
        businessName: _selectedType == 'business'
            ? _businessNameController.text.trim()
            : null,
        customDomain: _selectedType == 'business'
            ? _customDomainController.text.trim()
            : null,
        parentEmail: _selectedType == 'child'
            ? _parentEmailController.text.trim()
            : null,
        securityQuestion:
            _selectedType == 'child' ? _securityQuestion : null,
        securityAnswer: _selectedType == 'child'
            ? _securityAnswerController.text.trim()
            : null,
      );

      if (!mounted) return;

      setState(() {
        _tempToken = token;
        _isRegistering = false;
        _step = 3;
        _emailHandleController.text = username;
        _emailHandleError = null;
        _emailHandleSuggestions = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegistering = false);
      final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException(400): ', '');

      if (errorMsg.toLowerCase().contains('username') ||
          errorMsg.toLowerCase().contains('exists') ||
          errorMsg.toLowerCase().contains('taken')) {
        setState(() {
          if (_selectedType == 'business') {
            _adminUsernameError = 'Username is already taken';
          } else if (_selectedType == 'child') {
            _childUsernameError = 'Username is already taken';
          } else {
            _usernameError = 'Username is already taken';
          }
        });
        await _fetchSuggestions(firstName, lastName, dob, false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: $errorMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _submitStep3() async {
    final handle = _emailHandleController.text.trim();
    setState(() {
      _emailHandleError = handle.isEmpty ? 'Email Handle is required' : null;
    });

    if (_emailHandleError != null) return;

    if (_tempToken == null || _tempToken!.isEmpty) {
      await _submitStep2();
      if (_tempToken == null || _tempToken!.isEmpty) return;
    }

    setState(() {
      _isRegistering = true;
      _emailHandleSuggestions = [];
    });

    final String password = _selectedType == 'business'
        ? _adminPasswordController.text
        : _selectedType == 'child'
            ? _childPasswordController.text
            : _passwordController.text;

    final String firstName = _selectedType == 'business'
        ? _ownerFirstNameController.text.trim()
        : _selectedType == 'child'
            ? _childFirstNameController.text.trim()
            : _firstNameController.text.trim();

    final String lastName = _selectedType == 'business'
        ? _ownerLastNameController.text.trim()
        : _selectedType == 'child'
            ? ''
            : _lastNameController.text.trim();

    final String dob = _selectedType == 'business'
        ? DateTime.now().toIso8601String().substring(0, 10)
        : _selectedType == 'child'
            ? _childDobController.text.trim()
            : _dobController.text.trim();

    final cleanHandle = handle.contains('@') ? handle.split('@').first : handle;

    try {
      await AuthRepository.createMailbox(
        tempToken: _tempToken!,
        emailName: cleanHandle,
        password: password,
        isPrimary: true,
      );

      if (!mounted) return;

      ref.read(authProvider.notifier).login();
      context.go('/home');
      ref.read(accountsProvider.notifier).loadMailboxes();
      ref.read(emailProvider.notifier).initialLoad();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegistering = false);
      final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException(400): ', '');

      if (errorMsg.toLowerCase().contains('username') ||
          errorMsg.toLowerCase().contains('exists') ||
          errorMsg.toLowerCase().contains('taken')) {
        setState(() {
          _emailHandleError = 'Email handle "$cleanHandle" is already taken. Pick a suggestion below:';
        });
        await _fetchSuggestions(firstName, lastName, dob, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activation failed: $errorMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildSuggestionChips(
      List<String> suggestions, Function(String) onSelect) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available suggestions:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF195BAC),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) {
              return ActionChip(
                avatar: const Icon(Icons.add, size: 14, color: Color(0xFF195BAC)),
                label: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF195BAC),
                  ),
                ),
                backgroundColor: const Color(0xFFE9F4FF),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () => onSelect(s),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int calculateAge(String dobStr) {
    try {
      final birthDate = DateTime.parse(dobStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return -1;
    }
  }

  String? validateDob(String dobStr) {
    if (dobStr.isEmpty) {
      return 'Date of Birth is required';
    }
    final parts = dobStr.split('-');
    if (parts.length != 3 || dobStr.length != 10) {
      return 'Please enter date in YYYY-MM-DD format';
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    final currentYear = DateTime.now().year;

    if (year == null || year < 1925 || year > currentYear) {
      return 'Invalid year (must be between 1925 and $currentYear)';
    }
    if (month == null || month < 1 || month > 12) {
      return 'Invalid month (must be 01-12)';
    }
    if (day == null || day < 1 || day > 31) {
      return 'Invalid day (must be 01-31)';
    }
    try {
      final parsed = DateTime.parse(dobStr);
      if (parsed.isAfter(DateTime.now())) {
        return 'Date of Birth cannot be in the future';
      }
    } catch (e) {
      return 'Invalid date';
    }
    return null;
  }

  // Password standard validator: at least 8 chars, 1 letter, 1 number
  String? validatePasswordStrength(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    if (!hasLetter || !hasDigit) {
      return 'Password must contain both letters and numbers';
    }
    return null;
  }

  // Helper to build fields with consistent design
  Widget _buildFormField({
    required String label,
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    String? errorText,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null
                  ? Colors.redAccent
                  : Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F4FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF195BAC), size: 18),
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: Color(0xFF195BAC),
                size: 28,
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              onChanged: onChanged,
              items: items.map((String val) {
                return DropdownMenuItem<String>(value: val, child: Text(val));
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAccountCard({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    final themeBgColor = isSelected ? const Color(0xFF195BAC) : Colors.white;
    final themeTextColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final themeSubTextColor = isSelected
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.grey.shade600;
    final themeIconBg = isSelected
        ? Colors.white.withValues(alpha: 0.2)
        : const Color(0xFFE9F4FF);
    final themeIconColor = isSelected ? Colors.white : const Color(0xFF195BAC);
    final themeBorderColor = isSelected
        ? Colors.transparent
        : Colors.grey.shade200;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _personalStep = 1;
          _childStep = 1;
          _businessStep = 1;
          _tempToken = null;
          _usernameSuggestions = [];
          _emailHandleSuggestions = [];
          _parentOtpVerified = false;
          _parentOtpMessage = null;
          _parentOtpError = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: themeBorderColor, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF195BAC).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Left Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: themeIconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: themeIconColor, size: 22),
            ),
            const SizedBox(width: 16),
            // Middle Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: themeTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: themeSubTextColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right Selection Radio Indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey.shade300,
                  width: 2,
                ),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Color(0xFF195BAC), size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F4FF),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Top Bar with Back Navigation Arrow and Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _step > 1
                      ? IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Color(0xFF0F172A),
                            size: 20,
                          ),
                          onPressed: () {
                            if (_selectedType == 'personal' && _step == 2) {
                              if (_personalStep > 1) {
                                setState(() {
                                  _personalStep--;
                                });
                              } else {
                                setState(() {
                                  _step = 1;
                                });
                              }
                            } else if (_selectedType == 'business' && _step == 2) {
                              if (_businessStep > 1) {
                                setState(() {
                                  _businessStep--;
                                });
                              } else {
                                setState(() {
                                  _step = 1;
                                });
                              }
                            } else if (_selectedType == 'child' && _step == 2) {
                              if (_childStep > 1) {
                                setState(() {
                                  _childStep--;
                                });
                              } else {
                                setState(() {
                                  _step = 1;
                                });
                              }
                            } else {
                              setState(() {
                                _step--;
                              });
                            }
                          },
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Color(0xFF0F172A),
                            size: 20,
                          ),
                          onPressed: () => context.go('/login'),
                        ),
                  Image.asset(
                    'assets/bnx_mail_logo.png',
                    height: 40,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.mail_outline,
                      size: 40,
                      color: Color(0xFF195BAC),
                    ),
                  ),
                  const SizedBox(width: 48), // Keep layout balanced
                ],
              ),
              const SizedBox(height: 8),
              // Step Headings
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedType == 'child' && _step == 2
                    ? 'Step $_childStep of 5'
                    : (_selectedType == 'personal' && _step == 2
                        ? 'Step $_personalStep of 3'
                        : 'Step $_step of 3'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Card Container Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _buildStepContent(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 1) {
      return Column(
        children: [
          // Profile Gear Avatar Icon
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE9F4FF),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Icon(
                    Icons.person_rounded,
                    color: Color(0xFF195BAC),
                    size: 32,
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Icon(
                      Icons.settings_rounded,
                      color: Color(0xFF195BAC),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Titles
          const Text(
            'Account Type',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to use BNXmail',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Option Cards
          _buildAccountCard(
            type: 'personal',
            icon: Icons.person_rounded,
            title: 'Personal Use',
            subtitle: 'For individuals and daily communication',
            isSelected: _selectedType == 'personal',
          ),
          _buildAccountCard(
            type: 'business',
            icon: Icons.business_center_rounded,
            title: 'Business Use',
            subtitle: 'For organizations and professional teams',
            isSelected: _selectedType == 'business',
          ),
          _buildAccountCard(
            type: 'child',
            icon: Icons.face_rounded,
            title: 'Child Use',
            subtitle: 'Available exclusively for users under 18 years of age',
            isSelected: _selectedType == 'child',
          ),
          const SizedBox(height: 20),

          // Next / Get Started Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF195BAC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _step = 2;
                });
              },
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Page Indicators
          _buildPageIndicator(),
        ],
      );
    } else if (_step == 2) {
      if (_selectedType == 'business') {
        if (_businessStep == 1) {
          // Page 1: Business Details (Owner First Name & Last Name side-by-side, Reg Number, Phone)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Business Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit more about your business',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // 1. Owner First Name & Owner Last Name (left and right side)
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: 'Owner First Name',
                      hintText: 'John',
                      icon: Icons.person_outline,
                      controller: _ownerFirstNameController,
                      errorText: _ownerFirstNameError,
                      maxLength: 30,
                      onChanged: (val) {
                        if (_ownerFirstNameError != null) {
                          setState(() => _ownerFirstNameError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFormField(
                      label: 'Owner Last Name',
                      hintText: 'Doe',
                      icon: Icons.person_outline,
                      controller: _ownerLastNameController,
                      errorText: _ownerLastNameError,
                      maxLength: 30,
                      onChanged: (val) {
                        if (_ownerLastNameError != null) {
                          setState(() => _ownerLastNameError = null);
                        }
                      },
                    ),
                  ),
                ],
              ),

              // 2. Business Registration Number
              _buildFormField(
                label: 'Business Registration Number',
                hintText: 'REG-12345678',
                icon: Icons.apartment_rounded,
                controller: _businessNameController,
                errorText: _businessNameError,
                maxLength: 50,
                onChanged: (val) {
                  if (_businessNameError != null) {
                    setState(() => _businessNameError = null);
                  }
                },
              ),

              // 3. Phone Number
              _buildFormField(
                label: 'Phone Number',
                hintText: '+1 234 567 8900',
                icon: Icons.phone_outlined,
                controller: _phoneController,
                errorText: _phoneError,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                onChanged: (val) {
                  if (_phoneError != null) {
                    setState(() => _phoneError = null);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Next Step Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final oFName = _ownerFirstNameController.text.trim();
                    final oLName = _ownerLastNameController.text.trim();
                    final bReg = _businessNameController.text.trim();
                    final phone = _phoneController.text.trim();

                    setState(() {
                      _ownerFirstNameError =
                          oFName.isEmpty ? 'Owner First Name is required' : null;
                      _ownerLastNameError =
                          oLName.isEmpty ? 'Owner Last Name is required' : null;
                      _businessNameError =
                          bReg.isEmpty ? 'Registration Number is required' : null;
                      _phoneError =
                          phone.isEmpty ? 'Phone Number is required' : null;
                    });

                    if (_ownerFirstNameError == null &&
                        _ownerLastNameError == null &&
                        _businessNameError == null &&
                        _phoneError == null) {
                      final today = DateTime.now().toIso8601String().substring(0, 10);
                      await _fetchSuggestions(oFName, oLName, today, false);
                      setState(() {
                        _businessStep = 2;
                      });
                    }
                  },
                  child: const Text(
                    'Next Step',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        } else {
          // Page 2: Password Page (like in personal section!)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Secure your account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set your admin username and password for your business.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              _buildSuggestionChips(_usernameSuggestions, (s) {
                setState(() {
                  _adminUsernameController.text = s;
                  _adminUsernameError = null;
                });
              }),

              _buildFormField(
                label: 'Admin Username',
                hintText: 'e.g. admin_btc',
                icon: Icons.alternate_email,
                controller: _adminUsernameController,
                errorText: _adminUsernameError,
                maxLength: 30,
                suffixIcon: const Padding(
                  padding: EdgeInsets.only(right: 16.0, top: 14.0),
                  child: Text(
                    '@bnxmail.com',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF195BAC),
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (_adminUsernameError != null) {
                    setState(() => _adminUsernameError = null);
                  }
                },
              ),
              _buildFormField(
                label: 'Admin Password',
                hintText: '••••••••',
                icon: Icons.lock_outline,
                controller: _adminPasswordController,
                obscureText: _obscureAdminPassword,
                errorText: _adminPasswordError,
                maxLength: 64,
                onChanged: (val) {
                  if (_adminPasswordError != null) {
                    setState(() => _adminPasswordError = null);
                  }
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureAdminPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureAdminPassword = !_obscureAdminPassword;
                    });
                  },
                ),
              ),
              _buildFormField(
                label: 'Confirm Password',
                hintText: '••••••••',
                icon: Icons.lock_outline,
                controller: _retypeAdminPasswordController,
                obscureText: _obscureRetypeAdminPassword,
                errorText: _retypeAdminPasswordError,
                maxLength: 64,
                onChanged: (val) {
                  if (_retypeAdminPasswordError != null) {
                    setState(() => _retypeAdminPasswordError = null);
                  }
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRetypeAdminPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureRetypeAdminPassword = !_obscureRetypeAdminPassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Register Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isRegistering
                      ? null
                      : () async {
                          final aUName = _adminUsernameController.text.trim();
                          final aPass = _adminPasswordController.text;
                          final aRepass = _retypeAdminPasswordController.text;

                          setState(() {
                            _adminUsernameError = aUName.isEmpty
                                ? 'Admin Username is required'
                                : null;
                            _adminPasswordError = validatePasswordStrength(aPass);

                            if (aRepass.isEmpty) {
                              _retypeAdminPasswordError = 'Please retype your password';
                            } else if (aPass != aRepass) {
                              _retypeAdminPasswordError = 'Passwords do not match';
                            } else {
                              _retypeAdminPasswordError = null;
                            }
                          });

                          if (_adminUsernameError == null &&
                              _adminPasswordError == null &&
                              _retypeAdminPasswordError == null) {
                            await _submitStep2();
                          }
                        },
                  child: _isRegistering
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Register Account',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        }
      } else if (_selectedType == 'child') {
        // Child Account Flow (Divided into 5 pages)
        if (_childStep == 1) {
          // Page 1: Child Details
          final dobVal = _childDobController.text.trim();
          final dobErrCheck = validateDob(dobVal);
          final ageVal = dobErrCheck == null ? calculateAge(dobVal) : -1;
          final isOver18 = ageVal >= 18;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Child Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit more about your child',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: "Child's First Name",
                      hintText: 'First Name',
                      icon: Icons.face_outlined,
                      controller: _childFirstNameController,
                      errorText: _childFirstNameError,
                      maxLength: 30,
                      onChanged: (val) {
                        if (_childFirstNameError != null) {
                          setState(() => _childFirstNameError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFormField(
                      label: "Child's Last Name",
                      hintText: 'Last Name',
                      icon: Icons.face_outlined,
                      controller: _childLastNameController,
                      errorText: _childLastNameError,
                      maxLength: 30,
                      onChanged: (val) {
                        if (_childLastNameError != null) {
                          setState(() => _childLastNameError = null);
                        }
                      },
                    ),
                  ),
                ],
              ),
              _buildFormField(
                label: "Child's Date of Birth",
                hintText: 'YYYY-MM-DD',
                icon: Icons.calendar_today_outlined,
                controller: _childDobController,
                errorText: _childDobError,
                readOnly: false, // Typing enabled
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  DateInputFormatter(),
                ],
                onChanged: (val) {
                  if (_childDobError != null) {
                    setState(() => _childDobError = null);
                  }
                  setState(() {});
                },
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF195BAC)),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2015, 1, 1),
                      firstDate: DateTime(1925),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final formatted =
                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      setState(() {
                        _childDobController.text = formatted;
                        _childDobError = null;
                      });
                    }
                  },
                ),
              ),
              _buildDropdownField(
                label: 'Gender',
                value: _childGender,
                items: _genderOptions,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _childGender = val);
                  }
                },
              ),
              const SizedBox(height: 8),

              // Option for users 18 or older ONLY
              if (isOver18) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User is 18 years or older',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Child accounts are designed for users under 18.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFF1D4ED8),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedType = 'personal';
                            _step = 2;
                            _personalStep = 1;
                            _firstNameController.text = _childFirstNameController.text;
                            _lastNameController.text = _childLastNameController.text;
                            _dobController.text = _childDobController.text;
                            _personalGender = _childGender;
                          });
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text(
                          'Create a Personal Account instead',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Next Step Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final fName = _childFirstNameController.text.trim();
                    final lName = _childLastNameController.text.trim();
                    final dob = _childDobController.text.trim();

                    setState(() {
                      _childFirstNameError = fName.isEmpty ? 'First Name is required' : null;
                      _childLastNameError = lName.isEmpty ? 'Last Name is required' : null;

                      final dobErr = validateDob(dob);
                      if (dobErr != null) {
                        _childDobError = dobErr;
                      } else if (calculateAge(dob) >= 18) {
                        _childDobError = 'Child account is only for users under 18';
                      } else {
                        _childDobError = null;
                      }
                    });

                    if (_childFirstNameError == null &&
                        _childLastNameError == null &&
                        _childDobError == null) {
                      setState(() {
                        _childStep = 2;
                      });
                    }
                  },
                  child: const Text(
                    'Next Step',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        } else if (_childStep == 2) {
          // Page 2: Combined Parent Email Address & Consent Code Page
          final parentEmail = _parentEmailController.text.trim();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parent Verification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Since the account is for a child, enter parent's email address and verify consent code.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // 1. Parent's Email Address
              _buildFormField(
                label: "Parent's Email Address",
                hintText: 'parent@example.com',
                icon: Icons.email_outlined,
                controller: _parentEmailController,
                errorText: _parentEmailError,
                maxLength: 50,
                onChanged: (val) {
                  if (_parentEmailError != null) {
                    setState(() => _parentEmailError = null);
                  }
                },
              ),
              const SizedBox(height: 4),

              // Status and Send OTP Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _parentOtpMessage ??
                          (parentEmail.isNotEmpty && _parentOtpError == null
                              ? 'Code sent to $parentEmail'
                              : 'Tap Send OTP to receive consent code'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _parentOtpError != null
                            ? Colors.redAccent
                            : (_parentOtpVerified
                                ? const Color(0xFF22C55E)
                                : Colors.grey.shade600),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _isSendingParentOtp
                        ? null
                        : () async {
                            final email = _parentEmailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              setState(() =>
                                  _parentEmailError = 'Please enter a valid Parent Email address');
                              return;
                            }
                            await _sendParentOtp();
                          },
                    icon: _isSendingParentOtp
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF195BAC),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 14),
                    label: Text(
                      _parentOtpMessage != null ? 'Resend OTP' : 'Send OTP',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF195BAC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Consent Code Field
              _buildFormField(
                label: 'Consent Code',
                hintText: 'Enter 6-digit code',
                icon: Icons.lock_clock_outlined,
                controller: _parentOtpController,
                errorText: _parentOtpError,
                maxLength: 6,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  if (_parentOtpError != null) {
                    setState(() => _parentOtpError = null);
                  }
                },
              ),
              const SizedBox(height: 16),

              // 3. Verify & Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (_isVerifyingParentOtp || _isSendingParentOtp)
                      ? null
                      : () async {
                          final pEmail = _parentEmailController.text.trim();
                          final otp = _parentOtpController.text.trim();

                          if (pEmail.isEmpty || !pEmail.contains('@')) {
                            setState(() => _parentEmailError =
                                'Please enter a valid Parent Email address');
                            return;
                          }

                          if (otp.isEmpty) {
                            if (_parentOtpMessage == null) {
                              await _sendParentOtp();
                            } else {
                              setState(() => _parentOtpError =
                                  'Please enter the 6-digit Consent Code');
                            }
                            return;
                          }

                          await _verifyParentOtp();
                          if (_parentOtpVerified) {
                            final fName = _childFirstNameController.text.trim();
                            final lName = _childLastNameController.text.trim();
                            final dob = _childDobController.text.trim();
                            await _fetchSuggestions(fName, lName, dob, false);
                            setState(() {
                              _childStep = 3;
                            });
                          }
                        },
                  child: _isVerifyingParentOtp
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify & Continue',
                          style:
                              TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        } else if (_childStep == 3) {
          // Page 3: Choose your email address
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your email address',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a suggested handle or create your own.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              _buildSuggestionChips(_usernameSuggestions, (s) {
                setState(() {
                  _childUsernameController.text = s;
                  _childUsernameError = null;
                });
              }),

              _buildFormField(
                label: 'Create a custom handle',
                hintText: 'e.g. johndoe123',
                icon: Icons.alternate_email,
                controller: _childUsernameController,
                errorText: _childUsernameError,
                maxLength: 30,
                suffixIcon: const Padding(
                  padding: EdgeInsets.only(right: 16.0, top: 14.0),
                  child: Text(
                    '@bnxmail.com',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF195BAC),
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (_childUsernameError != null) {
                    setState(() => _childUsernameError = null);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Next Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final uName = _childUsernameController.text.trim();
                    setState(() {
                      _childUsernameError = uName.isEmpty ? 'Username is required' : null;
                    });
                    if (_childUsernameError == null) {
                      setState(() {
                        _childStep = 4;
                      });
                    }
                  },
                  child: const Text(
                    'Next Step',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        } else {
          // Page 4: Secure your account
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Secure your account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set a strong password for your new account.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              _buildFormField(
                label: 'Password',
                hintText: '••••••••',
                icon: Icons.lock_outline,
                controller: _childPasswordController,
                obscureText: _obscureChildPassword,
                errorText: _childPasswordError,
                maxLength: 64,
                onChanged: (val) {
                  if (_childPasswordError != null) {
                    setState(() => _childPasswordError = null);
                  }
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureChildPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureChildPassword = !_obscureChildPassword;
                    });
                  },
                ),
              ),
              _buildFormField(
                label: 'Confirm Password',
                hintText: '••••••••',
                icon: Icons.lock_outline,
                controller: _childRetypePasswordController,
                obscureText: _obscureChildRetypePassword,
                errorText: _childRetypePasswordError,
                maxLength: 64,
                onChanged: (val) {
                  if (_childRetypePasswordError != null) {
                    setState(() => _childRetypePasswordError = null);
                  }
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureChildRetypePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureChildRetypePassword = !_obscureChildRetypePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Complete Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isRegistering
                      ? null
                      : () async {
                          final pass = _childPasswordController.text;
                          final repass = _childRetypePasswordController.text;

                          setState(() {
                            _childPasswordError = validatePasswordStrength(pass);
                            _childRetypePasswordError = repass.isEmpty
                                ? 'Please confirm your password'
                                : (pass != repass ? 'Passwords do not match' : null);
                          });

                          if (_childPasswordError == null && _childRetypePasswordError == null) {
                            setState(() => _isRegistering = true);
                            try {
                              // Register the Child account
                              final token = await AuthRepository.register(
                                mode: 'CHILD',
                                firstName: _childFirstNameController.text.trim(),
                                lastName: _childLastNameController.text.trim(),
                                username: _childUsernameController.text.trim(),
                                password: pass,
                                dob: _childDobController.text.trim(),
                                parentEmail: _parentEmailController.text.trim(),
                              );

                              // Create Mailbox
                              await AuthRepository.createMailbox(
                                tempToken: token,
                                emailName: _childUsernameController.text.trim(),
                                password: pass,
                                isPrimary: true,
                              );

                              if (!mounted) return;
                              setState(() => _isRegistering = false);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Child Account successfully created! Please log in.'),
                                  backgroundColor: Color(0xFF22C55E),
                                ),
                              );
                              context.go('/login');
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isRegistering = false);
                              final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException(400): ', '');
                              if (errorMsg.toLowerCase().contains('username') ||
                                  errorMsg.toLowerCase().contains('exists') ||
                                  errorMsg.toLowerCase().contains('taken')) {
                                setState(() {
                                  _childUsernameError = 'Username is already taken';
                                  _childStep = 4; // Go back to handle selection
                                });
                                final fName = _childFirstNameController.text.trim();
                                final lName = _childLastNameController.text.trim();
                                final dob = _childDobController.text.trim();
                                await _fetchSuggestions(fName, lName, dob, false);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Registration failed: $errorMsg'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: _isRegistering
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Complete Setup',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        }
      } else {
        // Personal Account Flow (Divided into 3 pages)
        if (_personalStep == 1) {
          // Page 1: Personal Details
          final dobVal = _dobController.text.trim();
          final dobErrCheck = validateDob(dobVal);
          final ageVal = dobErrCheck == null ? calculateAge(dobVal) : -1;
          final isUnder18 = dobErrCheck == null && ageVal >= 0 && ageVal < 18;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit more about yourself',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              _buildFormField(
                label: 'First Name',
                hintText: 'John',
                icon: Icons.person_outline,
                controller: _firstNameController,
                errorText: _firstNameError,
                maxLength: 30,
                onChanged: (val) {
                  if (_firstNameError != null) {
                    setState(() => _firstNameError = null);
                  }
                },
              ),
              _buildFormField(
                label: 'Last Name',
                hintText: 'Doe',
                icon: Icons.person_outline,
                controller: _lastNameController,
                errorText: _lastNameError,
                maxLength: 30,
                onChanged: (val) {
                  if (_lastNameError != null) {
                    setState(() => _lastNameError = null);
                  }
                },
              ),
              _buildFormField(
                label: 'Date of Birth',
                hintText: 'YYYY-MM-DD',
                icon: Icons.calendar_today_outlined,
                controller: _dobController,
                errorText: _dobError,
                readOnly: false, // Typing enabled
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  DateInputFormatter(),
                ],
                onChanged: (val) {
                  if (_dobError != null) {
                    setState(() => _dobError = null);
                  }
                  setState(() {});
                },
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF195BAC)),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2005, 1, 1),
                      firstDate: DateTime(1925),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final formatted =
                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      setState(() {
                        _dobController.text = formatted;
                        _dobError = null;
                      });
                    }
                  },
                ),
              ),
              _buildDropdownField(
                label: 'Gender',
                value: _personalGender,
                items: _genderOptions,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _personalGender = val);
                  }
                },
              ),
              _buildFormField(
                label: 'Phone Number',
                hintText: '+1 234 567 8900',
                icon: Icons.phone_outlined,
                controller: _personalPhoneController,
                errorText: _personalPhoneError,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                onChanged: (val) {
                  if (_personalPhoneError != null) {
                    setState(() => _personalPhoneError = null);
                  }
                },
              ),
              const SizedBox(height: 8),

              // Option for users under 18 ONLY
              if (isUnder18) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User is under 18 years of age',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Personal accounts are designed for users 18 and older.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFF1D4ED8),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedType = 'child';
                            _step = 2;
                            _personalStep = 1;
                            _childStep = 1;
                            _childFirstNameController.text = _firstNameController.text;
                            _childLastNameController.text = _lastNameController.text;
                            _childDobController.text = _dobController.text;
                            _childGender = _personalGender;
                          });
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text(
                          'Create a Child Account instead',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Next Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final fName = _firstNameController.text.trim();
                    final lName = _lastNameController.text.trim();
                    final dob = _dobController.text.trim();

                    setState(() {
                      _firstNameError = fName.isEmpty ? 'First Name is required' : null;
                      _lastNameError = lName.isEmpty ? 'Last Name is required' : null;
                      
                      final dobErr = validateDob(dob);
                      if (dobErr != null) {
                        _dobError = dobErr;
                      } else {
                        _dobError = null;
                      }
                    });

                    if (_firstNameError == null && _lastNameError == null && _dobError == null) {
                      final age = calculateAge(dob);
                      if (age < 18) {
                        setState(() {
                          _selectedType = 'child';
                          _step = 2;
                          _personalStep = 1;
                          _childStep = 1;
                          _childFirstNameController.text = fName;
                          _childLastNameController.text = lName;
                          _childDobController.text = dob;
                          _childGender = _personalGender;
                          _usernameSuggestions = [];
                          _parentOtpVerified = false;
                          _parentOtpError = null;
                          _parentOtpMessage = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Personal accounts are for users 18 and older. Redirected to Child Account registration.'),
                            backgroundColor: Color(0xFF195BAC),
                          ),
                        );
                        return;
                      }
                      
                      // Fetch suggestions proactively
                      await _fetchSuggestions(fName, lName, dob, false);
                      setState(() {
                        _personalStep = 2;
                      });
                    }
                  },
                  child: const Text(
                    'Next Step',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        } else if (_personalStep == 2) {
          // Page 2: Choose your email address
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your email address',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a suggested handle or create your own.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              _buildSuggestionChips(_usernameSuggestions, (s) {
                setState(() {
                  _usernameController.text = s;
                  _usernameError = null;
                });
              }),

              _buildFormField(
                label: 'Create a custom handle',
                hintText: 'e.g. johndoe123',
                icon: Icons.alternate_email,
                controller: _usernameController,
                errorText: _usernameError,
                maxLength: 30,
                suffixIcon: const Padding(
                  padding: EdgeInsets.only(right: 16.0, top: 14.0),
                  child: Text(
                    '@bnxmail.com',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF195BAC),
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Next Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final uName = _usernameController.text.trim();
                    setState(() {
                      _usernameError = uName.isEmpty ? 'Username is required' : null;
                    });
                    if (_usernameError == null) {
                      setState(() {
                        _personalStep = 3;
                      });
                    }
                  },
                  child: const Text(
                    'Next Step',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        } else {
          // Page 3: Secure your account
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Secure your account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set a strong password for your new account.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              _buildFormField(
                label: 'Password',
                hintText: '••••••••',
                icon: Icons.lock_outline,
                controller: _passwordController,
                obscureText: _obscurePassword,
                errorText: _passwordError,
                maxLength: 64,
                onChanged: (val) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              _buildFormField(
                label: 'Confirm Password',
                hintText: '••••••••',
                icon: Icons.lock_outline,
                controller: _retypePasswordController,
                obscureText: _obscureRetypePassword,
                errorText: _retypePasswordError,
                maxLength: 64,
                onChanged: (val) {
                  if (_retypePasswordError != null) {
                    setState(() => _retypePasswordError = null);
                  }
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRetypePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureRetypePassword = !_obscureRetypePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Complete Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF195BAC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isRegistering
                      ? null
                      : () async {
                          final pass = _passwordController.text;
                          final repass = _retypePasswordController.text;

                          setState(() {
                            _passwordError = validatePasswordStrength(pass);
                            _retypePasswordError = repass.isEmpty
                                ? 'Please confirm your password'
                                : (pass != repass ? 'Passwords do not match' : null);
                          });

                          if (_passwordError == null && _retypePasswordError == null) {
                            setState(() => _isRegistering = true);
                            try {
                              // Register the account
                              final token = await AuthRepository.register(
                                mode: 'PERSONAL',
                                firstName: _firstNameController.text.trim(),
                                lastName: _lastNameController.text.trim(),
                                username: _usernameController.text.trim(),
                                password: pass,
                                dob: _dobController.text.trim(),
                              );

                              // Create mailbox
                              await AuthRepository.createMailbox(
                                tempToken: token,
                                emailName: _usernameController.text.trim(),
                                password: pass,
                                isPrimary: true,
                              );

                              if (!mounted) return;
                              setState(() => _isRegistering = false);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account successfully created! Please log in.'),
                                  backgroundColor: Color(0xFF22C55E),
                                ),
                              );
                              context.go('/login');
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isRegistering = false);
                              final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException(400): ', '');
                              if (errorMsg.toLowerCase().contains('username') ||
                                  errorMsg.toLowerCase().contains('exists') ||
                                  errorMsg.toLowerCase().contains('taken')) {
                                setState(() {
                                  _usernameError = 'Username is already taken';
                                  _personalStep = 2; // Go back to username selection step
                                });
                                final fName = _firstNameController.text.trim();
                                final lName = _lastNameController.text.trim();
                                final dob = _dobController.text.trim();
                                await _fetchSuggestions(fName, lName, dob, false);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Registration failed: $errorMsg'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: _isRegistering
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Complete Setup',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPageIndicator(),
            ],
          );
        }
      }
    } else {
      // Step 3 (Activate Email)
      final domainSuffix = _selectedType == 'business'
          ? '@${_customDomainController.text.trim().isNotEmpty ? _customDomainController.text.trim() : 'bnxmail.com'}'
          : '@bnxmail.com';

      return Column(
        children: [
          // Circular green check mail icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F7ED),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Icon(Icons.mail_rounded, color: Color(0xFF22C55E), size: 32),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Color(0xFF22C55E),
                      child: Icon(Icons.check, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Titles
          const Text(
            'Activate Email',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Final step! Pick your permanent email username to complete activation.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Email Handle Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email Handle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _emailHandleError != null
                        ? Colors.redAccent
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE9F4FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alternate_email,
                        color: Color(0xFF195BAC),
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _emailHandleController,
                        onChanged: (val) {
                          if (_emailHandleError != null) {
                            setState(() => _emailHandleError = null);
                          }
                        },
                        maxLength: 30,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'username',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_selectedType != 'business')
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          domainSuffix,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF195BAC),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_emailHandleError != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    _emailHandleError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              _buildSuggestionChips(_emailHandleSuggestions, (s) {
                setState(() {
                  _emailHandleController.text = s;
                  _emailHandleError = null;
                });
              }),
            ],
          ),
          const SizedBox(height: 24),

          // Activate Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF195BAC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _isRegistering ? null : _submitStep3,
              child: _isRegistering
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Activate & Join',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          _buildPageIndicator(),
        ],
      );
    }
  }

  Widget _buildPageIndicator() {
    final isChild = _selectedType == 'child' && _step == 2;
    final isPersonal = _selectedType == 'personal' && _step == 2;
    final isBusiness = _selectedType == 'business' && _step == 2;
    final activeStep = isChild
        ? _childStep
        : (isPersonal
            ? _personalStep
            : (isBusiness ? _businessStep : _step));
    final totalSteps = isChild ? 4 : (isBusiness ? 2 : 3);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final stepNum = index + 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: activeStep == stepNum ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: activeStep == stepNum ? const Color(0xFF195BAC) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length && i < 8; i++) {
      if (i == 4 || i == 6) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
