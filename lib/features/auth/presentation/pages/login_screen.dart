import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
