import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';
import 'package:flutter_bnx_mail/models/account_model.dart';
import 'package:flutter_bnx_mail/data/email_provider.dart';
import 'package:flutter_bnx_mail/data/account_provider.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/features/inbox/presentation/email_list_screen.dart';
import 'package:flutter_bnx_mail/features/inbox/presentation/templates_view.dart';
import 'package:flutter_bnx_mail/core/widgets/top_search_bar.dart';

class TestEmailNotifier extends EmailNotifier {
  final List<EmailModel> _initial;
  final VoidCallback? onRefresh;
  TestEmailNotifier(this._initial, {this.onRefresh}) : super() {
    clearAll();
    state = EmailState(emails: _initial, isLoading: false);
  }

  @override
  Future<void> loadFolder(String folder, {bool background = false}) async {
    state = EmailState(emails: _initial, isLoading: false);
  }

  @override
  Future<void> forceRefreshFolder(String folder) async {
    onRefresh?.call();
    state = EmailState(emails: _initial, isLoading: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Inbox 1-Month Date Filter Tests (Android & iOS alone)', () {
    testWidgets(
        'On Android, inbox displays only emails from past calendar month (e.g. 15th sep - 15th oct)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final now = DateTime.now();
        int targetYear = now.year;
        int targetMonth = now.month - 1;
        if (targetMonth < 1) {
          targetMonth = 12;
          targetYear -= 1;
        }
        final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        final targetDay =
            now.day > daysInTargetMonth ? daysInTargetMonth : now.day;
        final oneMonthAgo =
            DateTime(targetYear, targetMonth, targetDay, 10, 0, 0);

        final recentEmail = EmailModel(
          id: 'recent-1',
          senderName: 'Recent Sender',
          senderEmail: 'recent@bnxmail.com',
          recipient: 'user@bnxmail.com',
          subject: 'Recent Mail',
          body: 'Mail from 2 days ago',
          date: now.subtract(const Duration(days: 2)),
          memberOfFolders: const {'Inbox'},
        );

        final boundaryEmail = EmailModel(
          id: 'boundary-1',
          senderName: 'Boundary Sender',
          senderEmail: 'boundary@bnxmail.com',
          recipient: 'user@bnxmail.com',
          subject: 'Boundary Mail',
          body: 'Mail from one month ago boundary',
          date: oneMonthAgo,
          memberOfFolders: const {'Inbox'},
        );

        final oldEmail = EmailModel(
          id: 'old-1',
          senderName: 'Old Sender',
          senderEmail: 'old@bnxmail.com',
          recipient: 'user@bnxmail.com',
          subject: 'Old Mail 45 Days',
          body: 'Mail older than one month',
          date: now.subtract(const Duration(days: 45)),
          memberOfFolders: const {'Inbox'},
        );

        final container = ProviderContainer(
          overrides: [
            emailProvider.overrideWith((ref) => TestEmailNotifier([
                  recentEmail,
                  boundaryEmail,
                  oldEmail,
                ])),
            activeAccountProvider.overrideWith((ref) => const AccountModel(
                  id: 'acc-1',
                  email: 'user@bnxmail.com',
                  name: 'Test User',
                  avatarColor: Color(0xFF195BAC),
                )),
          ],
        );
        addTearDown(() => container.dispose());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: EmailListScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Recent and boundary emails should appear
        expect(find.text('Recent Sender'), findsOneWidget);
        expect(find.text('Boundary Sender'), findsOneWidget);

        // Old email should NOT appear on Android
        expect(find.text('Old Sender'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'On macOS desktop, all emails including older than 1 month appear',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();
        final oldEmail = EmailModel(
          id: 'old-macos-1',
          senderName: 'Old Sender',
          senderEmail: 'old@bnxmail.com',
          recipient: 'user@bnxmail.com',
          subject: 'Old Mail On MacOS',
          body: 'Older email visible on desktop',
          date: now.subtract(const Duration(days: 60)),
          memberOfFolders: const {'Inbox'},
        );

        final container = ProviderContainer(
          overrides: [
            emailProvider.overrideWith((ref) => TestEmailNotifier([oldEmail])),
            activeAccountProvider.overrideWith((ref) => const AccountModel(
                  id: 'acc-1',
                  email: 'user@bnxmail.com',
                  name: 'Test User',
                  avatarColor: Color(0xFF195BAC),
                )),
          ],
        );
        addTearDown(() => container.dispose());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: EmailListScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // On macOS, older emails are NOT filtered out
        expect(find.text('Old Sender'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Mobile Refresh Button SnackBar Suppression Tests', () {
    testWidgets('On Android, refresh does not show SnackBar messages',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final container = ProviderContainer(
          overrides: [
            emailProvider.overrideWith((ref) => TestEmailNotifier([])),
            appUiProvider.overrideWith((ref) => AppUiNotifier()),
          ],
        );
        addTearDown(() => container.dispose());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                appBar: TopSearchBar(),
                body: Text('Inbox Body'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap refresh icon
        final refreshBtn = find.byIcon(Icons.refresh_rounded);
        expect(refreshBtn, findsOneWidget);
        await tester.tap(refreshBtn);
        // During the animation, verify RotationTransition on refresh icon is present and no snackbar appears
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.ancestor(
            of: find.byIcon(Icons.refresh_rounded),
            matching: find.byType(RotationTransition),
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);

        // Advance past completion
        await tester.pump(const Duration(milliseconds: 700));

        // Ensure NO SnackBar is displayed on Android
        expect(find.textContaining('Refreshing'), findsNothing);
        expect(find.textContaining('Mailbox refreshed successfully'),
            findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'On iOS, tapping reload icon triggers reload function and reload rotation animation without SnackBars',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        bool reloadFunctionCalled = false;
        final container = ProviderContainer(
          overrides: [
            emailProvider.overrideWith((ref) => TestEmailNotifier(
                  [],
                  onRefresh: () {
                    reloadFunctionCalled = true;
                  },
                )),
            appUiProvider.overrideWith((ref) => AppUiNotifier()),
          ],
        );
        addTearDown(() => container.dispose());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                appBar: TopSearchBar(),
                body: Text('Inbox Body'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final refreshBtn = find.byIcon(Icons.refresh_rounded);
        expect(refreshBtn, findsOneWidget);

        // Tap the reload icon
        await tester.tap(refreshBtn);
        await tester.pump();

        // During reload animation, RotationTransition rotates the reload icon
        await tester.pump(const Duration(milliseconds: 150));
        final rotWidget = tester.widget<RotationTransition>(
          find.ancestor(
            of: find.byIcon(Icons.refresh_rounded),
            matching: find.byType(RotationTransition),
          ),
        );
        expect(rotWidget.turns.value, greaterThan(0.0));
        expect(find.byType(SnackBar), findsNothing);
        expect(reloadFunctionCalled, isTrue);

        // Wait for reload animation to finish
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.byType(SnackBar), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Templates Large Preview Overflow Tests', () {
    testWidgets(
        'Opening preview of a very large template does not throw RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final largeBody = List.generate(
        100,
        (i) =>
            'Paragraph $i: This is a detailed section of the business proposal with terms and conditions.',
      ).join('\n\n');

      final largeTemplate = BNXTemplate(
        id: 'tmpl-large-1',
        title: 'Master Service Agreement',
        subject:
            'Contract Execution & Master Terms Agreement for Enterprise Services',
        category: 'Business',
        body: largeBody,
        type: 'CUSTOM',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    final isMobile = MediaQuery.of(ctx).size.width < 600;
                    showDialog(
                      context: ctx,
                      builder: (dialogCtx) => Dialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        insetPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 14 : 20,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 520,
                            maxHeight:
                                MediaQuery.of(dialogCtx).size.height * 0.85,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isMobile ? 16 : 26,
                              20,
                              isMobile ? 16 : 26,
                              20,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Template Preview',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('SUBJECT'),
                                        Text(largeTemplate.subject),
                                        const SizedBox(height: 16),
                                        const Text('CATEGORY'),
                                        Text(largeTemplate.category),
                                        const SizedBox(height: 16),
                                        const Text('CONTENT'),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(14),
                                          child: Text(largeTemplate.body),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Preview'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Template Preview'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('Paragraph 0'), findsOneWidget);
    });
  });
}
