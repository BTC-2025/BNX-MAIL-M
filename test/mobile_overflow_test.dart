import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/standalone_macos_storage/pages/macos_storage_page.dart';
import 'package:flutter_bnx_mail/features/profile/presentation/manage_account_screen.dart';
import 'package:flutter_bnx_mail/features/profile/presentation/profile_screen.dart';
import 'package:flutter_bnx_mail/features/settings/presentation/settings_screen.dart';
import 'package:flutter_bnx_mail/features/dashboard/presentation/colab_screen.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/data/account_provider.dart';
import 'package:flutter_bnx_mail/models/account_model.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';

void main() {
  testWidgets('MacOsStoragePage renders on 360px mobile viewport without overflow errors', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MacOsStoragePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(errors, isEmpty, reason: 'RenderFlex overflow errors occurred on mobile storage page');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('ManageAccountScreen renders on 360px mobile viewport without overflow errors', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ManageAccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(errors, isEmpty, reason: 'RenderFlex overflow errors occurred on mobile manage account screen');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('ProfileScreen renders on 360px mobile viewport without overflow errors', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(errors, isEmpty, reason: 'RenderFlex overflow errors occurred on mobile profile screen');
      expect(find.text('Manage your BNX Account'), findsNothing); // Removed completely from blue part
      expect(find.text('Manage Account'), findsOneWidget); // Present in action list below
      expect(find.text('Add another account'), findsNWidgets(2)); // in dropdown and action list
      expect(find.text('Sign out of this account'), findsOneWidget);
      expect(find.text('Sign out of all accounts'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('ManageAccountScreen CreateSubIdDialog renders without overflow on mobile viewport', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ManageAccountScreen(initialTab: 3),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 600));
      });
      await tester.pumpAndSettle();

      // Find and tap 'Create Sub-ID' button
      final createBtnFinder = find.widgetWithText(FilledButton, 'Create Sub-ID');
      expect(createBtnFinder, findsOneWidget);
      await tester.tap(createBtnFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify dialog is opened with title and subtitle
      expect(find.text('Create New Sub-ID'), findsOneWidget);
      expect(find.text('Configure account access and assign isolated permissions.'), findsOneWidget);

      // Verify no overflow occurred in the dialog
      expect(errors, isEmpty, reason: 'RenderFlex overflow occurred in CreateSubIdDialog');

      // Close dialog
      final closeFinder = find.byIcon(Icons.close_rounded);
      if (closeFinder.evaluate().isNotEmpty) {
        await tester.tap(closeFinder);
        await tester.pumpAndSettle();
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('MacOsStoragePage all sub-views render without overflow on mobile', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MacOsStoragePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap BNX Mail card
      final bnxFinder = find.text('BNX Mail');
      if (bnxFinder.evaluate().isNotEmpty) {
        await tester.tap(bnxFinder.first);
        await tester.pumpAndSettle();
      }

      // Tap Cliks
      final cliksFinder = find.text('Cliks');
      if (cliksFinder.evaluate().isNotEmpty) {
        await tester.tap(cliksFinder.first);
        await tester.pumpAndSettle();
      }

      expect(errors, isEmpty, reason: 'Overflow in subviews of storage page');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('SettingsScreen Accounts & Mailboxes and Appearance render without overflow on 360px mobile', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Accounts & Mailboxes tab rendered with zero overflows
      expect(errors, isEmpty, reason: 'Overflow in SettingsScreen Accounts & Mailboxes tab on mobile');

      // Tap Appearance & Layout tab (index 3)
      final appearanceTabFinder = find.text('Appearance & Layout');
      if (appearanceTabFinder.evaluate().isNotEmpty) {
        await tester.tap(appearanceTabFinder.first);
        await tester.pumpAndSettle();
      }

      // Check Appearance tab (density pill buttons) rendered with zero overflows
      expect(errors, isEmpty, reason: 'Overflow in SettingsScreen Appearance & Layout tab on mobile');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('MacOsStoragePage Settings subsections render without overflow on 360px mobile', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MacOsStoragePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Settings in mobile bottom navigation / tabs
      final settingsIconFinder = find.byIcon(Icons.settings_outlined);
      if (settingsIconFinder.evaluate().isNotEmpty) {
        await tester.tap(settingsIconFinder.first);
        await tester.pumpAndSettle();
      }

      // Check General settings
      expect(errors, isEmpty, reason: 'Overflow in Storage Settings General on mobile');

      // Switch to Privacy & Control chip
      final privacyFinder = find.text('Privacy & Control');
      if (privacyFinder.evaluate().isNotEmpty) {
        await tester.tap(privacyFinder.first);
        await tester.pumpAndSettle();
      }
      expect(errors, isEmpty, reason: 'Overflow in Storage Settings Privacy & Control on mobile');

      // Switch to Manage Apps chip
      final appsFinder = find.text('Manage Apps');
      if (appsFinder.evaluate().isNotEmpty) {
        await tester.tap(appsFinder.first);
        await tester.pumpAndSettle();
      }
      expect(errors, isEmpty, reason: 'Overflow in Storage Settings Manage Apps on mobile');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('Casbox main view renders on 360px mobile viewport without overflow errors', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUiProvider.overrideWith((ref) => _TestAppUiNotifier(activeFolder: 'Casbox')),
            casboxMessagesProvider.overrideWith((ref) => _TestCasboxNotifier(_testCasboxMessages)),
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
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Casbox'), findsOneWidget);
      // Top-right Compose button is removed on mobile (FAB is used)
      expect(find.widgetWithText(ElevatedButton, 'Compose'), findsNothing);
      expect(errors, isEmpty, reason: 'RenderFlex overflow errors occurred on mobile Casbox main view');

      // Tap select-all checkbox to test toolbar with all action buttons visible on 360px screen
      final checkboxFinder = find.byType(Checkbox);
      if (checkboxFinder.evaluate().isNotEmpty) {
        await tester.tap(checkboxFinder.first);
        await tester.pump();
      }
      expect(errors, isEmpty, reason: 'RenderFlex overflow errors occurred on mobile Casbox selection toolbar');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('Casbox tabs and connections popup render on 360px mobile without overflow errors', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUiProvider.overrideWith((ref) => _TestAppUiNotifier(activeFolder: 'Casbox')),
            casboxMessagesProvider.overrideWith((ref) => _TestCasboxNotifier(_testCasboxMessages)),
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
      await tester.pump(const Duration(milliseconds: 400));

      // Tap 'Requests' tab
      final requestsTabFinder = find.text('Requests');
      if (requestsTabFinder.evaluate().isNotEmpty) {
        await tester.tap(requestsTabFinder.first, warnIfMissed: false);
        await tester.pump();
      }
      expect(errors, isEmpty, reason: 'Overflow in Casbox Requests tab on mobile');

      // Tap 'Combined Chat' tab
      final combinedChatFinder = find.text('Combined Chat');
      if (combinedChatFinder.evaluate().isNotEmpty) {
        await tester.tap(combinedChatFinder.first, warnIfMissed: false);
        await tester.pump();
      }
      expect(errors, isEmpty, reason: 'Overflow in Casbox Combined Chat tab on mobile');

      // Tap Connections popup circle icon (person_add_alt_1_rounded)
      final connectionsBtnFinder = find.byIcon(Icons.person_add_alt_1_rounded);
      if (connectionsBtnFinder.evaluate().isNotEmpty) {
        await tester.tap(connectionsBtnFinder.first, warnIfMissed: false);
        await tester.pump();
      }
      expect(errors, isEmpty, reason: 'Overflow in Casbox Connections popup on mobile');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('Casbox conversation view and pending request banner render on 360px and 390px without overflow', (tester) async {
    final List<FlutterErrorDetails> errors = [];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
    };

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUiProvider.overrideWith((ref) => _TestAppUiNotifier(activeFolder: 'Casbox')),
            casboxMessagesProvider.overrideWith((ref) => _TestCasboxNotifier(_testCasboxMessages)),
            selectedCasboxThreadProvider.overrideWith((ref) => 'msg_1'),
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
      await tester.pump(const Duration(milliseconds: 400));

      // Verify conversation elements exist
      expect(find.text('Type a message...'), findsOneWidget);
      expect(errors, isEmpty, reason: 'Overflow in Casbox active conversation view on 360px viewport');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // Test on 390px iOS viewport with a pending request conversation (which shows request banner)
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUiProvider.overrideWith((ref) => _TestAppUiNotifier(activeFolder: 'Casbox')),
            casboxMessagesProvider.overrideWith((ref) => _TestCasboxNotifier(_testCasboxMessages)),
            selectedCasboxThreadProvider.overrideWith((ref) => 'req_1'),
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
      await tester.pump(const Duration(milliseconds: 400));

      // Verify request banner buttons
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(errors, isEmpty, reason: 'Overflow in Casbox pending request conversation view on 390px viewport');

      // Tap back button
      final backBtn = find.byIcon(Icons.arrow_back_rounded);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await tester.pump();
      }
      expect(errors, isEmpty, reason: 'Overflow after back navigation from Casbox conversation');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = oldOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}

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

final _testCasboxMessages = [
  CasboxMessage(
    id: 'msg_1',
    sender: 'alexandra.verylongname@bnxmail.com',
    to: 'ravi@bnxmail.com',
    subject: 'Project Updates and Roadmaps',
    body: 'Hi Ravi, here are the extensive project updates and roadmaps for next quarter. Testing layout with extended sentences to verify zero horizontal RenderFlex overflows on mobile screens.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    status: 'DELIVERED',
  ),
  CasboxMessage(
    id: 'msg_2',
    sender: 'ravi@bnxmail.com',
    to: 'alexandra.verylongname@bnxmail.com',
    subject: 'Project Updates and Roadmaps',
    body: 'Thanks Alexandra! Looking forward to reviewing the roadmap document.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    status: 'SEEN',
  ),
  CasboxMessage(
    id: 'req_1',
    sender: 'stranger.person@otherdomain.com',
    to: 'ravi@bnxmail.com',
    subject: 'Connection Request',
    body: 'Hello! I would like to establish a Casbox messaging channel with you.',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    status: 'PENDING',
  ),
];


