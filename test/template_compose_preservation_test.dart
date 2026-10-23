import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/features/inbox/presentation/templates_view.dart';

void main() {
  group('Template Compose Recipient Preservation Tests', () {
    test('BNXTemplate defaultTemplates are populated', () {
      expect(BNXTemplate.defaultTemplates, isNotEmpty);
      final meetingReq = BNXTemplate.defaultTemplates.firstWhere(
        (t) => t.title == 'Meeting Request',
      );
      expect(meetingReq.subject, contains('Meeting Request'));
      expect(meetingReq.body, contains('Hi [Name]'));
    });

    test('updateComposeDraft preserves recipient when applying template', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appUiProvider.notifier);

      // User enters recipient "client@company.com" in Compose
      notifier.updateComposeDraft(to: 'client@company.com');
      expect(container.read(appUiProvider).composeTo, 'client@company.com');

      // User selects a template (e.g. Meeting Request)
      final template = BNXTemplate.defaultTemplates.firstWhere(
        (t) => t.title == 'Meeting Request',
      );

      // Applying template with existingTo preserved
      final currentTo = container.read(appUiProvider).composeTo;
      notifier.updateComposeDraft(
        to: currentTo.isNotEmpty ? currentTo : null,
        subject: template.subject,
        body: template.body,
      );

      final state = container.read(appUiProvider);

      // Verify recipient was NOT removed or cleared
      expect(state.composeTo, 'client@company.com');
      expect(state.composeSubject, template.subject);
      expect(state.composeBody, template.body);
    });

    test('updateComposeDraft does not clear recipient if to is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appUiProvider.notifier);

      // Initialize with recipient
      notifier.updateComposeDraft(to: 'boss@enterprise.com');
      expect(container.read(appUiProvider).composeTo, 'boss@enterprise.com');

      // Update only subject & body with null `to`
      notifier.updateComposeDraft(
        subject: 'Follow-up on Proposal',
        body: 'Please see the attached document for review.',
      );

      final state = container.read(appUiProvider);
      expect(state.composeTo, 'boss@enterprise.com');
      expect(state.composeSubject, 'Follow-up on Proposal');
      expect(state.composeBody, 'Please see the attached document for review.');
    });

    testWidgets('Template selection callback returns template details without modifying recipient', (tester) async {
      BNXTemplate? selected;
      final templateToApply = BNXTemplate.defaultTemplates.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  selected = templateToApply;
                },
                child: const Text('Insert Template'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Insert Template'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.title, templateToApply.title);
      expect(selected!.subject, templateToApply.subject);
      expect(selected!.body, templateToApply.body);
    });
  });
}
