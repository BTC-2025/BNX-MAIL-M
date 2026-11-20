import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bnx_mail/features/help/presentation/help_support_screen.dart';
import 'package:flutter_bnx_mail/core/widgets/sidebar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HelpSupportScreen UI & Interaction Tests', () {
    testWidgets('renders SubHeaderBar, Hero Banner, Quick Action Cards, and Cards', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HelpSupportScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sub-header bar
      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);

      // Hero banner
      expect(find.text('How can we help you today?'), findsOneWidget);
      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('2FA setup'), findsOneWidget);
      expect(find.text('Storage limit'), findsOneWidget);
      expect(find.text('Mobile verification'), findsOneWidget);

      // Quick action cards & Form Header
      expect(find.text('Raise a Ticket'), findsOneWidget);
      expect(find.text('Raise a Support Ticket'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);
      expect(find.text('Browse FAQs'), findsOneWidget);

      // Form
      expect(find.text('ISSUE SUBJECT'), findsOneWidget);
      expect(find.text('PRIORITY'), findsOneWidget);
      expect(find.text('DETAILED EXPLANATION'), findsOneWidget);
      expect(find.text('Submit Ticket'), findsOneWidget);

      // Support Log (empty state)
      expect(find.text('My Support Log'), findsOneWidget);
      expect(find.text('0 LOGGED'), findsOneWidget);
      expect(find.text('No filed tickets detected in your system history.'), findsOneWidget);

      // FAQs
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
      expect(find.text('How do I reset my password?'), findsOneWidget);
      expect(find.text('Can I use the app offline?'), findsOneWidget);

      // Direct Support Channels
      expect(find.text('Direct Support Channels'), findsOneWidget);
      expect(find.text('support@beta-softnet.com'), findsOneWidget);
      expect(find.text('beta-softnet.com'), findsOneWidget);
    });

    testWidgets('Submitting a support ticket adds it to My Support Log', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HelpSupportScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find subject textfield by hint
      final subjectFinder = find.widgetWithText(TextField, 'e.g. Unable to send emails');
      expect(subjectFinder, findsOneWidget);
      await tester.ensureVisible(subjectFinder);
      await tester.enterText(subjectFinder, 'Unable to sync mailbox');

      // Find explanation textfield
      final explanationFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.maxLines == 4,
      );
      expect(explanationFinder, findsOneWidget);
      await tester.ensureVisible(explanationFinder);
      await tester.enterText(explanationFinder, 'Getting a network timeout error on sync.');

      // Tap Submit Ticket
      final submitBtn = find.widgetWithText(ElevatedButton, 'Submit Ticket');
      expect(submitBtn, findsOneWidget);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Log count should now be 1 LOGGED
      final loggedFinder = find.text('1 LOGGED');
      await tester.ensureVisible(loggedFinder);
      expect(loggedFinder, findsOneWidget);
      expect(find.text('Unable to sync mailbox'), findsOneWidget);
    });

    testWidgets('FAQ item expands and collapses on tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HelpSupportScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final questionFinder = find.text('How do I reset my password?');
      expect(questionFinder, findsOneWidget);
      await tester.ensureVisible(questionFinder);

      // Tap to expand
      await tester.tap(questionFinder);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('To reset your password, navigate to Settings > Security'),
        findsOneWidget,
      );
    });

    testWidgets('Renders on Mobile screen width without errors', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HelpSupportScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('How can we help you today?'), findsOneWidget);
      expect(find.text('Raise a Ticket'), findsOneWidget);
      expect(find.text('Submit Ticket'), findsOneWidget);
    });

    testWidgets('Sidebar displays Support & Help and navigates to /help', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: Sidebar(),
              ),
            ),
            GoRoute(
              path: '/help',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Help Screen Destination')),
              ),
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final helpSidebarItem = find.text('Support & Help');
        expect(helpSidebarItem, findsOneWidget);

        await tester.tap(helpSidebarItem);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Help Screen Destination'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
