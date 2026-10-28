import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bnx_mail/features/settings/presentation/settings_screen.dart';
import 'package:flutter_bnx_mail/core/widgets/compose_dialog.dart';
import 'package:flutter_bnx_mail/core/widgets/avatar_widget.dart';

void main() {
  group('Casbox Connections Avatar Tests', () {
    testWidgets('AvatarWidget renders letter fallback when no photo is provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'itsokletssee123',
              avatarUrl: null,
              size: 34,
              fontSize: 13,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('I'), findsOneWidget);
    });

    testWidgets('AvatarWidget handles network/file/remote URL gracefully',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'Ravi K',
              avatarUrl: '/api/users/profile-picture/ravinew2004',
              size: 34,
              fontSize: 13,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AvatarWidget), findsOneWidget);
    });
  });

  group('Compose Dialog Mobile Overflow Tests', () {
    testWidgets('ComposeDialog renders on narrow 320px screen without overflow in Mail and Casbox modes',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/compose',
        routes: [
          GoRoute(
            path: '/compose',
            builder: (context, state) => const Scaffold(body: ComposeDialog()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Attach'), findsOneWidget);

      // Switch to Casbox tab
      await tester.tap(find.text('Casbox'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Send via Casbox'), findsOneWidget);
      expect(find.text('Attach'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });
  });

  group('Settings Tabs & Subsections "Show More" Tests', () {
    testWidgets('Settings screen renders 4 primary tabs and a Show more tab',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar should have 4 primary tabs + 1 "Show more" tab
      expect(find.text('Accounts & Mailboxes'), findsOneWidget);
      expect(find.text('General & Composing'), findsOneWidget);
      expect(find.text('Notifications & Quiet'), findsOneWidget);
      expect(find.text('Appearance & Layout'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Show more'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Show more'), findsOneWidget);
    });

    testWidgets('Tapping Show more opens popup with remaining tabs including Active Sessions',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll horizontally to bring Show more fully onto the screen
      await tester.drag(find.byType(ListView).first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Tap "Show more"
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();

      expect(find.text('Security & Recovery'), findsOneWidget);
      expect(find.text('Labels & Sidebar'), findsOneWidget);
      expect(find.text('Active Sessions & Logs'), findsOneWidget);

      // Select Active Sessions & Logs
      await tester.tap(find.text('Active Sessions & Logs'));
      await tester.pumpAndSettle();

      // Title should be visible inside Active Sessions tab
      expect(find.text('Active Login Sessions'), findsOneWidget);
      expect(find.text('Connected Applications'), findsOneWidget);
      expect(find.text('Recent Activity Logs'), findsOneWidget);
    });
  });
}
