import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/notifiers/auth_notifier.dart';

import '../../../../core/network/token_service.dart';
import '../../../../data/email_provider.dart';
import '../../../../data/account_provider.dart';
import '../../../../data/colab_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    _progressController.forward();
    _fadeController.forward();

    Timer(const Duration(milliseconds: 2800), () async {
      if (mounted) {
        final isLoggedIn = await TokenService.hasToken();
        if (isLoggedIn) {
          ref.read(authProvider.notifier).login();
          await ref.read(accountsProvider.notifier).loadMailboxes();
          await ref.read(colabListProvider.notifier).loadGroups();
          ref.read(colabInvitationsProvider.notifier).loadInvitations();
          // Pre-fetch all emails from backend to populate inbox, sent, draft folders
          ref.read(emailProvider.notifier).initialLoad();
          if (mounted) {
            context.go('/home');
          }
        } else {
          ref.read(authProvider.notifier).logout();
          context.go('/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F7FC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // HD Animated Brand Logo Container
              FadeTransition(
                opacity: _fadeController,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF195bac,
                          ).withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/bnx_mail_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return CustomPaint(painter: _LogoPainter());
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Brand Name with slide-up fade transition
              FadeTransition(
                opacity: _fadeController,
                child: const Text(
                  'BNXmail',
                  style: TextStyle(
                    color: Color(0xFF195bac),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // HD Animated loading bar
              SizedBox(
                width: 140,
                height: 4,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progressController.value,
                        backgroundColor: const Color(0xFFD0E3F5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF195bac),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Spacer(flex: 2),
              // Tagline
              Text(
                'Secure. Fast. Reliable.',
                style: TextStyle(
                  color: const Color(0xFF195bac).withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF195bac)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;

    // Draw envelope outline matching the logo
    final envelopePath = Path()
      ..moveTo(width * 0.1, height * 0.4)
      ..lineTo(width * 0.1, height * 0.8)
      ..quadraticBezierTo(
        width * 0.1,
        height * 0.85,
        width * 0.15,
        height * 0.85,
      )
      ..lineTo(width * 0.85, height * 0.85)
      ..quadraticBezierTo(width * 0.9, height * 0.85, width * 0.9, height * 0.8)
      ..lineTo(width * 0.9, height * 0.4)
      ..moveTo(width * 0.1, height * 0.4)
      ..lineTo(width * 0.45, height * 0.65)
      ..quadraticBezierTo(
        width * 0.5,
        height * 0.68,
        width * 0.55,
        height * 0.65,
      )
      ..lineTo(width * 0.9, height * 0.4);

    canvas.drawPath(envelopePath, paint);

    // Draw a simplified bird shape taking off inside the envelope top
    final birdPaint = Paint()
      ..color = const Color(0xFF195bac)
      ..style = PaintingStyle.fill;

    final birdPath = Path()
      ..moveTo(width * 0.35, height * 0.42)
      ..quadraticBezierTo(
        width * 0.3,
        height * 0.28,
        width * 0.15,
        height * 0.22,
      )
      ..quadraticBezierTo(
        width * 0.35,
        height * 0.22,
        width * 0.5,
        height * 0.38,
      )
      ..quadraticBezierTo(
        width * 0.7,
        height * 0.28,
        width * 0.85,
        height * 0.28,
      )
      ..quadraticBezierTo(
        width * 0.65,
        height * 0.45,
        width * 0.42,
        height * 0.45,
      )
      ..close();

    canvas.drawPath(birdPath, birdPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
