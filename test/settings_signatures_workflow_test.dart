import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/data/settings_provider.dart';
import 'package:flutter_bnx_mail/models/signature_model.dart';
import 'package:flutter_bnx_mail/core/widgets/compose_dialog.dart';
import 'package:flutter_bnx_mail/features/settings/presentation/settings_screen.dart';

void main() {
  group('Settings Email Signatures Workflow & Mobile UI Tests', () {
    testWidgets(
        'Clicking + Add Signature creates exactly one signature chip without duplicates',
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

      // Switch to General & Composing tab
      await tester.tap(find.text('General & Composing'));
      await tester.pumpAndSettle();

      // Scroll to EMAIL SIGNATURES section
      await tester.scrollUntilVisible(
        find.text('EMAIL SIGNATURES'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('EMAIL SIGNATURES'), findsOneWidget);
      expect(find.text('+ Add Signature'), findsOneWidget);

      // Tap "+ Add Signature"
      await tester.tap(find.text('+ Add Signature'));
      await tester.pumpAndSettle();

      // Exactly ONE "Signature 1" chip should exist, not two duplicate chips
      expect(find.widgetWithText(InkWell, 'Signature 1'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      // Verify "Save" button and editor are visible
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
      expect(find.text('Design your signature...'), findsOneWidget);
    });

    testWidgets(
        'Adding a second signature creates Signature 2 and preserves both signatures',
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

      // Switch to General & Composing tab
      await tester.tap(find.text('General & Composing'));
      await tester.pumpAndSettle();

      // Scroll to EMAIL SIGNATURES section
      await tester.scrollUntilVisible(
        find.text('EMAIL SIGNATURES'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Add first signature
      await tester.tap(find.text('+ Add Signature'));
      await tester.pumpAndSettle();

      // Find content textfield
      final contentField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Design your signature...',
      );
      expect(contentField, findsOneWidget);

      // Enter text for Signature 1
      await tester.enterText(contentField, 'Regards, User 1');
      await tester.pumpAndSettle();

      // Add second signature
      await tester.tap(find.text('+ Add Signature'));
      await tester.pumpAndSettle();

      // Both chips must exist simultaneously
      expect(find.widgetWithText(InkWell, 'Signature 1'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Signature 2'), findsOneWidget);

      // Switch back to Signature 1
      await tester.tap(find.widgetWithText(InkWell, 'Signature 1'));
      await tester.pumpAndSettle();

      // Verify Signature 1 content was preserved
      expect(find.text('Regards, User 1'), findsOneWidget);

      // Both chips remain visible
      expect(find.widgetWithText(InkWell, 'Signature 1'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Signature 2'), findsOneWidget);
    });

    testWidgets(
        'Signature Editor renders on 360px mobile viewport without overflow',
        (tester) async {
      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
        originalOnError?.call(details);
      };

      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        FlutterError.onError = originalOnError;
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

      // Scroll the top horizontal tab bar to make General & Composing visible if needed
      final generalTabFinder = find.text('General & Composing');
      if (tester.getCenter(generalTabFinder).dx > 360) {
        await tester.drag(find.byType(ListView).first, const Offset(-200, 0));
        await tester.pumpAndSettle();
      }

      await tester.tap(generalTabFinder);
      await tester.pumpAndSettle();

      // Scroll vertically to EMAIL SIGNATURES section
      await tester.scrollUntilVisible(
        find.text('EMAIL SIGNATURES'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Tap "+ Add Signature"
      await tester.tap(find.text('+ Add Signature'));
      await tester.pumpAndSettle();

      // No overflow exceptions should occur
      expect(errorDetails, isNull);

      // All elements in mobile responsive layout are visible
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
      expect(find.text('Design your signature...'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });

    testWidgets(
        'ComposeDialog loads and displays default signature from Settings',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => SettingsNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      // Pre-seed a default signature in settings
      final notifier = container.read(settingsProvider.notifier);
      notifier.state = notifier.state.copyWith(
        signatures: const [
          SignatureModel(
            id: 'sig_101',
            name: 'Work Signature',
            content: '<p>Best regards,<br>Alice</p>',
            isDefault: true,
          ),
        ],
      );

      // Set composeStatus to normal so ComposeDialog is active and visible
      container.read(appUiProvider.notifier).setComposeStatus(ComposeStatus.normal);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ComposeDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Signature should be fetched from settings and displayed in ComposeDialog
      expect(find.text('Best regards,\nAlice'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);

      // If user removes signature via close icon [x]
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Best regards,\nAlice'), findsNothing);

      // Tapping "Signature" from More menu fetches and re-shows default signature from Settings
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Signature'));
      await tester.pumpAndSettle();

      // Default signature from Settings is restored and displayed
      expect(find.text('Best regards,\nAlice'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });
  });
}
