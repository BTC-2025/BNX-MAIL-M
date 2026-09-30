import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/auth_constants.dart';
import '../../../../core/widgets/auth_text_field.dart';
import '../../../../core/widgets/auth_button.dart';
import '../notifiers/login_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../../../../data/email_provider.dart';
import '../../../../data/account_provider.dart';
import '../../../../data/colab_provider.dart';
import '../../../../data/app_state_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginNotifier = LoginNotifier();
  bool _staySignedIn = false;
  final bool _obscurePassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _logoSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _cardSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loginNotifier.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleSignIn() async {
    final success = await _loginNotifier.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      final newEmail = _emailController.text.trim().toLowerCase();
      // Instantly set logged in state and navigate to /home
      ref.read(authProvider.notifier).login();
      context.go('/home');

      // Update provider contexts to the new account to prevent old data flashing
      ref.read(emailProvider.notifier).switchAccountContext(newEmail);
      ref.read(customLabelsProvider.notifier).switchAccountContext(newEmail);
      ref.read(colabListProvider.notifier).switchAccountContext(newEmail);
      ref.read(colabInvitationsProvider.notifier).switchAccountContext(newEmail);
      ref.read(casboxMessagesProvider.notifier).switchAccountContext(newEmail);

      // Load mailboxes in parallel
      ref.read(accountsProvider.notifier).loadMailboxes();
    } else if (mounted && _loginNotifier.value.generalError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loginNotifier.value.generalError!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopOS = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);

    if (isDesktopOS) {
      return _buildDesktopLogin(context);
    }
    return _buildMobileLogin(context);
  }

  Widget _buildDesktopLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
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
              padding: const EdgeInsets.fromLTRB(40, 42, 40, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/bnx_mail_logo.png',
                    height: 52,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'lib/standalone_macos_storage/assets/bnx_mail_logo.png',
                      height: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.mark_email_unread_rounded,
                        size: 52,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Welcome Back',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Securely access your BNX Mail account.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Form
                  ValueListenableBuilder<LoginState>(
                    valueListenable: _loginNotifier,
                    builder: (context, state, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.generalError != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      state.generalError!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          Text(
                            'Email Address',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: state.emailError != null
                                    ? Colors.redAccent
                                    : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'you@bnxmail.com',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (_) => _handleSignIn(),
                            ),
                          ),
                          if (state.emailError != null) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                state.emailError!,
                                style: GoogleFonts.inter(
                                  color: Colors.redAccent,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            'Password',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: state.passwordError != null
                                    ? Colors.redAccent
                                    : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '••••••••',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 2,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (_) => _handleSignIn(),
                            ),
                          ),
                          if (state.passwordError != null) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                state.passwordError!,
                                style: GoogleFonts.inter(
                                  color: Colors.redAccent,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(
                                      () => _staySignedIn = !_staySignedIn),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 17,
                                        height: 17,
                                        decoration: BoxDecoration(
                                          color: _staySignedIn
                                              ? const Color(0xFF2563EB)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(4.5),
                                          border: Border.all(
                                            color: _staySignedIn
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFFCBD5E1),
                                            width: 1.4,
                                          ),
                                        ),
                                        child: _staySignedIn
                                            ? const Icon(
                                                Icons.check,
                                                size: 12,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Stay signed in',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Password reset instructions will be sent to your email.'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Forgot password?',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: state.isLoading ? null : _handleSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF93C5FD),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: state.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: GoogleFonts.inter(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => context.go('/register'),
                                  child: Text(
                                    'Create one for free',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthConstants.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    minWidth: constraints.maxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuthConstants.paddingMedium,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Logo Section
                        SlideTransition(
                          position: _logoSlideAnimation,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AuthConstants.borderRadiusMedium,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/bnx_mail_logo.png',
                                  height: 60,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.mail_outline,
                                    size: 60,
                                    color: AuthConstants.primaryBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'BNXmail',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AuthConstants.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Secure communication, simplified.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AuthConstants.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Login Card
                        SlideTransition(
                          position: _cardSlideAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(
                              AuthConstants.paddingLarge,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AuthConstants.borderRadiusLarge,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ValueListenableBuilder<LoginState>(
                              valueListenable: _loginNotifier,
                              builder: (context, state, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthTextField(
                                      label: 'Email Address',
                                      hintText: 'name@bnxmail.com',
                                      prefixIcon: Icons.alternate_email,
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      validator: (val) => state.emailError,
                                    ),
                                    if (state.emailError != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        state.emailError!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(
                                      height: AuthConstants.verticalSpacing,
                                    ),
                                    AuthTextField(
                                      label: 'Password',
                                      hintText: '••••••••',
                                      prefixIcon: Icons.lock_outline,
                                      isPassword: true,
                                      controller: _passwordController,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      validator: (val) => state.passwordError,
                                    ),
                                    if (state.passwordError != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        state.passwordError!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 32),
                                    AuthButton(
                                      text: 'Sign In',
                                      isLoading: state.isLoading,
                                      onPressed: state.isLoading
                                          ? null
                                          : _handleSignIn,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'New here? ',
                              style: TextStyle(
                                color: AuthConstants.textSecondary,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                context.go('/register');
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  'Create an Account',
                                  style: TextStyle(
                                    color: AuthConstants.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40), // Extra padding for scroll
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
