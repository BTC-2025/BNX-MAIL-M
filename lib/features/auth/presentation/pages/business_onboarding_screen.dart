import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_service.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/account_provider.dart';
import '../../../../data/email_provider.dart';
import '../notifiers/auth_notifier.dart';

class BusinessOnboardingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const BusinessOnboardingScreen({super.key, this.initialData});

  @override
  ConsumerState<BusinessOnboardingScreen> createState() =>
      _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState
    extends ConsumerState<BusinessOnboardingScreen> {
  int _currentStep = 1; // 1: Business Profile, 2: Branding & Preferences
  bool _isSubmitting = false;

  // Step 1 Controllers & State
  String? _selectedBusinessType;
  final TextEditingController _industryController = TextEditingController();
  String? _selectedCompanySize;
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? _businessTypeError;
  String? _industryError;
  String? _companySizeError;

  // Step 2 Controllers & State
  String? _ownerAvatarPath;
  Uint8List? _ownerAvatarBytes;
  String? _ownerAvatarFilename;

  String? _companyLogoPath;
  Uint8List? _companyLogoBytes;
  String? _companyLogoFilename;

  String _selectedTimeZone = 'Asia/Kolkata (IST)';
  String _selectedLanguage = 'English';
  bool _acceptedTerms = true;
  String? _termsError;

  String _userEmail = '';

  final List<String> _businessTypeOptions = [
    'Sole Proprietorship',
    'Partnership',
    'Private Limited Company',
    'Public Limited Company',
    'Limited Liability Partnership (LLP)',
    'Non-Profit / NGO',
    'Other',
  ];

  final List<String> _companySizeOptions = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+',
  ];

  final List<String> _timeZoneOptions = [
    'Asia/Kolkata (IST)',
    'America/New_York (EST)',
    'America/Chicago (CST)',
    'America/Denver (MST)',
    'America/Los_Angeles (PST)',
    'Europe/London (GMT/BST)',
    'Europe/Paris (CET)',
    'Europe/Berlin (CET)',
    'Asia/Dubai (GST)',
    'Asia/Singapore (SGT)',
    'Asia/Hong_Kong (HKT)',
    'Asia/Tokyo (JST)',
    'Australia/Sydney (AEST)',
    'UTC',
  ];

  final List<String> _languageOptions = [
    'English',
    'Spanish (Español)',
    'French (Français)',
    'German (Deutsch)',
    'Hindi (हिन्दी)',
    'Tamil (தமிழ்)',
    'Telugu (తెలుగు)',
    'Arabic (العربية)',
    'Japanese (日本語)',
    'Chinese (Mandarin)',
  ];

  @override
  void initState() {
    super.initState();
    _initFromData();
  }

  Future<void> _initFromData() async {
    final passedEmail = widget.initialData?['email']?.toString() ?? '';
    final storedEmail = await TokenService.getUserEmail() ?? '';
    final effectiveEmail = passedEmail.isNotEmpty ? passedEmail : storedEmail;

    // Check if this specific business account has ALREADY completed onboarding
    if (effectiveEmail.isNotEmpty || storedEmail.isNotEmpty || passedEmail.isNotEmpty) {
      final alreadyOnboarded =
          (effectiveEmail.isNotEmpty &&
              await UserRepository.isBusinessAccountOnboarded(effectiveEmail)) ||
          (passedEmail.isNotEmpty &&
              await UserRepository.isBusinessAccountOnboarded(passedEmail)) ||
          (storedEmail.isNotEmpty &&
              await UserRepository.isBusinessAccountOnboarded(storedEmail));
      if (alreadyOnboarded && mounted) {
        context.go('/home');
        return;
      }
    }

    final initialBizType = widget.initialData?['businessType']?.toString();
    final initialIndustry = widget.initialData?['industry']?.toString();
    final initialCompanySize = widget.initialData?['companySize']?.toString();
    final initialWebsite = widget.initialData?['website']?.toString();
    final initialAddress = widget.initialData?['address']?.toString();

    if (mounted) {
      setState(() {
        _userEmail = effectiveEmail;
        if (initialBizType != null && _businessTypeOptions.contains(initialBizType)) {
          _selectedBusinessType = initialBizType;
        }
        if (initialIndustry != null && initialIndustry.isNotEmpty) {
          _industryController.text = initialIndustry;
        }
        if (initialCompanySize != null && _companySizeOptions.contains(initialCompanySize)) {
          _selectedCompanySize = initialCompanySize;
        }
        if (initialWebsite != null && initialWebsite.isNotEmpty) {
          _websiteController.text = initialWebsite;
        }
        if (initialAddress != null && initialAddress.isNotEmpty) {
          _addressController.text = initialAddress;
        }
      });
    }

    // Try prefilling from existing user profile / settings if already partially saved
    if (effectiveEmail.isNotEmpty) {
      try {
        final profile = await UserRepository.getProfileData(email: effectiveEmail);
        if (profile != null && mounted) {
          setState(() {
            if (_selectedBusinessType == null) {
              final bt = profile['businessType']?.toString();
              if (bt != null && _businessTypeOptions.contains(bt)) {
                _selectedBusinessType = bt;
              }
            }
            if (_industryController.text.isEmpty) {
              final ind = profile['industry']?.toString() ?? profile['occupation']?.toString();
              if (ind != null && ind.isNotEmpty) _industryController.text = ind;
            }
            if (_selectedCompanySize == null) {
              final cs = profile['companySize']?.toString() ?? profile['businessSize']?.toString();
              if (cs != null && _companySizeOptions.contains(cs)) {
                _selectedCompanySize = cs;
              }
            }
            if (_websiteController.text.isEmpty) {
              final ws = profile['businessWebsite']?.toString() ?? profile['website']?.toString();
              if (ws != null && ws.isNotEmpty) _websiteController.text = ws;
            }
            if (_addressController.text.isEmpty) {
              final addr = profile['workAddress']?.toString() ??
                  profile['businessAddress']?.toString() ??
                  profile['homeAddress']?.toString();
              if (addr != null && addr.isNotEmpty) _addressController.text = addr;
            }
            final tz = profile['timeZone']?.toString();
            if (tz != null && _timeZoneOptions.contains(tz)) {
              _selectedTimeZone = tz;
            }
            final lang = profile['language']?.toString();
            if (lang != null && _languageOptions.contains(lang)) {
              _selectedLanguage = lang;
            }
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _industryController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ── Step 1 Validation ───────────────────────────────────────────────────────
  bool _validateStep1() {
    bool isValid = true;
    setState(() {
      if (_selectedBusinessType == null || _selectedBusinessType!.isEmpty) {
        _businessTypeError = 'Please select a business type';
        isValid = false;
      } else {
        _businessTypeError = null;
      }

      if (_industryController.text.trim().isEmpty) {
        _industryError = 'Please enter your industry';
        isValid = false;
      } else {
        _industryError = null;
      }

      if (_selectedCompanySize == null || _selectedCompanySize!.isEmpty) {
        _companySizeError = 'Please select company size';
        isValid = false;
      } else {
        _companySizeError = null;
      }
    });
    return isValid;
  }

  void _onContinueStep1() {
    if (_validateStep1()) {
      setState(() => _currentStep = 2);
    }
  }

  // ── File Pickers ────────────────────────────────────────────────────────────
  Future<void> _pickOwnerAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        setState(() {
          _ownerAvatarFilename = file.name;
          _ownerAvatarBytes = file.bytes;
          _ownerAvatarPath = file.path;
        });
      }
    } catch (e) {
      print('[FILE PICKER ERROR] Owner avatar: $e');
    }
  }

  Future<void> _pickCompanyLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        setState(() {
          _companyLogoFilename = file.name;
          _companyLogoBytes = file.bytes;
          _companyLogoPath = file.path;
        });
      }
    } catch (e) {
      print('[FILE PICKER ERROR] Company logo: $e');
    }
  }

  // ── Step 2 Completion & API Integration ────────────────────────────────────
  Future<void> _onCompleteOnboarding() async {
    if (!_acceptedTerms) {
      setState(() {
        _termsError = 'You must accept the Terms of Service and Privacy Policy to continue.';
      });
      return;
    }
    setState(() {
      _termsError = null;
      _isSubmitting = true;
    });

    final email = _userEmail.isNotEmpty
        ? _userEmail
        : (await TokenService.getUserEmail() ?? '');

    try {
      // 1. Update Profile fields
      final profilePayload = {
        'businessType': _selectedBusinessType,
        'industry': _industryController.text.trim(),
        'companySize': _selectedCompanySize,
        'businessWebsite': _websiteController.text.trim(),
        'workAddress': _addressController.text.trim(),
        'businessAddress': _addressController.text.trim(),
        'timeZone': _selectedTimeZone,
        'language': _selectedLanguage,
        'businessOnboarded': true,
        'businessOnboardingCompleted': true,
      };

      await UserRepository.updateProfile(profilePayload, email: email);

      // 2. Update Settings fields
      await UserRepository.updateSettings({
        'timeZone': _selectedTimeZone,
        'language': _selectedLanguage,
        'businessType': _selectedBusinessType,
        'companySize': _selectedCompanySize,
        'businessOnboarded': true,
        'businessOnboardingCompleted': true,
      });

      // 3. Upload Owner Profile Picture if selected
      if (_ownerAvatarBytes != null || (_ownerAvatarPath != null && _ownerAvatarPath!.isNotEmpty)) {
        try {
          await UserRepository.uploadAvatar(
            email,
            _ownerAvatarPath ?? '',
            bytes: _ownerAvatarBytes,
            filename: _ownerAvatarFilename,
          );
        } catch (e) {
          print('[AVATAR UPLOAD EXCEPTION] $e');
        }
      }

      // 4. Upload / Save Company Logo if selected
      if (_companyLogoBytes != null || (_companyLogoPath != null && _companyLogoPath!.isNotEmpty)) {
        try {
          final logoRes = await ApiClient.uploadProfilePicture(
            _companyLogoPath,
            bytes: _companyLogoBytes,
            filename: _companyLogoFilename ?? 'company_logo.png',
          );
          final logoData = (logoRes['data'] as Map<String, dynamic>?) ?? logoRes;
          final logoUrl = logoData['profilePictureUrl'] ?? logoData['avatarUrl'];
          if (logoUrl != null) {
            await UserRepository.updateProfile({'companyLogo': logoUrl}, email: email);
          }
        } catch (e) {
          print('[LOGO UPLOAD EXCEPTION] $e');
        }
      }

      // 5. CRITICAL: Mark business onboarding as COMPLETED (Appears ONLY ONCE!)
      if (email.isNotEmpty) {
        await TokenService.setBusinessOnboardingCompleted(email, completed: true);
        if (email.contains('@')) {
          await TokenService.setBusinessOnboardingCompleted(
            email.split('@').first,
            completed: true,
          );
        }
      }
      final currentStored = await TokenService.getUserEmail();
      if (currentStored != null && currentStored.isNotEmpty && currentStored != email) {
        await TokenService.setBusinessOnboardingCompleted(currentStored, completed: true);
      }

      // 6. Ensure Auth status and context switch
      ref.read(authProvider.notifier).login();
      if (email.isNotEmpty) {
        ref.read(emailProvider.notifier).switchAccountContext(email);
        ref.read(accountsProvider.notifier).loadMailboxes();
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Bnx mail for Business! Setup complete.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Proceed into the business account dashboard / inbox
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      print('[BUSINESS ONBOARDING SUBMIT ERROR] $e');

      // Still mark completed if local profile updated so user is never locked out
      if (email.isNotEmpty) {
        await TokenService.setBusinessOnboardingCompleted(email, completed: true);
        if (email.contains('@')) {
          await TokenService.setBusinessOnboardingCompleted(
            email.split('@').first,
            completed: true,
          );
        }
      }
      ref.read(authProvider.notifier).login();
      if (mounted) {
        context.go('/home');
      }
    }
  }

  // ── Build UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 640;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 36 : 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : 22,
                  vertical: isDesktop ? 38 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Title
                    const Text(
                      'Welcome to Bnx mail for Business',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Header Subtitle
                    const Text(
                      "Let's get your organization set up.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Bar (2 segments)
                    _buildProgressBar(),
                    const SizedBox(height: 28),

                    // Step Title
                    Text(
                      _currentStep == 1
                          ? 'Step 1: Business Profile'
                          : 'Step 2: Branding & Preferences',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step Form Content
                    if (_currentStep == 1)
                      _buildStep1Content(isDesktop)
                    else
                      _buildStep2Content(isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress Bar ───────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(100),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final filledWidth = _currentStep == 1 ? totalWidth * 0.5 : totalWidth;

          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: 6,
              width: filledWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Step 1 Form: Business Profile ──────────────────────────────────────────
  Widget _buildStep1Content(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Business Type * & Industry *
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Business Type *',
                  value: _selectedBusinessType,
                  placeholder: 'Select type',
                  items: _businessTypeOptions,
                  error: _businessTypeError,
                  onChanged: (val) {
                    setState(() {
                      _selectedBusinessType = val;
                      _businessTypeError = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Industry *',
                  controller: _industryController,
                  placeholder: 'e.g. Technology, Retail',
                  error: _industryError,
                  onChanged: (val) {
                    if (_industryError != null && val.isNotEmpty) {
                      setState(() => _industryError = null);
                    }
                  },
                ),
              ),
            ],
          )
        else ...[
          _buildDropdownField(
            label: 'Business Type *',
            value: _selectedBusinessType,
            placeholder: 'Select type',
            items: _businessTypeOptions,
            error: _businessTypeError,
            onChanged: (val) {
              setState(() {
                _selectedBusinessType = val;
                _businessTypeError = null;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Industry *',
            controller: _industryController,
            placeholder: 'e.g. Technology, Retail',
            error: _industryError,
            onChanged: (val) {
              if (_industryError != null && val.isNotEmpty) {
                setState(() => _industryError = null);
              }
            },
          ),
        ],

        const SizedBox(height: 16),

        // Row 2: Company Size * & Website URL
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Company Size *',
                  value: _selectedCompanySize,
                  placeholder: 'Select size',
                  items: _companySizeOptions,
                  error: _companySizeError,
                  onChanged: (val) {
                    setState(() {
                      _selectedCompanySize = val;
                      _companySizeError = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Website URL',
                  controller: _websiteController,
                  placeholder: 'https://',
                  keyboardType: TextInputType.url,
                ),
              ),
            ],
          )
        else ...[
          _buildDropdownField(
            label: 'Company Size *',
            value: _selectedCompanySize,
            placeholder: 'Select size',
            items: _companySizeOptions,
            error: _companySizeError,
            onChanged: (val) {
              setState(() {
                _selectedCompanySize = val;
                _companySizeError = null;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Website URL',
            controller: _websiteController,
            placeholder: 'https://',
            keyboardType: TextInputType.url,
          ),
        ],

        const SizedBox(height: 16),

        // Row 3: Business Address
        _buildTextAreaField(
          label: 'Business Address',
          controller: _addressController,
          placeholder: '',
        ),

        const SizedBox(height: 28),

        // Continue Button
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _onContinueStep1,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2 Form: Branding & Preferences ────────────────────────────────────
  Widget _buildStep2Content(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Profile Picture (Owner) & Company Logo
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFilePickerField(
                  label: 'Profile Picture (Owner)',
                  filename: _ownerAvatarFilename,
                  onPickFile: _pickOwnerAvatar,
                  onClear: () {
                    setState(() {
                      _ownerAvatarFilename = null;
                      _ownerAvatarBytes = null;
                      _ownerAvatarPath = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilePickerField(
                  label: 'Company Logo',
                  filename: _companyLogoFilename,
                  onPickFile: _pickCompanyLogo,
                  onClear: () {
                    setState(() {
                      _companyLogoFilename = null;
                      _companyLogoBytes = null;
                      _companyLogoPath = null;
                    });
                  },
                ),
              ),
            ],
          )
        else ...[
          _buildFilePickerField(
            label: 'Profile Picture (Owner)',
            filename: _ownerAvatarFilename,
            onPickFile: _pickOwnerAvatar,
            onClear: () {
              setState(() {
                _ownerAvatarFilename = null;
                _ownerAvatarBytes = null;
                _ownerAvatarPath = null;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildFilePickerField(
            label: 'Company Logo',
            filename: _companyLogoFilename,
            onPickFile: _pickCompanyLogo,
            onClear: () {
              setState(() {
                _companyLogoFilename = null;
                _companyLogoBytes = null;
                _companyLogoPath = null;
              });
            },
          ),
        ],

        const SizedBox(height: 16),

        // Row 2: Time Zone & Language
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Time Zone',
                  value: _selectedTimeZone,
                  placeholder: 'Select timezone',
                  items: _timeZoneOptions,
                  isHighlighted: true,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedTimeZone = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Language',
                  value: _selectedLanguage,
                  placeholder: 'Select language',
                  items: _languageOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLanguage = val);
                  },
                ),
              ),
            ],
          )
        else ...[
          _buildDropdownField(
            label: 'Time Zone',
            value: _selectedTimeZone,
            placeholder: 'Select timezone',
            items: _timeZoneOptions,
            isHighlighted: true,
            onChanged: (val) {
              if (val != null) setState(() => _selectedTimeZone = val);
            },
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Language',
            value: _selectedLanguage,
            placeholder: 'Select language',
            items: _languageOptions,
            onChanged: (val) {
              if (val != null) setState(() => _selectedLanguage = val);
            },
          ),
        ],

        const SizedBox(height: 20),

        // Terms of Service & Privacy Policy Checkbox
        InkWell(
          onTap: () {
            setState(() {
              _acceptedTerms = !_acceptedTerms;
              if (_acceptedTerms) _termsError = null;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _acceptedTerms,
                    activeColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(
                      color: Color(0xFF94A3B8),
                      width: 1.5,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _acceptedTerms = val ?? false;
                        if (_acceptedTerms) _termsError = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w400,
                      ),
                      children: [
                        TextSpan(text: 'I accept the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_termsError != null) ...[
          const SizedBox(height: 6),
          Text(
            _termsError!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
          ),
        ],

        const SizedBox(height: 28),

        // Bottom Actions: Back button & Complete Onboarding
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      setState(() => _currentStep = 1);
                    },
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _onCompleteOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Complete Onboarding',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helper Form Widgets ───────────────────────────────────────────────────
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    String? error,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: placeholder,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String placeholder,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? error,
    bool isHighlighted = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFEF4444)
                  : (isHighlighted
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFE2E8F0)),
              width: isHighlighted ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                placeholder,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
              borderRadius: BorderRadius.circular(10),
              dropdownColor: Colors.white,
              items: items.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(
                    opt,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
          ),
        ],
      ],
    );
  }

  Widget _buildTextAreaField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Stack(
            children: [
              TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              // Subtle corner resize handle indicator matching screenshot
              Positioned(
                bottom: 0,
                right: 0,
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 14,
                  color: const Color(0xFFCBD5E1).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilePickerField({
    required String label,
    required String? filename,
    required VoidCallback onPickFile,
    required VoidCallback onClear,
  }) {
    final hasFile = filename != null && filename.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: onPickFile,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE0E7FF),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Choose file',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasFile ? filename : 'No file chosen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: hasFile ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            if (hasFile)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: const Color(0xFF64748B),
                tooltip: 'Remove',
              ),
          ],
        ),
      ],
    );
  }
}
