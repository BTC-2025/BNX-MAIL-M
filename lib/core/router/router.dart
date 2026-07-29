import 'package:flutter/material.dart';
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
          builder: (context, state) {
            return const ProfileScreen();
          },
        ),
        GoRoute(
          path: '/email/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return EmailBody(emailId: id);
          },
        ),
        GoRoute(
          path: '/draft/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DraftDetailScreen(draftId: id);
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
