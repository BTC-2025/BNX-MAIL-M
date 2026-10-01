import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/dashboard_shell.dart';
import '../../features/dashboard/presentation/splash_screen.dart';
import '../../features/inbox/presentation/email_list_screen.dart';
import '../../features/dashboard/presentation/colab_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/help/presentation/help_support_screen.dart';
import '../../features/ai/presentation/analytics_screen.dart';
import '../../features/inbox/presentation/compose_screen.dart';
import '../../features/inbox/presentation/draft_detail_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_account_type_screen.dart';
import '../widgets/email_body.dart';
import '../../features/dashboard/presentation/connect_settings_screen.dart';
import '../../features/profile/presentation/manage_account_screen.dart';
import '../../standalone_macos_storage/standalone_macos_storage.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterAccountTypeScreen(),
    ),
    GoRoute(
      path: '/manage-account',
      builder: (context, state) => const ManageAccountScreen(),
    ),
    GoRoute(
      path: '/storage',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: MacOsStoragePage(
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          backButtonTooltip: 'Back to Mail',
        ),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return DashboardShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) {
            return const EmailListScreen();
          },
        ),
        GoRoute(
          path: '/colab',
          builder: (context, state) {
            return const ColabScreen();
          },
        ),
        GoRoute(
          path: '/compose',
          builder: (context, state) {
            return const ComposeScreen();
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) {
            return const SettingsScreen();
          },
        ),
        GoRoute(
          path: '/profile',
          redirect: (context, state) {
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              return '/manage-account';
            }
            return null;
          },
          builder: (context, state) {
            return const ProfileScreen();
          },
        ),
        GoRoute(
          path: '/email/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              return NoTransitionPage(
                key: state.pageKey,
                child: EmailBody(emailId: id),
              );
            }
            return MaterialPage(
              key: state.pageKey,
              child: EmailBody(emailId: id),
            );
          },
        ),
        GoRoute(
          path: '/draft/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              return NoTransitionPage(
                key: state.pageKey,
                child: DraftDetailScreen(draftId: id),
              );
            }
            return MaterialPage(
              key: state.pageKey,
              child: DraftDetailScreen(draftId: id),
            );
          },
        ),
        GoRoute(
          path: '/help',
          builder: (context, state) {
            return const HelpSupportScreen();
          },
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) {
            return const AnalyticsScreen();
          },
        ),
        GoRoute(
          path: '/connect-settings',
          builder: (context, state) {
            return const ConnectSettingsScreen();
          },
        ),
        GoRoute(
          path: '/manage-account',
          builder: (context, state) {
            return const ManageAccountScreen();
          },
        ),
      ],
    ),
  ],
);
