import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/standalone_macos_storage/pages/macos_storage_page.dart';
import 'package:flutter_bnx_mail/features/profile/presentation/manage_account_screen.dart';
import 'package:flutter_bnx_mail/features/settings/presentation/settings_screen.dart';

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
}

