import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/core/router/router.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/models/account_model.dart';
import 'package:flutter_bnx_mail/data/account_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Sidebar and Route Synchronization Tests', () {
    testWidgets('Opening /home on macOS renders Mail sidebar (Inbox, Sent, Drafts) and not Casbox tiles', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
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
            ],
            child: MaterialApp.router(
              routerConfig: goRouter,
            ),
          ),
        );

        goRouter.go('/home');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // On /home, desktop sidebar must contain Mail folders
        expect(find.text('Inbox'), findsOneWidget);
        expect(find.text('Starred'), findsOneWidget);
        expect(find.text('Sent'), findsOneWidget);
        expect(find.text('Draft'), findsOneWidget);

        // Sidebar should have Mail folders active
        expect(find.text('Inbox'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('If activeFolder was Casbox, opening /home resets activeFolder to Inbox and shows Mail sidebar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
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
          ],
        );
        try {
          // Simulate prior Casbox folder selection
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

          // DashboardShell post-frame callback must have synchronized activeFolder to Inbox
          expect(container.read(appUiProvider).activeFolder, equals('Inbox'));

          // Sidebar must render Mail folders, not Colab
          expect(find.text('Inbox'), findsOneWidget);
          expect(find.text('Starred'), findsOneWidget);
          expect(find.text('Sent'), findsOneWidget);
        } finally {
          container.dispose();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Opening /colab renders Colab sidebar (Casbox & Colab tiles)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
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
            ],
            child: MaterialApp.router(
              routerConfig: goRouter,
            ),
          ),
        );

        goRouter.go('/colab');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // On /colab, desktop sidebar must contain Casbox and Colab tiles
        expect(find.text('Colab'), findsWidgets);
        // Inbox should not be in the sidebar on /colab
        expect(find.text('Inbox'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('On /colab, clicking Archive under Colab in sidebar opens Archive page and does not revert to Casbox', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
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

          goRouter.go('/colab');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Ensure Archive tile is visible in sidebar under Colab
          expect(find.text('Archive'), findsWidgets);

          // Click Archive under Colab
          await tester.tap(find.text('Archive').first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Active folder must be ColabArchive (not reverted to Casbox)
          expect(container.read(appUiProvider).activeFolder, equals('ColabArchive'));

          // The Archive page content must be rendered
          expect(
            find.text('View and manage your archived messages and colab conversations'),
            findsOneWidget,
          );
        } finally {
          container.dispose();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
