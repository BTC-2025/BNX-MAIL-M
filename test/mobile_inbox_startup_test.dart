import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/core/router/router.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/models/account_model.dart';
import 'package:flutter_bnx_mail/data/account_provider.dart';
import 'package:flutter_bnx_mail/data/email_provider.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';
import 'package:flutter_bnx_mail/core/widgets/top_search_bar.dart';

class TestEmailNotifier extends EmailNotifier {
  TestEmailNotifier(List<EmailModel> initialEmails) : super() {
    state = EmailState(emails: initialEmails, isLoading: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockEmails = [
    // Draft email
    EmailModel(
      id: 'draft-1',
      senderName: 'Draft',
      senderEmail: 'ravinew2004@bnxmail.com',
      recipient: '',
      subject: 'Meeting Request: Discussion on Project Updates',
      body: 'Hi [Name],',
      date: DateTime(2026, 10, 24, 10, 0),
      isRead: true,
      isDraft: true,
      memberOfFolders: const {'Draft'},
    ),
    // Sent email
    EmailModel(
      id: 'sent-1',
      senderName: 'Ravi Kumar',
      senderEmail: 'ravinew2004@bnxmail.com',
      recipient: 'connectwithravi2004@gmail.com',
      subject: 'Thank you for your support',
      body: 'Hi [Name],',
      date: DateTime(2026, 10, 24, 9, 30),
      isRead: true,
      isSent: true,
      memberOfFolders: const {'Sent'},
    ),
    // Received Inbox email
    EmailModel(
      id: 'inbox-1',
      senderName: 'Beta Verification',
      senderEmail: 'beta@beta-softnet.com',
      recipient: 'ravinew2004@bnxmail.com',
      subject: 'BNX Mail Parent Consent Verification',
      body: 'Your verification code is: 985231',
      date: DateTime(2026, 10, 24, 9, 0),
      isRead: false,
      memberOfFolders: const {'Inbox'},
    ),
    // Another Received Inbox email
    EmailModel(
      id: 'inbox-2',
      senderName: 'GitHub',
      senderEmail: 'support@github.com',
      recipient: 'ravinew2004@bnxmail.com',
      subject: 'Your GitHub launch code',
      body: 'Here is your GitHub launch code!',
      date: DateTime(2026, 10, 23, 8, 0),
      isRead: true,
      memberOfFolders: const {'Inbox'},
    ),
  ];

  group('Mobile Inbox Startup & Route Synchronization Tests (Android & iOS)', () {
    testWidgets('Normal Inbox screen appears with TopSearchBar, TabBar and filtered Inbox emails', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            activeAccountProvider.overrideWithValue(
              const AccountModel(
                id: '1',
                name: 'Ravi Kumar',
                email: 'ravinew2004@bnxmail.com',
                avatarColor: Color(0xFF195BAC),
                isActive: true,
              ),
            ),
            emailProvider.overrideWith((ref) => TestEmailNotifier(mockEmails)),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: goRouter,
              ),
            ),
          );

          goRouter.go('/home');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // 1. TopSearchBar must be present on mobile
          expect(find.byType(TopSearchBar), findsOneWidget);
          expect(find.byTooltip('Main menu'), findsOneWidget);

          // 2. Mobile tabs must be present: Primary, Unread, Sent, Draft
          expect(find.text('Primary'), findsOneWidget);
          expect(find.text('Unread'), findsOneWidget);
          expect(find.text('Sent'), findsOneWidget);
          expect(find.text('Draft'), findsOneWidget);

          // 3. Primary tab must ONLY show inbox emails, NOT draft or sent emails
          expect(find.text('BNX Mail Parent Consent Verification'), findsOneWidget);
          expect(find.text('Your GitHub launch code'), findsOneWidget);
          expect(find.text('Meeting Request: Discussion on Project Updates'), findsNothing);
          expect(find.text('Thank you for your support'), findsNothing);
        } finally {
          container.dispose();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Even if activeFolder was Casbox, opening /home immediately renders normal Inbox and TopSearchBar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            activeAccountProvider.overrideWithValue(
              const AccountModel(
                id: '1',
                name: 'Ravi Kumar',
                email: 'ravinew2004@bnxmail.com',
                avatarColor: Color(0xFF195BAC),
                isActive: true,
              ),
            ),
            emailProvider.overrideWith((ref) => TestEmailNotifier(mockEmails)),
          ],
        );
        try {
          // Simulate state retaining 'Casbox' folder
          container.read(appUiProvider.notifier).selectFolder('Casbox');
          expect(container.read(appUiProvider).activeFolder, equals('Casbox'));

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: goRouter,
              ),
            ),
          );

          goRouter.go('/home');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // 1. TopSearchBar must be rendered
          expect(find.byType(TopSearchBar), findsOneWidget);

          // 2. TabBar must be rendered
          expect(find.text('Primary'), findsOneWidget);

          // 3. Draft and Sent emails must be excluded from the initial Primary Inbox view
          expect(find.text('Meeting Request: Discussion on Project Updates'), findsNothing);
          expect(find.text('BNX Mail Parent Consent Verification'), findsOneWidget);

          // 4. App state folder must have synchronized to Inbox
          expect(container.read(appUiProvider).activeFolder, equals('Inbox'));
        } finally {
          container.dispose();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Verified on iOS platform as well', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(1170, 2532); // iPhone 13/14/15
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            activeAccountProvider.overrideWithValue(
              const AccountModel(
                id: '1',
                name: 'Ravi Kumar',
                email: 'ravinew2004@bnxmail.com',
                avatarColor: Color(0xFF195BAC),
                isActive: true,
              ),
            ),
            emailProvider.overrideWith((ref) => TestEmailNotifier(mockEmails)),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: goRouter,
              ),
            ),
          );

          goRouter.go('/home');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(TopSearchBar), findsOneWidget);
          expect(find.text('Primary'), findsOneWidget);
          expect(find.text('BNX Mail Parent Consent Verification'), findsOneWidget);
          expect(find.text('Meeting Request: Discussion on Project Updates'), findsNothing);
        } finally {
          container.dispose();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

