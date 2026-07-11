import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/dashboard_shell.dart';
import '../../features/inbox/presentation/email_list_screen.dart';
import '../../features/dashboard/presentation/colab_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/help/presentation/help_support_screen.dart';
import '../../features/ai/presentation/analytics_screen.dart';
import '../widgets/email_body.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return DashboardShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
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
      ],
    ),
  ],
);
