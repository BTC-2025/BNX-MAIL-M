import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/auth_notifier.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/account_provider.dart';
import '../../../../data/email_provider.dart';

class RegisterAccountTypeScreen extends ConsumerStatefulWidget {
  final String? initialStep;
  const RegisterAccountTypeScreen({super.key, this.initialStep});

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
  String _currentPersonalStep = 'selection'; // 'selection', 'profile', 'mail', 'mobile-verify', 'password'
  String _currentChildStep = 'details'; // 'details', 'parent-email', 'parent-otp', 'mail', 'mobile-verify', 'password'
  String _currentBusinessStep = 'details'; // 'details', 'sole_proprietorship', 'organization', 'mail', 'mobile-verify', 'password'
  String _businessFlow = 'secondary'; // 'secondary' | 'primary'
  String _businessPrimaryType = 'sole_proprietorship'; // 'sole_proprietorship' | 'organization'
  bool _isFetchingGstins = false;
  bool _phoneOtpSent = false;
  bool _isSendingMobileOtp = false;
  bool _isVerifyingMobileOtp = false;
  bool _showPassword = false;
  late CountryOption _selectedCountry;
  String get _selectedCountryCode => _selectedCountry.code;
  final _otpController = TextEditingController();
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _countryOptions.first;
    if (widget.initialStep != null) {
      if (widget.initialStep == 'selection') {
        _step = 1;
        _selectedType = 'personal';
        _currentPersonalStep = 'selection';
      } else if (widget.initialStep == 'profile') {
        _step = 2;
        _selectedType = 'personal';
        _personalStep = 1;
        _currentPersonalStep = 'profile';
      } else if (widget.initialStep == 'mail') {
        _step = 2;
        _selectedType = 'personal';
        _personalStep = 2;
        _currentPersonalStep = 'mail';
      } else if (widget.initialStep == 'mobile-verify') {
        _step = 2;
        _selectedType = 'personal';
        _personalStep = 3;
        _currentPersonalStep = 'mobile-verify';
      } else if (widget.initialStep == 'password') {
        _step = 2;
        _selectedType = 'personal';
        _personalStep = 3;
        _currentPersonalStep = 'password';
      } else if (widget.initialStep == 'child' || widget.initialStep == 'child-details') {
        _step = 2;
        _selectedType = 'child';
        _childStep = 1;
        _currentChildStep = 'details';
      } else if (widget.initialStep == 'child-parent-email') {
        _step = 2;
        _selectedType = 'child';
        _childStep = 2;
        _currentChildStep = 'parent-email';
      } else if (widget.initialStep == 'child-parent-otp') {
        _step = 2;
        _selectedType = 'child';
        _childStep = 2;
        _currentChildStep = 'parent-otp';
      } else if (widget.initialStep == 'child-mail') {
        _step = 2;
        _selectedType = 'child';
        _childStep = 3;
        _currentChildStep = 'mail';
      } else if (widget.initialStep == 'child-password') {
        _step = 2;
        _selectedType = 'child';
        _childStep = 4;
        _currentChildStep = 'password';
      } else if (widget.initialStep == 'business' || widget.initialStep == 'business-details') {
        _step = 2;
        _selectedType = 'business';
        _businessFlow = 'secondary';
        _currentBusinessStep = 'details';
      } else if (widget.initialStep == 'business-sole') {
        _step = 2;
        _selectedType = 'business';
        _businessFlow = 'primary';
        _businessPrimaryType = 'sole_proprietorship';
        _currentBusinessStep = 'sole_proprietorship';
      } else if (widget.initialStep == 'business-org') {
        _step = 2;
        _selectedType = 'business';
        _businessFlow = 'primary';
        _businessPrimaryType = 'organization';
        _currentBusinessStep = 'organization';
      } else if (widget.initialStep == 'business-mail') {
        _step = 2;
        _selectedType = 'business';
        _currentBusinessStep = 'mail';
      } else if (widget.initialStep == 'business-password') {
        _step = 2;
        _selectedType = 'business';
        _currentBusinessStep = 'password';
      }
    }
  }

  // Validation errors (Personal)
  String? _firstNameError;
  String? _lastNameError;
  String? _usernameError;
  String? _dobError;
  String? _passwordError;
  String? _retypePasswordError;

  // Validation errors (Business)
  String? _businessNameError;
  String? _ownerFirstNameError;
  String? _ownerLastNameError;
  String? _adminUsernameError;
  String? _adminPasswordError;
  String? _retypeAdminPasswordError;
  String? _phoneError;
  String? _businessSecondaryFirstNameError;
  String? _businessSecondaryLastNameError;
  String? _businessIdError;
  String? _businessOwnerFirstNameError;
  String? _businessOwnerLastNameError;
  String? _panError;
  String? _cinError;

  // Validation errors (Child)
  String? _childFirstNameError;
  String? _childLastNameError;
  String? _childUsernameError;
  String? _childDobError;
  String? _childPasswordError;
  String? _childRetypePasswordError;
  String? _parentEmailError;

  bool _isRegistering = false;
  bool _isLoadingSuggestions = false;

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
  final _businessSecondaryFirstNameController = TextEditingController();
  final _businessSecondaryLastNameController = TextEditingController();
  final _businessIdController = TextEditingController();
  final _businessOwnerFirstNameController = TextEditingController();
  final _businessOwnerLastNameController = TextEditingController();
  final _panController = TextEditingController();
  final _cinController = TextEditingController();
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
    _businessSecondaryFirstNameController.dispose();
    _businessSecondaryLastNameController.dispose();
    _businessIdController.dispose();
    _businessOwnerFirstNameController.dispose();
    _businessOwnerLastNameController.dispose();
    _panController.dispose();
    _cinController.dispose();
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
    _otpController.dispose();
    super.dispose();
  }

  String _sanitizeRegistrationError(String rawError) {
    final lower = rawError.toLowerCase();
    if (lower.contains('data truncation') ||
        lower.contains('data too long')) {
      if (lower.contains("column 'first_name'") || lower.contains("'first_name'")) {
        return 'First Name cannot exceed 30 characters';
      }
      if (lower.contains("column 'last_name'") || lower.contains("'last_name'")) {
        return 'Last Name cannot exceed 30 characters';
      }
      if (lower.contains("column 'business_name'") ||
          lower.contains("column 'company_name'") ||
          lower.contains("'business_name'") ||
          lower.contains("'company_name'")) {
        return 'Business Name cannot exceed 50 characters';
      }
      if (lower.contains("column 'username'") || lower.contains("'username'")) {
        return 'Username cannot exceed 15 characters';
      }
      return 'Character limit exceeded for one of the fields';
    }
    if (lower.contains('too long') && lower.contains('username')) {
      return 'Username cannot exceed 15 characters';
    }
    if (lower.contains('taken') ||
        lower.contains('already exist') ||
        lower.contains('already in use')) {
      return 'Username is already taken, please pick another.';
    }
    if (lower.contains('could not execute statement') ||
        lower.contains('sql [') ||
        lower.contains('hibernateexception') ||
        lower.contains('constraintviolation')) {
      return 'Invalid username or registration details. Please choose another username.';
    }
    return rawError;
  }

  Future<void> _fetchSuggestions(
    String firstName,
    String lastName,
    String dob,
    bool isStep3,
  ) async {
    final suggestions = await AuthRepository.getUsernameSuggestions(
      firstName: firstName,
      lastName: lastName,
      dob: dob,
    );
    final validSuggestions = suggestions
        .where((s) => s.length >= 6 && s.length <= 15)
        .toList();
    if (!mounted) return;
    setState(() {
      if (isStep3) {
        _emailHandleSuggestions = validSuggestions;
      } else {
        _usernameSuggestions = validSuggestions;
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
        _parentOtpError = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException(400): ', '');
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
        _parentOtpError = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException(400): ', '');
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
        securityQuestion: _selectedType == 'child' ? _securityQuestion : null,
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
      final rawError = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException(400): ', '');
      final cleanError = _sanitizeRegistrationError(rawError);

      if (cleanError.toLowerCase().contains('username') ||
          cleanError.toLowerCase().contains('exists') ||
          cleanError.toLowerCase().contains('taken') ||
          cleanError.toLowerCase().contains('exceed')) {
        setState(() {
          if (_selectedType == 'business') {
            _adminUsernameError = cleanError;
          } else if (_selectedType == 'child') {
            _childUsernameError = cleanError;
          } else {
            _usernameError = cleanError;
          }
        });
        await _fetchSuggestions(firstName, lastName, dob, false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: $cleanError'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _submitStep3() async {
    final handle = _emailHandleController.text.trim().toLowerCase();
    _emailHandleController.text = handle;
    final cleanHandle = handle.contains('@') ? handle.split('@').first : handle;

    String? handleErr;
    if (cleanHandle.isEmpty) {
      handleErr = 'Email Handle is required';
    } else if (cleanHandle.length < 6) {
      handleErr = 'Email handle must be at least 6 characters';
    } else if (cleanHandle.length > 15) {
      handleErr = 'Email handle cannot exceed 15 characters';
    } else if (!RegExp(r'^[a-z]').hasMatch(cleanHandle)) {
      handleErr = 'Email handle must start with a lowercase letter';
    } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(cleanHandle)) {
      handleErr = 'Only lowercase letters and numbers are allowed';
    }

    setState(() {
      _emailHandleError = handleErr;
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
      final rawError = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException(400): ', '');
      final errorMsg = _sanitizeRegistrationError(rawError);

      if (errorMsg.toLowerCase().contains('username') ||
          errorMsg.toLowerCase().contains('exists') ||
          errorMsg.toLowerCase().contains('taken') ||
          errorMsg.toLowerCase().contains('exceed')) {
        setState(() {
          _emailHandleError =
              'Email handle "$cleanHandle" is not available ($errorMsg). Pick a suggestion below:';
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
    List<String> suggestions,
    Function(String) onSelect,
  ) {
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
                avatar: const Icon(
                  Icons.add,
                  size: 14,
                  color: Color(0xFF195BAC),
                ),
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

  DateTime? _parseDob(String s) {
    s = s.trim();
    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31 && y >= 1900) {
          try {
            return DateTime(y, m, d);
          } catch (_) {}
        }
      }
    } else if (s.contains('-')) {
      final parts = s.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31 && y >= 1900) {
          try {
            return DateTime(y, m, d);
          } catch (_) {}
        }
      }
    }
    return null;
  }

  int calculateAge(String dobStr) {
    final birthDate = _parseDob(dobStr);
    if (birthDate == null) return -1;
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String? validateDob(String dobStr) {
    if (dobStr.isEmpty) {
      return 'Date of Birth is required';
    }
    final dt = _parseDob(dobStr);
    if (dt == null) {
      return 'Please enter date in dd/mm/yyyy format';
    }
    final currentYear = DateTime.now().year;
    if (dt.year < 1920 || dt.year > currentYear) {
      return 'Invalid year (must be between 1920 and $currentYear)';
    }
    if (dt.isAfter(DateTime.now())) {
      return 'Date of Birth cannot be in the future';
    }
    return null;
  }

  String _formatDobForApi(String s) {
    final dt = _parseDob(s);
    if (dt != null) {
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }
    return s;
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

  static final List<TextInputFormatter> _nameFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\.\'\-]")),
    LengthLimitingTextInputFormatter(30),
  ];

  static final List<TextInputFormatter> _businessNameFormatters = [
    LengthLimitingTextInputFormatter(50),
  ];

  String? validatePersonName(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '$fieldName is required';
    if (trimmed.length < 2) return '$fieldName must be at least 2 characters';
    if (trimmed.length > 30) return '$fieldName cannot exceed 30 characters';
    if (!RegExp(r'^[a-zA-Z]').hasMatch(trimmed)) return '$fieldName must start with a letter';
    if (!RegExp(r"^[a-zA-Z\s\.\'\-]+$").hasMatch(trimmed)) {
      return 'Only letters, spaces, hyphens, and dots are allowed';
    }
    return null;
  }

  String? validateBusinessName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Business Name is required';
    if (trimmed.length < 2) return 'Business Name must be at least 2 characters';
    if (trimmed.length > 50) return 'Business Name cannot exceed 50 characters';
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
    TextCapitalization textCapitalization = TextCapitalization.none,
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
            textCapitalization: textCapitalization,
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

  bool get _canGoBackFromHeader {
    if (_selectedType == 'child') return true;
    if (_selectedType == 'personal') return _currentPersonalStep != 'selection';
    if (_selectedType == 'business') return false;
    return false;
  }

  void _handleChildBack() {
    if (_currentChildStep == 'password') {
      setState(() => _currentChildStep = 'mobile-verify');
    } else if (_currentChildStep == 'mobile-verify') {
      if (_phoneOtpSent) {
        setState(() => _phoneOtpSent = false);
      } else {
        setState(() => _currentChildStep = 'mail');
      }
    } else if (_currentChildStep == 'mail') {
      setState(() => _currentChildStep = 'parent-otp');
    } else if (_currentChildStep == 'parent-otp') {
      setState(() => _currentChildStep = 'parent-email');
    } else if (_currentChildStep == 'parent-email') {
      setState(() => _currentChildStep = 'details');
    } else {
      setState(() {
        _selectedType = 'personal';
        _currentPersonalStep = 'selection';
        _step = 1;
      });
    }
  }

  void _handlePersonalBack() {
    if (_currentPersonalStep == 'password') {
      setState(() => _currentPersonalStep = 'mobile-verify');
    } else if (_currentPersonalStep == 'mobile-verify') {
      if (_phoneOtpSent) {
        setState(() => _phoneOtpSent = false);
      } else {
        setState(() => _currentPersonalStep = 'mail');
      }
    } else if (_currentPersonalStep == 'mail') {
      setState(() => _currentPersonalStep = 'profile');
    } else if (_currentPersonalStep == 'profile') {
      setState(() => _currentPersonalStep = 'selection');
    }
  }

  void _handleBusinessBack() {
    if (_currentBusinessStep == 'password') {
      setState(() => _currentBusinessStep = 'mobile-verify');
    } else if (_currentBusinessStep == 'mobile-verify') {
      if (_phoneOtpSent) {
        setState(() => _phoneOtpSent = false);
      } else {
        setState(() => _currentBusinessStep = 'mail');
      }
    } else if (_currentBusinessStep == 'mail') {
      setState(() {
        if (_businessFlow == 'primary') {
          _currentBusinessStep = _businessPrimaryType == 'organization'
              ? 'organization'
              : 'sole_proprietorship';
        } else {
          _currentBusinessStep = 'details';
        }
      });
    } else if (_currentBusinessStep == 'sole_proprietorship' ||
        _currentBusinessStep == 'organization') {
      setState(() {
        _currentBusinessStep = 'details';
        _businessFlow = 'primary';
      });
    } else if (_currentBusinessStep == 'details') {
      if (_businessFlow == 'primary') {
        setState(() => _businessFlow = 'secondary');
      } else {
        setState(() {
          _selectedType = 'personal';
          _currentPersonalStep = 'selection';
          _step = 1;
        });
      }
    }
  }

  void _handleTopBack() {
    if (_selectedType == 'child') {
      _handleChildBack();
    } else if (_selectedType == 'personal') {
      _handlePersonalBack();
    } else if (_selectedType == 'business') {
      _handleBusinessBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 24.0,
              vertical: isMobile ? 20.0 : 40.0,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540),
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20.0 : 36.0,
                vertical: isMobile ? 28.0 : 36.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dove Logo carrying envelope
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_canGoBackFromHeader)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_rounded,
                              color: Color(0xFF0F172A),
                              size: 18,
                            ),
                            onPressed: _handleTopBack,
                          ),
                        ),
                      Center(
                        child: Image.asset(
                          'assets/bnx_mail_logo.png',
                          height: 48,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.mark_email_read_rounded,
                            size: 48,
                            color: Color(0xFF195BAC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Title
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Subtitle
                  const Text(
                    'Secure. Private. Professional.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Step Content
                  _buildCurrentStepContent(isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent(bool isMobile) {
    if (_selectedType == 'personal') {
      if (_currentPersonalStep == 'selection') {
        return _buildPersonalSelectionStep(isMobile);
      } else if (_currentPersonalStep == 'profile') {
        return _buildPersonalProfileStep(isMobile);
      } else if (_currentPersonalStep == 'mail') {
        return _buildPersonalMailStep(isMobile);
      } else if (_currentPersonalStep == 'mobile-verify') {
        return _buildPersonalMobileVerifyStep(isMobile);
      } else if (_currentPersonalStep == 'password') {
        return _buildPersonalPasswordStep(isMobile);
      }
    } else if (_selectedType == 'child') {
      if (_currentChildStep == 'details') {
        return _buildChildDetailsStep(isMobile);
      } else if (_currentChildStep == 'parent-email') {
        return _buildChildParentEmailStep(isMobile);
      } else if (_currentChildStep == 'parent-otp') {
        return _buildChildParentOtpStep(isMobile);
      } else if (_currentChildStep == 'mail') {
        return _buildChildMailStep(isMobile);
      } else if (_currentChildStep == 'mobile-verify') {
        return _buildPersonalMobileVerifyStep(isMobile);
      } else if (_currentChildStep == 'password') {
        return _buildPersonalPasswordStep(isMobile);
      }
    } else if (_selectedType == 'business') {
      if (_currentBusinessStep == 'details') {
        return _buildBusinessDetailsStep(isMobile);
      } else if (_currentBusinessStep == 'sole_proprietorship') {
        return _buildBusinessSoleProprietorshipStep(isMobile);
      } else if (_currentBusinessStep == 'organization') {
        return _buildBusinessOrganizationStep(isMobile);
      } else if (_currentBusinessStep == 'mail') {
        return _buildPersonalMailStep(isMobile);
      } else if (_currentBusinessStep == 'mobile-verify') {
        return _buildPersonalMobileVerifyStep(isMobile);
      } else if (_currentBusinessStep == 'password') {
        return _buildPersonalPasswordStep(isMobile);
      }
    }
    return _buildStepContent();
  }

  Widget _buildPersonalSelectionStep(bool isMobile) {
    return Column(
      children: [
        const Text(
          'Who is this account for?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: const Icon(
                    Icons.person,
                    color: Color(0xFF2563EB),
                    size: 28,
                  ),
                  title: 'For myself',
                  subtitle: 'Personal email account for your everyday needs.',
                  isMobile: false,
                  onTap: () {
                    setState(() {
                      _selectedType = 'personal';
                      _currentPersonalStep = 'profile';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceCard(
                  icon: const Text('👶', style: TextStyle(fontSize: 24)),
                  title: 'For my child',
                  subtitle: 'Create a managed account for users under 18.',
                  isMobile: false,
                  onTap: () {
                    setState(() {
                      _selectedType = 'child';
                      _step = 2;
                      _childStep = 1;
                      _currentChildStep = 'details';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceCard(
                  icon: const Text('🏢', style: TextStyle(fontSize: 24)),
                  title: 'For business',
                  subtitle: 'Professional accounts linked to your organization.',
                  isMobile: false,
                  onTap: () {
                    setState(() {
                      _selectedType = 'business';
                      _step = 2;
                      _businessFlow = 'secondary';
                      _currentBusinessStep = 'details';
                    });
                  },
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _ChoiceCard(
                icon: const Icon(
                  Icons.person,
                  color: Color(0xFF2563EB),
                  size: 28,
                ),
                title: 'For myself',
                subtitle: 'Personal email account for your everyday needs.',
                isMobile: true,
                onTap: () {
                  setState(() {
                    _selectedType = 'personal';
                    _currentPersonalStep = 'profile';
                  });
                },
              ),
              const SizedBox(height: 12),
              _ChoiceCard(
                icon: const Text('👶', style: TextStyle(fontSize: 24)),
                title: 'For my child',
                subtitle: 'Create a managed account for users under 18.',
                isMobile: true,
                onTap: () {
                  setState(() {
                    _selectedType = 'child';
                    _step = 2;
                    _childStep = 1;
                    _currentChildStep = 'details';
                  });
                },
              ),
              const SizedBox(height: 12),
              _ChoiceCard(
                icon: const Text('🏢', style: TextStyle(fontSize: 24)),
                title: 'For business',
                subtitle: 'Professional accounts linked to your organization.',
                isMobile: true,
                onTap: () {
                  setState(() {
                    _selectedType = 'business';
                    _step = 2;
                    _businessFlow = 'secondary';
                    _currentBusinessStep = 'details';
                  });
                },
              ),
            ],
          ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            InkWell(
              onTap: () => context.go('/login'),
              child: const Text(
                'Sign in here',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalProfileStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Personal Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSimpleInput(
                  label: 'First Name',
                  controller: _firstNameController,
                  errorText: _firstNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_firstNameError != null) {
                      setState(() => _firstNameError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleInput(
                  label: 'Last Name',
                  controller: _lastNameController,
                  errorText: _lastNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_lastNameError != null) {
                      setState(() => _lastNameError = null);
                    }
                  },
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildSimpleInput(
                label: 'First Name',
                controller: _firstNameController,
                errorText: _firstNameError,
                maxLength: 30,
                inputFormatters: _nameFormatters,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  if (_firstNameError != null) {
                    setState(() => _firstNameError = null);
                  }
                },
              ),
              const SizedBox(height: 14),
              _buildSimpleInput(
                label: 'Last Name',
                controller: _lastNameController,
                errorText: _lastNameError,
                maxLength: 30,
                inputFormatters: _nameFormatters,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  if (_lastNameError != null) {
                    setState(() => _lastNameError = null);
                  }
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
        _buildSimpleInput(
          label: 'Date of Birth',
          controller: _dobController,
          hintText: 'dd/mm/yyyy',
          errorText: _dobError,
          keyboardType: TextInputType.datetime,
          inputFormatters: [DobSlashInputFormatter()],
          suffixIcon: IconButton(
            icon: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF334155),
            ),
            onPressed: _pickDob,
          ),
          onChanged: (v) {
            if (_dobError != null) {
              setState(() => _dobError = null);
            }
          },
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _currentPersonalStep = 'selection'),
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isLoadingSuggestions ? null : _validateAndProceedProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: _isLoadingSuggestions
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Next Step',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalMailStep(bool isMobile) {
    final suggestions = _getDisplaySuggestions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Choose your email address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Pick a suggested handle or create your own.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: suggestions.map((s) {
              final isSelected = _usernameController.text.trim() == s;
              return InkWell(
                onTap: () {
                  setState(() {
                    _usernameController.text = s;
                    _usernameError = null;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE0E7FF) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE0E7FF),
                    ),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Create a custom handle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _usernameError != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.only(left: 14, right: 6, top: 4, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(15),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) => newValue.copyWith(
                        text: newValue.text.toLowerCase(),
                        selection: newValue.selection,
                      ),
                    ),
                  ],
                  maxLength: 15,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  onChanged: (v) {
                    if (_usernameError != null) {
                      setState(() => _usernameError = null);
                    }
                  },
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '6-15 characters (e.g. johndoe123)',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '@bnxmail.com',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: _usernameError != null
              ? Text(
                  _usernameError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                )
              : const Row(
                  children: [
                    Icon(Icons.info_outline, size: 13, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text(
                      '6–15 characters (letters & numbers only)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedType == 'business') {
                    if (_businessFlow == 'primary') {
                      _currentBusinessStep = _businessPrimaryType == 'organization'
                          ? 'organization'
                          : 'sole_proprietorship';
                    } else {
                      _currentBusinessStep = 'details';
                    }
                  } else {
                    _currentPersonalStep = 'profile';
                  }
                });
              },
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _validateAndProceedMail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Next Step',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalMobileVerifyStep(bool isMobile) {
    if (!_phoneOtpSent) {
      // Step 4A: Phone Number entry
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Mobile Verification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Verify your mobile number to secure your account.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mobile Number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _personalPhoneError != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                PopupMenuButton<CountryOption>(
                  tooltip: 'Select Country',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  color: Colors.white,
                  elevation: 6,
                  offset: const Offset(0, 40),
                  onSelected: (val) {
                    setState(() => _selectedCountry = val);
                  },
                  itemBuilder: (context) {
                    return _countryOptions.map((c) {
                      final isSelected = c.name == _selectedCountry.name;
                      return PopupMenuItem<CountryOption>(
                        value: c,
                        height: 40,
                        child: Row(
                          children: [
                            Text(c.flag, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${c.name} (${c.code})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, size: 16, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_selectedCountry.flag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedCountryCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _personalPhoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) {
                      if (_personalPhoneError != null) {
                        setState(() => _personalPhoneError = null);
                      }
                    },
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_personalPhoneError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _personalPhoneError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  if (_selectedType == 'child') {
                    setState(() => _currentChildStep = 'mail');
                  } else if (_selectedType == 'business') {
                    setState(() => _currentBusinessStep = 'mail');
                  } else {
                    setState(() => _currentPersonalStep = 'mail');
                  }
                },
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isSendingMobileOtp ? null : _sendMobileOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                ),
                child: _isSendingMobileOtp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Send OTP',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Step 4B: Enter OTP
      final fullPhone = '$_selectedCountryCode${_personalPhoneController.text.trim()}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Mobile Verification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Verify your mobile number to secure your account.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter the 6-digit OTP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _otpError != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              onChanged: (v) {
                if (_otpError != null) {
                  setState(() => _otpError = null);
                }
              },
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: '123456',
                hintStyle: TextStyle(
                  fontSize: 16,
                  letterSpacing: 4,
                  color: Color(0xFF94A3B8),
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_otpError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text(
                  _otpError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    children: [
                      const TextSpan(text: 'Code sent to '),
                      TextSpan(
                        text: fullPhone,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: _resendMobileOtp,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const Text('  ·  ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    InkWell(
                      onTap: () => setState(() => _phoneOtpSent = false),
                      child: const Text(
                        'Change number',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      children: [
                        const TextSpan(text: 'Code sent to '),
                        TextSpan(
                          text: fullPhone,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _resendMobileOtp,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const Text('  ·  ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    InkWell(
                      onTap: () => setState(() => _phoneOtpSent = false),
                      child: const Text(
                        'Change number',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _phoneOtpSent = false),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isVerifyingMobileOtp ? null : _verifyMobileOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                ),
                child: _isVerifyingMobileOtp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Verify OTP',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      );
    }
  }

  // ==========================================
  // CHILD REGISTRATION STEPS (Screenshots 3-5)
  // ==========================================

  Widget _buildChildDetailsStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Child Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSimpleInput(
                  label: "Child's First Name",
                  controller: _childFirstNameController,
                  errorText: _childFirstNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_childFirstNameError != null) {
                      setState(() => _childFirstNameError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleInput(
                  label: "Child's Last Name",
                  controller: _childLastNameController,
                  errorText: _childLastNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_childLastNameError != null) {
                      setState(() => _childLastNameError = null);
                    }
                  },
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildSimpleInput(
                label: "Child's First Name",
                controller: _childFirstNameController,
                errorText: _childFirstNameError,
                maxLength: 30,
                inputFormatters: _nameFormatters,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  if (_childFirstNameError != null) {
                    setState(() => _childFirstNameError = null);
                  }
                },
              ),
              const SizedBox(height: 14),
              _buildSimpleInput(
                label: "Child's Last Name",
                controller: _childLastNameController,
                errorText: _childLastNameError,
                maxLength: 30,
                inputFormatters: _nameFormatters,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  if (_childLastNameError != null) {
                    setState(() => _childLastNameError = null);
                  }
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
        _buildSimpleInput(
          label: "Child's Date of Birth",
          controller: _childDobController,
          hintText: 'dd/mm/yyyy',
          errorText: _childDobError,
          keyboardType: TextInputType.datetime,
          inputFormatters: [DobSlashInputFormatter()],
          suffixIcon: IconButton(
            icon: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF334155),
            ),
            onPressed: _pickChildDob,
          ),
          onChanged: (v) {
            if (_childDobError != null) {
              setState(() => _childDobError = null);
            }
          },
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _handleChildBack,
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _validateAndProceedChildDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Next Step',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChildParentEmailStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Parent Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            "Since the account is for a child, we need a parent's consent.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        _buildSimpleInput(
          label: "Parent's Email Address",
          controller: _parentEmailController,
          hintText: 'parent@example.com',
          errorText: _parentEmailError,
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) {
            if (_parentEmailError != null) {
              setState(() => _parentEmailError = null);
            }
          },
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _handleChildBack,
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isSendingParentOtp ? null : _sendChildParentOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: _isSendingParentOtp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Send OTP',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChildParentOtpStep(bool isMobile) {
    final parentEmail = _parentEmailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Parent Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            "Since the account is for a child, we need a parent's consent.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enter the Consent Code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _parentOtpError != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF818CF8),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: TextField(
            controller: _parentOtpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            onChanged: (v) {
              if (_parentOtpError != null) {
                setState(() => _parentOtpError = null);
              }
            },
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: Color(0xFF0F172A),
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '1 2 3 4 5 6',
              hintStyle: TextStyle(
                fontSize: 16,
                letterSpacing: 6,
                color: Color(0xFF94A3B8),
              ),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_parentOtpError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: Text(
                _parentOtpError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  children: [
                    const TextSpan(text: 'Code sent to '),
                    TextSpan(
                      text: parentEmail,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  InkWell(
                    onTap: _isSendingParentOtp ? null : _resendChildParentOtp,
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const Text('  ·  ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  InkWell(
                    onTap: () => setState(() => _currentChildStep = 'parent-email'),
                    child: const Text(
                      'Change email',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    children: [
                      const TextSpan(text: 'Code sent to '),
                      TextSpan(
                        text: parentEmail,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _isSendingParentOtp ? null : _resendChildParentOtp,
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const Text('  ·  ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  InkWell(
                    onTap: () => setState(() => _currentChildStep = 'parent-email'),
                    child: const Text(
                      'Change email',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _handleChildBack,
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isVerifyingParentOtp ? null : _verifyChildParentOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: _isVerifyingParentOtp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Verify OTP',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickChildDob() async {
    DateTime initial = DateTime(2015, 1, 1);
    final cur = _childDobController.text.trim();
    if (cur.isNotEmpty) {
      final p = _parseDob(cur);
      if (p != null) initial = p;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1925),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      setState(() {
        _childDobController.text = formatted;
        _childDobError = null;
      });
    }
  }

  void _validateAndProceedChildDetails() {
    final fName = _childFirstNameController.text.trim();
    final lName = _childLastNameController.text.trim();
    final dob = _childDobController.text.trim();

    setState(() {
      _childFirstNameError = validatePersonName(fName, 'First Name');
      _childLastNameError = validatePersonName(lName, 'Last Name');

      if (dob.isEmpty) {
        _childDobError = 'Date of Birth is required';
      } else {
        final dobErr = validateDob(dob);
        if (dobErr != null) {
          _childDobError = dobErr;
        } else if (calculateAge(dob) >= 18) {
          _childDobError = 'Child account is only for users under 18';
        } else {
          _childDobError = null;
        }
      }
    });

    if (_childFirstNameError == null &&
        _childLastNameError == null &&
        _childDobError == null) {
      setState(() {
        _currentChildStep = 'parent-email';
        _childStep = 2;
      });
    }
  }

  Future<void> _sendChildParentOtp() async {
    final email = _parentEmailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _parentEmailError = 'Please enter a valid Parent Email address');
      return;
    }
    setState(() {
      _isSendingParentOtp = true;
      _parentEmailError = null;
      _parentOtpError = null;
    });
    try {
      await AuthRepository.sendParentOtp(email);
      if (!mounted) return;
      setState(() {
        _isSendingParentOtp = false;
        _currentChildStep = 'parent-otp';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingParentOtp = false;
        _parentEmailError = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException(400): ', '');
      });
    }
  }

  Future<void> _resendChildParentOtp() async {
    final email = _parentEmailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _isSendingParentOtp = true;
      _parentOtpError = null;
    });
    try {
      await AuthRepository.sendParentOtp(email);
      if (!mounted) return;
      setState(() {
        _isSendingParentOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Consent code resent to $email'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingParentOtp = false;
        _parentOtpError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _verifyChildParentOtp() async {
    final email = _parentEmailController.text.trim();
    final otp = _parentOtpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      setState(() => _parentOtpError = 'Please enter the 6-digit consent code');
      return;
    }
    setState(() {
      _isVerifyingParentOtp = true;
      _parentOtpError = null;
    });
    try {
      await AuthRepository.verifyParentOtp(email, otp);
      if (!mounted) return;
      setState(() {
        _isVerifyingParentOtp = false;
        _parentOtpVerified = true;
        _currentChildStep = 'mail';
        _childStep = 3;
      });
      _fetchSuggestions(
        _childFirstNameController.text.trim(),
        _childLastNameController.text.trim(),
        _formatDobForApi(_childDobController.text.trim()),
        false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parent Consent verified successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingParentOtp = false;
        _parentOtpError = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException(400): ', '');
      });
    }
  }

  List<String> _getChildDisplaySuggestions() {
    if (_usernameSuggestions.isNotEmpty) {
      return _usernameSuggestions;
    }
    final fName = _childFirstNameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final lName = _childLastNameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final baseFirst = fName.isNotEmpty ? fName : 'ejhdc';
    final baseLast = lName.isNotEmpty ? lName : 'bee';

    final p1 = baseFirst.length >= 4 ? baseFirst.substring(0, 4) : baseFirst;
    final p2 = baseLast.length >= 3 ? baseLast.substring(0, 3) : baseLast;

    final s1 = '$p1${p2}202';
    final s2 = '$p1${p2}202';
    final s3 = 'ekjhc${p1}202';

    return [s1, s2, s3];
  }

  Widget _buildChildMailStep(bool isMobile) {
    final suggestions = _getChildDisplaySuggestions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Choose your email address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Pick a suggested handle or create your own.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: suggestions.map((s) {
              final isSelected = _childUsernameController.text.trim() == s;
              return InkWell(
                onTap: () {
                  setState(() {
                    _childUsernameController.text = s;
                    _childUsernameError = null;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE0E7FF) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE0E7FF),
                    ),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Create a custom handle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _childUsernameError != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.only(left: 14, right: 6, top: 4, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _childUsernameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(15),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) => newValue.copyWith(
                        text: newValue.text.toLowerCase(),
                        selection: newValue.selection,
                      ),
                    ),
                  ],
                  maxLength: 15,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  onChanged: (v) {
                    if (_childUsernameError != null) {
                      setState(() => _childUsernameError = null);
                    }
                  },
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '6-15 characters (e.g. johndoe123)',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '@bnxmail.com',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: _childUsernameError != null
              ? Text(
                  _childUsernameError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                )
              : const Row(
                  children: [
                    Icon(Icons.info_outline, size: 13, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text(
                      '6–15 characters (letters & numbers only)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _handleChildBack,
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _validateAndProceedChildMail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Next Step',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _validateAndProceedChildMail() {
    final uName = _childUsernameController.text.trim().toLowerCase();
    _childUsernameController.text = uName;
    setState(() {
      if (uName.isEmpty) {
        _childUsernameError = 'Username is required';
      } else if (uName.length < 6) {
        _childUsernameError = 'Username must be at least 6 characters';
      } else if (uName.length > 15) {
        _childUsernameError = 'Username cannot exceed 15 characters';
      } else if (!RegExp(r'^[a-z]').hasMatch(uName)) {
        _childUsernameError = 'Username must start with a lowercase letter';
      } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(uName)) {
        _childUsernameError = 'Only lowercase letters and numbers are allowed';
      } else {
        _childUsernameError = null;
      }
    });
    if (_childUsernameError == null) {
      _usernameController.text = uName;
      _firstNameController.text = _childFirstNameController.text.trim();
      _lastNameController.text = _childLastNameController.text.trim();
      _dobController.text = _childDobController.text.trim();
      setState(() {
        _currentChildStep = 'mobile-verify';
        _phoneOtpSent = false;
      });
    }
  }

  Widget _buildSimpleInput({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? errorText,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            maxLength: maxLength,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
            ),
          ),
      ],
    );
  }

  Future<void> _pickDob() async {
    DateTime initial = DateTime(2000, 1, 1);
    final cur = _dobController.text.trim();
    if (cur.isNotEmpty) {
      final p = _parseDob(cur);
      if (p != null) initial = p;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      setState(() {
        _dobController.text = formatted;
        _dobError = null;
      });
    }
  }

  List<String> _getDisplaySuggestions() {
    if (_usernameSuggestions.isNotEmpty) {
      return _usernameSuggestions;
    }
    if (_selectedType == 'business') {
      final fName = (_businessFlow == 'primary'
              ? _businessOwnerFirstNameController.text
              : _businessSecondaryFirstNameController.text)
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z]'), '');
      final bName = _businessNameController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z]'), '');
      final base1 = bName.isNotEmpty ? (bName.length > 7 ? bName.substring(0, 7) : bName) : 'corp';
      final base2 = fName.isNotEmpty ? (fName.length > 5 ? fName.substring(0, 5) : fName) : 'biz';
      return [
        '${base1}123',
        '${base2}001',
        '${base1}team',
      ];
    }
    final fName = _firstNameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final lName = _lastNameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final baseFirst = fName.isNotEmpty ? fName : 'ravi';
    final baseLast = lName.isNotEmpty ? lName : 'rave';

    final p1 = baseFirst.length >= 4 ? baseFirst.substring(0, 4) : baseFirst.padRight(4, 'a');
    final p2 = baseLast.length >= 3 ? baseLast.substring(0, 3) : baseLast.padRight(3, 'b');

    // Exactly 7 letters + 3 digits = 10 chars (per BNX Handle Rule)
    final s1 = '$p1${p2}001';
    final s2 = '$p1${p2}002';
    final s3 = '$p1${p2}123';

    return [s1, s2, s3];
  }

  void _validateAndProceedProfile() async {
    final fName = _firstNameController.text.trim();
    final lName = _lastNameController.text.trim();
    final dob = _dobController.text.trim();

    setState(() {
      _firstNameError = validatePersonName(fName, 'First Name');
      _lastNameError = validatePersonName(lName, 'Last Name');
      _dobError = validateDob(dob);
    });

    if (_firstNameError == null && _lastNameError == null && _dobError == null) {
      final age = calculateAge(dob);
      if (age >= 0 && age < 18) {
        final switchToChild = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Under 18 Account', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              'Personal accounts are designed for users 18 and older. Would you like to create a managed Child account instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay here'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create Child Account'),
              ),
            ],
          ),
        );

        if (switchToChild == true && mounted) {
          setState(() {
            _selectedType = 'child';
            _step = 2;
            _childStep = 1;
            _currentChildStep = 'details';
            _childFirstNameController.text = fName;
            _childLastNameController.text = lName;
            _childDobController.text = dob;
          });
          return;
        }
      }

      setState(() => _isLoadingSuggestions = true);
      await _fetchSuggestions(fName, lName, _formatDobForApi(dob), false);
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
          if (_usernameController.text.trim().isEmpty) {
            final available = _getDisplaySuggestions();
            if (available.isNotEmpty) {
              _usernameController.text = available.first;
            }
          }
          _currentPersonalStep = 'mail';
        });
      }
    }
  }

  void _validateAndProceedMail() {
    final uName = _usernameController.text.trim().toLowerCase();
    _usernameController.text = uName;
    setState(() {
      if (uName.isEmpty) {
        _usernameError = 'Username is required';
      } else if (uName.length < 6) {
        _usernameError = 'Username must be at least 6 characters';
      } else if (uName.length > 15) {
        _usernameError = 'Username cannot exceed 15 characters';
      } else if (!RegExp(r'^[a-z]').hasMatch(uName)) {
        _usernameError = 'Username must start with a lowercase letter';
      } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(uName)) {
        _usernameError = 'Only lowercase letters and numbers are allowed';
      } else {
        _usernameError = null;
      }
    });
    if (_usernameError == null) {
      setState(() {
        if (_selectedType == 'business') {
          _currentBusinessStep = 'mobile-verify';
        } else if (_selectedType == 'child') {
          _currentChildStep = 'mobile-verify';
        } else {
          _currentPersonalStep = 'mobile-verify';
        }
        _phoneOtpSent = false;
      });
    }
  }

  Future<void> _sendMobileOtp() async {
    final phone = _personalPhoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _personalPhoneError = 'Mobile number is required');
      return;
    }
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 6 || digitsOnly.length > 15) {
      setState(() => _personalPhoneError = 'Please enter a valid mobile number');
      return;
    }
    final fullPhone = phone.startsWith('+') ? phone : '$_selectedCountryCode$phone';

    setState(() {
      _personalPhoneError = null;
      _isSendingMobileOtp = true;
    });

    try {
      await AuthRepository.sendMobileOtp(fullPhone);
      if (!mounted) return;
      setState(() {
        _isSendingMobileOtp = false;
        _phoneOtpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to $fullPhone'),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException(400): ', '')
          .replaceAll('ApiException(500): ', '');
      setState(() {
        _isSendingMobileOtp = false;
        _personalPhoneError = errMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resendMobileOtp() async {
    final phone = _personalPhoneController.text.trim();
    final fullPhone = phone.startsWith('+') ? phone : '$_selectedCountryCode$phone';
    setState(() => _isSendingMobileOtp = true);

    try {
      await AuthRepository.sendMobileOtp(fullPhone);
      if (!mounted) return;
      setState(() => _isSendingMobileOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP resent to $fullPhone'),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException(400): ', '')
          .replaceAll('ApiException(500): ', '');
      setState(() => _isSendingMobileOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _verifyMobileOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _otpError = 'Please enter a valid 6-digit OTP');
      return;
    }
    final phone = _personalPhoneController.text.trim();
    final fullPhone = phone.startsWith('+') ? phone : '$_selectedCountryCode$phone';

    setState(() {
      _otpError = null;
      _isVerifyingMobileOtp = true;
    });

    try {
      await AuthRepository.verifyMobileOtp(fullPhone, otp);
      if (!mounted) return;

      setState(() {
        _isVerifyingMobileOtp = false;
        if (_selectedType == 'child') {
          _currentChildStep = 'password';
        } else if (_selectedType == 'business') {
          _currentBusinessStep = 'password';
        } else {
          _currentPersonalStep = 'password';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number verified successfully!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException(400): ', '')
          .replaceAll('ApiException(500): ', '');
      setState(() {
        _isVerifyingMobileOtp = false;
        _otpError = errMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPersonalPasswordStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Create Password',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Create a strong password to protect your account.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),

        _buildSimpleInput(
          label: 'Password',
          controller: _passwordController,
          hintText: 'Enter at least 8 characters',
          errorText: _passwordError,
          obscureText: !_showPassword,
          onChanged: (v) {
            if (_passwordError != null) {
              setState(() => _passwordError = null);
            }
          },
        ),
        const SizedBox(height: 16),

        _buildSimpleInput(
          label: 'Retype Password',
          controller: _retypePasswordController,
          hintText: 'Confirm your password',
          errorText: _retypePasswordError,
          obscureText: !_showPassword,
          onChanged: (v) {
            if (_retypePasswordError != null) {
              setState(() => _retypePasswordError = null);
            }
          },
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _showPassword,
                activeColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() => _showPassword = val ?? false);
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() => _showPassword = !_showPassword);
              },
              child: const Text(
                'Show password',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedType == 'child') {
                    _currentChildStep = 'mobile-verify';
                  } else if (_selectedType == 'business') {
                    _currentBusinessStep = 'mobile-verify';
                  } else {
                    _currentPersonalStep = 'mobile-verify';
                  }
                });
              },
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isRegistering ? null : _registerAndCreateAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: _isRegistering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Next Step',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _registerAndCreateAccount() async {
    final pass = _passwordController.text;
    final rePass = _retypePasswordController.text;

    setState(() {
      _passwordError = validatePasswordStrength(pass);

      if (rePass.isEmpty) {
        _retypePasswordError = 'Please retype your password';
      } else if (rePass != pass) {
        _retypePasswordError = 'Passwords do not match';
      } else {
        _retypePasswordError = null;
      }
    });

    if (_passwordError != null || _retypePasswordError != null) return;

    setState(() => _isRegistering = true);

    final isChild = _selectedType == 'child';
    final isBusiness = _selectedType == 'business';
    final fName = isChild
        ? _childFirstNameController.text.trim()
        : (isBusiness
            ? (_businessFlow == 'primary'
                ? _businessOwnerFirstNameController.text.trim()
                : _businessSecondaryFirstNameController.text.trim())
            : _firstNameController.text.trim());
    final lName = isChild
        ? _childLastNameController.text.trim()
        : (isBusiness
            ? (_businessFlow == 'primary'
                ? _businessOwnerLastNameController.text.trim()
                : _businessSecondaryLastNameController.text.trim())
            : _lastNameController.text.trim());
    final uName = isChild
        ? _childUsernameController.text.trim()
        : _usernameController.text.trim();
    final dob = isChild
        ? _formatDobForApi(_childDobController.text.trim())
        : (isBusiness
            ? DateTime.now().toIso8601String().substring(0, 10)
            : _formatDobForApi(_dobController.text.trim()));
    final rawPhone = _personalPhoneController.text.trim();
    final phone = rawPhone.startsWith('+') ? rawPhone : '$_selectedCountryCode$rawPhone';
    final parentEmail = isChild ? _parentEmailController.text.trim() : null;

    final bName = isBusiness ? _businessNameController.text.trim() : null;
    final bFlow = isBusiness ? _businessFlow : null;
    final regNum = isBusiness
        ? (_businessFlow == 'secondary'
            ? _businessIdController.text.trim()
            : (_businessPrimaryType == 'organization' ? _cinController.text.trim() : null))
        : null;
    final gstin = isBusiness ? _panController.text.trim() : null;
    final cin = isBusiness && _businessPrimaryType == 'organization' ? _cinController.text.trim() : null;

    try {
      // 1. Register with backend API
      final token = await AuthRepository.register(
        mode: isChild ? 'CHILD' : (isBusiness ? 'BUSINESS' : 'PERSONAL'),
        firstName: fName,
        lastName: lName,
        username: uName,
        password: pass,
        dob: dob,
        phoneNumber: phone,
        parentEmail: parentEmail,
        businessName: bName,
        businessFlow: bFlow,
        registrationNumber: regNum,
        gstin: gstin,
        cin: cin,
      );

      // 2. Create Mailbox with tempToken
      await AuthRepository.createMailbox(
        tempToken: token,
        emailName: uName,
        password: pass,
        isPrimary: true,
      );

      if (!mounted) return;
      setState(() => _isRegistering = false);

      if (isBusiness) {
        final businessEmail = '$uName@bnxmail.com';
        try {
          await AuthRepository.login(businessEmail, pass);
          ref.read(authProvider.notifier).login();
        } catch (_) {}

        if (!mounted) return;
        context.go('/signup/business-onboarding', extra: {
          'email': businessEmail,
          'businessName': bName,
          'businessType': _businessPrimaryType == 'organization'
              ? 'Private Limited Company'
              : 'Sole Proprietorship',
          'companySize': '1-10',
          'industry': 'Retail & Trade',
          'tempToken': token,
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isChild
                ? 'Child account successfully created! Please log in.'
                : 'Account successfully created! Please log in.',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegistering = false);
      final rawError = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException(400): ', '')
          .replaceAll('ApiException(409): ', '')
          .replaceAll('ApiException(500): ', '');
      final errorMsg = _sanitizeRegistrationError(rawError);

      if (errorMsg.toLowerCase().contains('taken') ||
          errorMsg.toLowerCase().contains('already exist') ||
          errorMsg.toLowerCase().contains('already in use')) {
        setState(() {
          if (isChild) {
            _childUsernameError = 'Username is already taken';
            _currentChildStep = 'mail';
          } else if (isBusiness) {
            _usernameError = 'Username is already taken';
            _currentBusinessStep = 'mail';
          } else {
            _usernameError = 'Username is already taken';
            _currentPersonalStep = 'mail';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username is already taken, please pick another.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (errorMsg.toLowerCase().contains('handle') ||
          errorMsg.toLowerCase().contains('character') ||
          errorMsg.toLowerCase().contains('letter') ||
          errorMsg.toLowerCase().contains('number') ||
          errorMsg.toLowerCase().contains('username') ||
          errorMsg.toLowerCase().contains('exceed') ||
          errorMsg.toLowerCase().contains('too long')) {
        setState(() {
          if (isChild) {
            _childUsernameError = errorMsg;
            _currentChildStep = 'mail';
          } else if (isBusiness) {
            _usernameError = errorMsg;
            _currentBusinessStep = 'mail';
          } else {
            _usernameError = errorMsg;
            _currentPersonalStep = 'mail';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ==========================================
  // BUSINESS REGISTRATION STEPS (Screenshots 1-4)
  // ==========================================

  Widget _buildBusinessTab({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAFAFE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessSizeCard({
    required String avatarLetter,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessDetailsStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Enter business details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Tabs: [ Secondary | Standard flow ] and [ Primary | Verified account ]
        Row(
          children: [
            Expanded(
              child: _buildBusinessTab(
                title: 'Secondary',
                subtitle: 'Standard flow',
                isSelected: _businessFlow == 'secondary',
                onTap: () {
                  setState(() => _businessFlow = 'secondary');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBusinessTab(
                title: 'Primary',
                subtitle: 'Verified account',
                isSelected: _businessFlow == 'primary',
                onTap: () {
                  setState(() => _businessFlow = 'primary');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_businessFlow == 'secondary') ...[
          // Screenshot 1: Secondary fields
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSimpleInput(
                    label: '',
                    controller: _businessSecondaryFirstNameController,
                    hintText: 'First Name',
                    errorText: _businessSecondaryFirstNameError,
                    maxLength: 30,
                    inputFormatters: _nameFormatters,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) {
                      if (_businessSecondaryFirstNameError != null) {
                        setState(() => _businessSecondaryFirstNameError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSimpleInput(
                    label: '',
                    controller: _businessSecondaryLastNameController,
                    hintText: 'Last Name',
                    errorText: _businessSecondaryLastNameError,
                    maxLength: 30,
                    inputFormatters: _nameFormatters,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) {
                      if (_businessSecondaryLastNameError != null) {
                        setState(() => _businessSecondaryLastNameError = null);
                      }
                    },
                  ),
                ),
              ],
            )
          else ...[
            _buildSimpleInput(
              label: '',
              controller: _businessSecondaryFirstNameController,
              hintText: 'First Name',
              errorText: _businessSecondaryFirstNameError,
              maxLength: 30,
              inputFormatters: _nameFormatters,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) {
                if (_businessSecondaryFirstNameError != null) {
                  setState(() => _businessSecondaryFirstNameError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildSimpleInput(
              label: '',
              controller: _businessSecondaryLastNameController,
              hintText: 'Last Name',
              errorText: _businessSecondaryLastNameError,
              maxLength: 30,
              inputFormatters: _nameFormatters,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) {
                if (_businessSecondaryLastNameError != null) {
                  setState(() => _businessSecondaryLastNameError = null);
                }
              },
            ),
          ],
          const SizedBox(height: 14),

          _buildSimpleInput(
            label: '',
            controller: _businessNameController,
            hintText: 'Business Name',
            errorText: _businessNameError,
            maxLength: 50,
            inputFormatters: _businessNameFormatters,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              if (_businessNameError != null) {
                setState(() => _businessNameError = null);
              }
            },
          ),
          const SizedBox(height: 14),

          _buildSimpleInput(
            label: '',
            controller: _businessIdController,
            hintText: 'Business ID Number',
            errorText: _businessIdError,
            onChanged: (v) {
              if (_businessIdError != null) {
                setState(() => _businessIdError = null);
              }
            },
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _handleBusinessBack,
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _validateAndProceedBusinessSecondary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ] else ...[
          // Screenshot 2: Primary fields
          const Center(
            child: Text(
              'Choose your business size to continue verification',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          _buildBusinessSizeCard(
            avatarLetter: 'S',
            title: 'Sole Proprietorship',
            subtitle: 'Verify instantly using your GSTIN',
            onTap: () {
              setState(() {
                _businessFlow = 'primary';
                _businessPrimaryType = 'sole_proprietorship';
                _currentBusinessStep = 'sole_proprietorship';
              });
            },
          ),
          const SizedBox(height: 12),

          _buildBusinessSizeCard(
            avatarLetter: 'L',
            title: 'Organization',
            subtitle: 'Verify via CIN, PAN, and GSTIN details',
            onTap: () {
              setState(() {
                _businessFlow = 'primary';
                _businessPrimaryType = 'organization';
                _currentBusinessStep = 'organization';
              });
            },
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              TextButton(
                onPressed: _handleBusinessBack,
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBusinessSoleProprietorshipStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Business Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Verify your identity to create a new organization account.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),

        // PAN Number
        const Text(
          'PAN Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSimpleInput(
                label: '',
                controller: _panController,
                hintText: 'E.G. ABCDE1234F',
                errorText: _panError,
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) {
                  if (_panError != null) {
                    setState(() => _panError = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: _isFetchingGstins ? null : _fetchGstinsForPan,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isFetchingGstins
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                      )
                    : const Text(
                        'Fetch GSTINs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Owner First Name & Last Name
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSimpleInput(
                  label: 'Owner First Name',
                  controller: _businessOwnerFirstNameController,
                  hintText: 'Ravi',
                  errorText: _businessOwnerFirstNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_businessOwnerFirstNameError != null) {
                      setState(() => _businessOwnerFirstNameError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleInput(
                  label: 'Owner Last Name',
                  controller: _businessOwnerLastNameController,
                  hintText: 'Kumar',
                  errorText: _businessOwnerLastNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_businessOwnerLastNameError != null) {
                      setState(() => _businessOwnerLastNameError = null);
                    }
                  },
                ),
              ),
            ],
          )
        else ...[
          _buildSimpleInput(
            label: 'Owner First Name',
            controller: _businessOwnerFirstNameController,
            hintText: 'Ravi',
            errorText: _businessOwnerFirstNameError,
            maxLength: 30,
            inputFormatters: _nameFormatters,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              if (_businessOwnerFirstNameError != null) {
                setState(() => _businessOwnerFirstNameError = null);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildSimpleInput(
            label: 'Owner Last Name',
            controller: _businessOwnerLastNameController,
            hintText: 'Kumar',
            errorText: _businessOwnerLastNameError,
            maxLength: 30,
            inputFormatters: _nameFormatters,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              if (_businessOwnerLastNameError != null) {
                setState(() => _businessOwnerLastNameError = null);
              }
            },
          ),
        ],
        const SizedBox(height: 14),

        // Business Name
        _buildSimpleInput(
          label: 'Business Name',
          controller: _businessNameController,
          hintText: 'djew',
          errorText: _businessNameError,
          maxLength: 50,
          inputFormatters: _businessNameFormatters,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            if (_businessNameError != null) {
              setState(() => _businessNameError = null);
            }
          },
        ),
        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _handleBusinessBack,
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _validateAndProceedSoleProprietorship,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF818CF8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Verify Identity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessOrganizationStep(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Business Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Verify your identity to create a new organization account.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),

        // CIN Number
        _buildSimpleInput(
          label: 'CIN Number',
          controller: _cinController,
          hintText: 'E.G. U72900KA2020PTC123456',
          errorText: _cinError,
          maxLength: 21,
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) {
            if (_cinError != null) {
              setState(() => _cinError = null);
            }
          },
        ),
        const SizedBox(height: 14),

        // PAN Number
        const Text(
          'PAN Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSimpleInput(
                label: '',
                controller: _panController,
                hintText: 'E.G. ABCDE1234F',
                errorText: _panError,
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) {
                  if (_panError != null) {
                    setState(() => _panError = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: _isFetchingGstins ? null : _fetchGstinsForPan,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isFetchingGstins
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                      )
                    : const Text(
                        'Fetch GSTINs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Owner First Name & Last Name
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSimpleInput(
                  label: 'Owner First Name',
                  controller: _businessOwnerFirstNameController,
                  hintText: 'Ravi',
                  errorText: _businessOwnerFirstNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_businessOwnerFirstNameError != null) {
                      setState(() => _businessOwnerFirstNameError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleInput(
                  label: 'Owner Last Name',
                  controller: _businessOwnerLastNameController,
                  hintText: 'Kumar',
                  errorText: _businessOwnerLastNameError,
                  maxLength: 30,
                  inputFormatters: _nameFormatters,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    if (_businessOwnerLastNameError != null) {
                      setState(() => _businessOwnerLastNameError = null);
                    }
                  },
                ),
              ),
            ],
          )
        else ...[
          _buildSimpleInput(
            label: 'Owner First Name',
            controller: _businessOwnerFirstNameController,
            hintText: 'Ravi',
            errorText: _businessOwnerFirstNameError,
            maxLength: 30,
            inputFormatters: _nameFormatters,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              if (_businessOwnerFirstNameError != null) {
                setState(() => _businessOwnerFirstNameError = null);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildSimpleInput(
            label: 'Owner Last Name',
            controller: _businessOwnerLastNameController,
            hintText: 'Kumar',
            errorText: _businessOwnerLastNameError,
            maxLength: 30,
            inputFormatters: _nameFormatters,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              if (_businessOwnerLastNameError != null) {
                setState(() => _businessOwnerLastNameError = null);
              }
            },
          ),
        ],
        const SizedBox(height: 14),

        // Business Name
        _buildSimpleInput(
          label: 'Business Name',
          controller: _businessNameController,
          hintText: 'djew',
          errorText: _businessNameError,
          maxLength: 50,
          inputFormatters: _businessNameFormatters,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            if (_businessNameError != null) {
              setState(() => _businessNameError = null);
            }
          },
        ),
        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _handleBusinessBack,
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _validateAndProceedOrganization,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF818CF8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Verify Identity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _fetchGstinsForPan() async {
    final pan = _panController.text.trim();
    if (pan.isEmpty) {
      setState(() => _panError = 'Please enter PAN Number first');
      return;
    }
    setState(() {
      _isFetchingGstins = true;
      _panError = null;
    });
    try {
      final gstins = await AuthRepository.fetchGstins(pan);
      if (!mounted) return;
      setState(() => _isFetchingGstins = false);
      if (gstins.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${gstins.length} GSTIN(s): ${gstins.first}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GSTIN check completed for this PAN.'),
            backgroundColor: Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFetchingGstins = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GSTIN check completed.'),
          backgroundColor: Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _validateAndProceedBusinessSecondary() {
    final fName = _businessSecondaryFirstNameController.text.trim();
    final lName = _businessSecondaryLastNameController.text.trim();
    final bName = _businessNameController.text.trim();
    final bId = _businessIdController.text.trim();

    setState(() {
      _businessSecondaryFirstNameError = validatePersonName(fName, 'First Name');
      _businessSecondaryLastNameError = validatePersonName(lName, 'Last Name');
      _businessNameError = validateBusinessName(bName);
      _businessIdError = bId.isEmpty ? 'Business ID Number is required' : null;
    });

    if (_businessSecondaryFirstNameError == null &&
        _businessSecondaryLastNameError == null &&
        _businessNameError == null &&
        _businessIdError == null) {
      setState(() {
        _currentBusinessStep = 'mail';
        if (_usernameController.text.trim().isEmpty) {
          final suggestions = _getDisplaySuggestions();
          if (suggestions.isNotEmpty) {
            _usernameController.text = suggestions.first;
          }
        }
      });
    }
  }

  void _validateAndProceedSoleProprietorship() {
    final pan = _panController.text.trim();
    final fName = _businessOwnerFirstNameController.text.trim();
    final lName = _businessOwnerLastNameController.text.trim();
    final bName = _businessNameController.text.trim();

    setState(() {
      _panError = pan.isEmpty ? 'PAN Number is required' : null;
      _businessOwnerFirstNameError = validatePersonName(fName, 'Owner First Name');
      _businessOwnerLastNameError = validatePersonName(lName, 'Owner Last Name');
      _businessNameError = validateBusinessName(bName);
    });

    if (_panError == null &&
        _businessOwnerFirstNameError == null &&
        _businessOwnerLastNameError == null &&
        _businessNameError == null) {
      setState(() {
        _currentBusinessStep = 'mail';
        if (_usernameController.text.trim().isEmpty) {
          final suggestions = _getDisplaySuggestions();
          if (suggestions.isNotEmpty) {
            _usernameController.text = suggestions.first;
          }
        }
      });
    }
  }

  void _validateAndProceedOrganization() {
    final cin = _cinController.text.trim();
    final pan = _panController.text.trim();
    final fName = _businessOwnerFirstNameController.text.trim();
    final lName = _businessOwnerLastNameController.text.trim();
    final bName = _businessNameController.text.trim();

    setState(() {
      _cinError = cin.isEmpty ? 'CIN Number is required' : null;
      _panError = pan.isEmpty ? 'PAN Number is required' : null;
      _businessOwnerFirstNameError = validatePersonName(fName, 'Owner First Name');
      _businessOwnerLastNameError = validatePersonName(lName, 'Owner Last Name');
      _businessNameError = validateBusinessName(bName);
    });

    if (_cinError == null &&
        _panError == null &&
        _businessOwnerFirstNameError == null &&
        _businessOwnerLastNameError == null &&
        _businessNameError == null) {
      setState(() {
        _currentBusinessStep = 'mail';
        if (_usernameController.text.trim().isEmpty) {
          final suggestions = _getDisplaySuggestions();
          if (suggestions.isNotEmpty) {
            _usernameController.text = suggestions.first;
          }
        }
      });
    }
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
            'Choose how you want to use Bnx Mail',
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
                      inputFormatters: _nameFormatters,
                      textCapitalization: TextCapitalization.words,
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
                      inputFormatters: _nameFormatters,
                      textCapitalization: TextCapitalization.words,
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
                      _ownerFirstNameError = validatePersonName(oFName, 'Owner First Name');
                      _ownerLastNameError = validatePersonName(oLName, 'Owner Last Name');
                      _businessNameError = bReg.isEmpty
                          ? 'Registration Number is required'
                          : null;
                      _phoneError = phone.isEmpty
                          ? 'Phone Number is required'
                          : null;
                    });

                    if (_ownerFirstNameError == null &&
                        _ownerLastNameError == null &&
                        _businessNameError == null &&
                        _phoneError == null) {
                      final today = DateTime.now().toIso8601String().substring(
                        0,
                        10,
                      );
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
                hintText: 'e.g. adminbtc',
                icon: Icons.alternate_email,
                controller: _adminUsernameController,
                errorText: _adminUsernameError,
                maxLength: 15,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(15),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => newValue.copyWith(
                      text: newValue.text.toLowerCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
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
                      _obscureRetypeAdminPassword =
                          !_obscureRetypeAdminPassword;
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
                          final aUName = _adminUsernameController.text.trim().toLowerCase();
                          _adminUsernameController.text = aUName;
                          final aPass = _adminPasswordController.text;
                          final aRepass = _retypeAdminPasswordController.text;

                          String? adminUserErr;
                          if (aUName.isEmpty) {
                            adminUserErr = 'Admin Username is required';
                          } else if (aUName.length < 6) {
                            adminUserErr = 'Username must be at least 6 characters';
                          } else if (aUName.length > 15) {
                            adminUserErr = 'Username cannot exceed 15 characters';
                          } else if (!RegExp(r'^[a-z]').hasMatch(aUName)) {
                            adminUserErr = 'Username must start with a lowercase letter';
                          } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(aUName)) {
                            adminUserErr = 'Only lowercase letters and numbers are allowed';
                          }

                          setState(() {
                            _adminUsernameError = adminUserErr;
                            _adminPasswordError = validatePasswordStrength(
                              aPass,
                            );

                            if (aRepass.isEmpty) {
                              _retypeAdminPasswordError =
                                  'Please retype your password';
                            } else if (aPass != aRepass) {
                              _retypeAdminPasswordError =
                                  'Passwords do not match';
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
                      inputFormatters: _nameFormatters,
                      textCapitalization: TextCapitalization.words,
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
                      inputFormatters: _nameFormatters,
                      textCapitalization: TextCapitalization.words,
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
                inputFormatters: [DateInputFormatter()],
                onChanged: (val) {
                  if (_childDobError != null) {
                    setState(() => _childDobError = null);
                  }
                  setState(() {});
                },
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF195BAC),
                  ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                        ),
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
                            _firstNameController.text =
                                _childFirstNameController.text;
                            _lastNameController.text =
                                _childLastNameController.text;
                            _dobController.text = _childDobController.text;
                            _personalGender = _childGender;
                          });
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text(
                          'Create a Personal Account instead',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
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
                      _childFirstNameError = validatePersonName(fName, 'First Name');
                      _childLastNameError = validatePersonName(lName, 'Last Name');

                      final dobErr = validateDob(dob);
                      if (dobErr != null) {
                        _childDobError = dobErr;
                      } else if (calculateAge(dob) >= 18) {
                        _childDobError =
                            'Child account is only for users under 18';
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _isSendingParentOtp
                        ? null
                        : () async {
                            final email = _parentEmailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              setState(
                                () => _parentEmailError =
                                    'Please enter a valid Parent Email address',
                              );
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
                            setState(
                              () => _parentEmailError =
                                  'Please enter a valid Parent Email address',
                            );
                            return;
                          }

                          if (otp.isEmpty) {
                            if (_parentOtpMessage == null) {
                              await _sendParentOtp();
                            } else {
                              setState(
                                () => _parentOtpError =
                                    'Please enter the 6-digit Consent Code',
                              );
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
                maxLength: 15,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(15),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => newValue.copyWith(
                      text: newValue.text.toLowerCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
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
                    final uName = _childUsernameController.text.trim().toLowerCase();
                    _childUsernameController.text = uName;
                    String? childUserErr;
                    if (uName.isEmpty) {
                      childUserErr = 'Username is required';
                    } else if (uName.length < 6) {
                      childUserErr = 'Username must be at least 6 characters';
                    } else if (uName.length > 15) {
                      childUserErr = 'Username cannot exceed 15 characters';
                    } else if (!RegExp(r'^[a-z]').hasMatch(uName)) {
                      childUserErr = 'Username must start with a lowercase letter';
                    } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(uName)) {
                      childUserErr = 'Only lowercase letters and numbers are allowed';
                    }
                    setState(() {
                      _childUsernameError = childUserErr;
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
                      _obscureChildRetypePassword =
                          !_obscureChildRetypePassword;
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
                            _childPasswordError = validatePasswordStrength(
                              pass,
                            );
                            _childRetypePasswordError = repass.isEmpty
                                ? 'Please confirm your password'
                                : (pass != repass
                                      ? 'Passwords do not match'
                                      : null);
                          });

                          if (_childPasswordError == null &&
                              _childRetypePasswordError == null) {
                            setState(() => _isRegistering = true);
                            try {
                              // Register the Child account
                              final token = await AuthRepository.register(
                                mode: 'CHILD',
                                firstName: _childFirstNameController.text
                                    .trim(),
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
                                  content: Text(
                                    'Child Account successfully created! Please log in.',
                                  ),
                                  backgroundColor: Color(0xFF22C55E),
                                ),
                              );
                              context.go('/login');
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isRegistering = false);
                              final rawError = e
                                  .toString()
                                  .replaceAll('Exception: ', '')
                                  .replaceAll('ApiException(400): ', '');
                              final errorMsg = _sanitizeRegistrationError(rawError);
                              if (errorMsg.toLowerCase().contains('username') ||
                                  errorMsg.toLowerCase().contains('exists') ||
                                  errorMsg.toLowerCase().contains('taken') ||
                                  errorMsg.toLowerCase().contains('exceed')) {
                                setState(() {
                                  _childUsernameError = errorMsg;
                                  _childStep = 4; // Go back to handle selection
                                });
                                final fName = _childFirstNameController.text
                                    .trim();
                                final lName = _childLastNameController.text
                                    .trim();
                                final dob = _childDobController.text.trim();
                                await _fetchSuggestions(
                                  fName,
                                  lName,
                                  dob,
                                  false,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Registration failed: $errorMsg',
                                    ),
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
                inputFormatters: _nameFormatters,
                textCapitalization: TextCapitalization.words,
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
                inputFormatters: _nameFormatters,
                textCapitalization: TextCapitalization.words,
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
                inputFormatters: [DateInputFormatter()],
                onChanged: (val) {
                  if (_dobError != null) {
                    setState(() => _dobError = null);
                  }
                  setState(() {});
                },
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF195BAC),
                  ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                        ),
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
                            _childFirstNameController.text =
                                _firstNameController.text;
                            _childLastNameController.text =
                                _lastNameController.text;
                            _childDobController.text = _dobController.text;
                            _childGender = _personalGender;
                          });
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text(
                          'Create a Child Account instead',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
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
                      _firstNameError = validatePersonName(fName, 'First Name');
                      _lastNameError = validatePersonName(lName, 'Last Name');

                      final dobErr = validateDob(dob);
                      if (dobErr != null) {
                        _dobError = dobErr;
                      } else {
                        _dobError = null;
                      }
                    });

                    if (_firstNameError == null &&
                        _lastNameError == null &&
                        _dobError == null) {
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
                            content: Text(
                              'Personal accounts are for users 18 and older. Redirected to Child Account registration.',
                            ),
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
                maxLength: 15,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(15),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => newValue.copyWith(
                      text: newValue.text.toLowerCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
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
                    final uName = _usernameController.text.trim().toLowerCase();
                    _usernameController.text = uName;
                    String? userErr;
                    if (uName.isEmpty) {
                      userErr = 'Username is required';
                    } else if (uName.length < 6) {
                      userErr = 'Username must be at least 6 characters';
                    } else if (uName.length > 15) {
                      userErr = 'Username cannot exceed 15 characters';
                    } else if (!RegExp(r'^[a-z]').hasMatch(uName)) {
                      userErr = 'Username must start with a lowercase letter';
                    } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(uName)) {
                      userErr = 'Only lowercase letters and numbers are allowed';
                    }
                    setState(() {
                      _usernameError = userErr;
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
                                : (pass != repass
                                      ? 'Passwords do not match'
                                      : null);
                          });

                          if (_passwordError == null &&
                              _retypePasswordError == null) {
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
                                  content: Text(
                                    'Account successfully created! Please log in.',
                                  ),
                                  backgroundColor: Color(0xFF22C55E),
                                ),
                              );
                              context.go('/login');
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isRegistering = false);
                              final rawError = e
                                  .toString()
                                  .replaceAll('Exception: ', '')
                                  .replaceAll('ApiException(400): ', '');
                              final errorMsg = _sanitizeRegistrationError(rawError);
                              if (errorMsg.toLowerCase().contains('username') ||
                                  errorMsg.toLowerCase().contains('exists') ||
                                  errorMsg.toLowerCase().contains('taken') ||
                                  errorMsg.toLowerCase().contains('exceed')) {
                                setState(() {
                                  _usernameError = errorMsg;
                                  _personalStep =
                                      2; // Go back to username selection step
                                });
                                final fName = _firstNameController.text.trim();
                                final lName = _lastNameController.text.trim();
                                final dob = _dobController.text.trim();
                                await _fetchSuggestions(
                                  fName,
                                  lName,
                                  dob,
                                  false,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Registration failed: $errorMsg',
                                    ),
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
                        maxLength: 15,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          LengthLimitingTextInputFormatter(15),
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) => newValue.copyWith(
                              text: newValue.text.toLowerCase(),
                              selection: newValue.selection,
                            ),
                          ),
                        ],
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
        : (isPersonal ? _personalStep : (isBusiness ? _businessStep : _step));
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
            color: activeStep == stepNum
                ? const Color(0xFF195BAC)
                : Colors.grey.shade300,
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

class DobSlashInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length && i < 8; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
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

class CountryOption {
  final String flag;
  final String code;
  final String name;
  const CountryOption({required this.flag, required this.code, required this.name});
}

const List<CountryOption> _countryOptions = [
  CountryOption(flag: '🇺🇸', code: '+1', name: 'United States'),
  CountryOption(flag: '🇮🇳', code: '+91', name: 'India'),
  CountryOption(flag: '🇬🇧', code: '+44', name: 'United Kingdom'),
  CountryOption(flag: '🇨🇦', code: '+1', name: 'Canada'),
  CountryOption(flag: '🇦🇺', code: '+61', name: 'Australia'),
  CountryOption(flag: '🇩🇪', code: '+49', name: 'Germany'),
  CountryOption(flag: '🇫🇷', code: '+33', name: 'France'),
  CountryOption(flag: '🇸🇬', code: '+65', name: 'Singapore'),
  CountryOption(flag: '🇦🇪', code: '+971', name: 'United Arab Emirates'),
];

class _ChoiceCard extends StatefulWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isMobile;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isMobile,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.isMobile ? null : 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
