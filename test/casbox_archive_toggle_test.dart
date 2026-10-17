import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/data/account_provider.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/models/account_model.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';
import 'package:flutter_bnx_mail/features/dashboard/presentation/colab_screen.dart';

class _TestAppUiNotifier extends AppUiNotifier {
  _TestAppUiNotifier({String activeFolder = 'Casbox'}) : super() {
    state = state.copyWith(activeFolder: activeFolder);
  }
}

class _TestCasboxNotifier extends CasboxMessagesNotifier {
  _TestCasboxNotifier(List<CasboxMessage> initial) : super() {
    state = initial;
  }
  @override
  Future<void> fetchMessages([List<EmailModel>? mailboxEmails]) async {}
  @override
  Future<void> fetchThreadMessages(dynamic otherEmailOrId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMessages = [
    CasboxMessage(
      id: 'msg_1',
      sender: 'alice@bnxmail.com',
      to: 'ravi@bnxmail.com',
      subject: 'Discussion',
      body: 'Ok see whether it came or not?',
      timestamp: DateTime.now(),
      status: 'DELIVERED',
      isArchived: false,
    ),
  ];

  Widget buildCasboxApp({double width = 1024, double height = 768}) {
    return ProviderScope(
      overrides: [
        appUiProvider.overrideWith((ref) => _TestAppUiNotifier(activeFolder: 'Casbox')),
        casboxMessagesProvider.overrideWith((ref) => _TestCasboxNotifier(testMessages)),
        activeAccountProvider.overrideWithValue(
          const AccountModel(
            id: 'user_1',
            name: 'Ravi',
            email: 'ravi@bnxmail.com',
            avatarColor: Color(0xFF195BAC),
            isActive: true,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          drawer: const Drawer(),
          body: SizedBox(
            width: width,
            height: height,
            child: const ColabScreen(),
          ),
        ),
      ),
    );
  }

  group('Archive Collapsible Tab & Arrow Toggle Tests', () {
    testWidgets('Archive is in hide position initially; clicking arrow reveals it; clicking again hides it', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildCasboxApp(width: 1024, height: 768));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially Archive is hidden; only Messages, Combine, Requests are shown
      expect(find.text('Messages'), findsWidgets);
      expect(find.text('Combine'), findsWidgets);
      expect(find.text('Requests'), findsWidgets);
      expect(find.text('Archive'), findsNothing);

      // Verify the Show Archive arrow tooltip is present
      final showArchiveArrow = find.byTooltip('Show Archive');
      expect(showArchiveArrow, findsOneWidget);

      // Click the arrow to expand Archive
      await tester.tap(showArchiveArrow);
      await tester.pumpAndSettle();

      // Now Archive tab is revealed
      expect(find.text('Archive'), findsOneWidget);
      final hideArchiveArrow = find.byTooltip('Hide Archive');
      expect(hideArchiveArrow, findsOneWidget);

      // Click the arrow again to hide Archive
      await tester.tap(hideArchiveArrow);
      await tester.pumpAndSettle();

      // Archive is hidden again
      expect(find.text('Archive'), findsNothing);
      expect(find.byTooltip('Show Archive'), findsOneWidget);
    });

    testWidgets('Archive toggle works on mobile 360px viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildCasboxApp(width: 360, height: 640));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially on mobile, Archive is in hide position
      expect(find.text('Archive'), findsNothing);
      final showArchiveArrow = find.byTooltip('Show Archive');
      expect(showArchiveArrow, findsOneWidget);

      // Tap to expand on mobile
      await tester.ensureVisible(showArchiveArrow);
      await tester.pumpAndSettle();
      await tester.tap(showArchiveArrow);
      await tester.pumpAndSettle();

      // Archive tab appears on mobile
      expect(find.text('Archive'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap to hide on mobile
      final hideArchiveArrow = find.byTooltip('Hide Archive');
      expect(hideArchiveArrow, findsOneWidget);
      await tester.ensureVisible(hideArchiveArrow);
      await tester.pumpAndSettle();
      await tester.tap(hideArchiveArrow);
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('On macOS desktop, connection buttons are positioned on the right side', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildCasboxApp(width: 1280, height: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final connectionsButton = find.text('+ Connections');
      expect(connectionsButton, findsOneWidget);

      final connectionsTopLeft = tester.getTopLeft(connectionsButton);
      // Screen width is 1280. On the right side, x should be > 900
      expect(connectionsTopLeft.dx, greaterThan(900));

      final blockedButton = find.byTooltip('Blocked Users');
      expect(blockedButton, findsOneWidget);
      final blockedTopLeft = tester.getTopLeft(blockedButton);
      expect(blockedTopLeft.dx, greaterThan(connectionsTopLeft.dx));

      final refreshButton = find.byTooltip('Refresh');
      expect(refreshButton, findsOneWidget);
      final refreshTopLeft = tester.getTopLeft(refreshButton);
      expect(refreshTopLeft.dx, greaterThan(blockedTopLeft.dx));
    });

    testWidgets('Activity section displays recent messages at top and older messages at bottom', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialMsg = CasboxMessage(
        id: 'msg_main',
        sender: 'chandran123@bnxmail.com',
        to: 'ravi@bnxmail.com',
        subject: '12345670',
        body: 'Main initial message text',
        timestamp: DateTime(2026, 8, 1, 10, 0),
        status: 'DELIVERED',
        isArchived: false,
      );

      final oldMsg = CasboxMessage(
        id: 'msg_old',
        sender: 'ravi@bnxmail.com',
        to: 'chandran123@bnxmail.com',
        subject: '12345670',
        body: 'lets test correctly (oldest)',
        timestamp: DateTime(2026, 8, 17, 12, 17),
        status: 'DELIVERED',
        isArchived: false,
      );

      final midMsg = CasboxMessage(
        id: 'msg_mid',
        sender: 'ravi@bnxmail.com',
        to: 'chandran123@bnxmail.com',
        subject: '12345670',
        body: 'ok see coming or not (middle)',
        timestamp: DateTime(2026, 9, 8, 9, 57),
        status: 'DELIVERED',
        isArchived: false,
      );

      final recentMsg = CasboxMessage(
        id: 'msg_recent',
        sender: 'ravi@bnxmail.com',
        to: 'chandran123@bnxmail.com',
        subject: '12345670',
        body: 'hello bro wht doing (most recent)',
        timestamp: DateTime(2026, 9, 30, 10, 30),
        status: 'DELIVERED',
        isArchived: false,
      );

      final threadList = [initialMsg, oldMsg, midMsg, recentMsg];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUiProvider.overrideWith((ref) => _TestAppUiNotifier(activeFolder: 'Casbox')),
            casboxMessagesProvider.overrideWith((ref) => _TestCasboxNotifier(threadList)),
            selectedCasboxThreadProvider.overrideWith((ref) => 'msg_main'),
            activeAccountProvider.overrideWithValue(
              const AccountModel(
                id: 'user_1',
                name: 'Ravi',
                email: 'ravi@bnxmail.com',
                avatarColor: Color(0xFF195BAC),
                isActive: true,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              drawer: Drawer(),
              body: ColabScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on the conversation to select it
      final rowFinder = find.text('12345670');
      if (rowFinder.evaluate().isNotEmpty) {
        await tester.tap(rowFinder.first);
        await tester.pumpAndSettle();
      }

      // Check Activity section header
      expect(find.text('Activity (4)'), findsOneWidget);

      // Verify that all 3 follow-up messages are present
      final recentFinder = find.text('hello bro wht doing (most recent)');
      final midFinder = find.text('ok see coming or not (middle)');
      final oldFinder = find.text('lets test correctly (oldest)');

      expect(recentFinder, findsOneWidget);
      expect(midFinder, findsOneWidget);
      expect(oldFinder, findsOneWidget);

      // Verify vertical positions: recent at top, older at bottom
      final recentY = tester.getTopLeft(recentFinder).dy;
      final midY = tester.getTopLeft(midFinder).dy;
      final oldY = tester.getTopLeft(oldFinder).dy;

      expect(recentY, lessThan(midY), reason: 'Most recent message must be positioned higher than middle message');
      expect(midY, lessThan(oldY), reason: 'Middle message must be positioned higher than oldest message');
    });
  });
}
