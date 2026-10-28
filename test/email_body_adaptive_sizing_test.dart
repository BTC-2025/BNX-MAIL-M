import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:flutter_bnx_mail/core/widgets/email_body.dart';
import 'package:flutter_bnx_mail/core/widgets/email_html_view.dart';
import 'package:flutter_bnx_mail/data/email_provider.dart';
import 'package:flutter_bnx_mail/models/attachment_model.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';

void main() {
  group('EmailHtmlView Adaptive Sizing Tests', () {
    testWidgets('Short email body adapts intrinsically to content height and is not inflated',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                EmailHtmlView(
                  html: '<p>docu</p>',
                  text: 'docu',
                  isDark: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emailHtmlViewFinder = find.byType(EmailHtmlView);
      expect(emailHtmlViewFinder, findsOneWidget);

      final size = tester.getSize(emailHtmlViewFinder);
      // "docu" is a single line (~20-40px). It must NOT be inflated to 450px or greater!
      expect(size.height, lessThan(100.0),
          reason: 'Short email body height should adapt to content (~20-40px), not 450px+');
      expect(size.height, greaterThan(10.0));
      expect(find.byType(HtmlWidget), findsOneWidget);
    });

    testWidgets('Plain text email is converted to HTML and sizes adaptively without bordered card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                EmailHtmlView(
                  html: '',
                  text: 'Simple plain text body',
                  isDark: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emailHtmlViewFinder = find.byType(EmailHtmlView);
      expect(emailHtmlViewFinder, findsOneWidget);

      final size = tester.getSize(emailHtmlViewFinder);
      expect(size.height, lessThan(100.0));
    });

    testWidgets('Long email body is constrained to maxHeight and provides scrollable viewport',
        (WidgetTester tester) async {
      final longContent = List.generate(50, (i) => '<p>Paragraph $i: Detailed message content line.</p>').join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                EmailHtmlView(
                  html: longContent,
                  text: '',
                  isDark: false,
                  maxHeight: 350,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emailHtmlViewFinder = find.byType(EmailHtmlView);
      expect(emailHtmlViewFinder, findsOneWidget);

      final size = tester.getSize(emailHtmlViewFinder);
      // Must be capped at maxHeight (350), not stretching endlessly!
      expect(size.height, equals(350.0));

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      // Verify internal scrolling works smoothly
      await tester.drag(scrollFinder, const Offset(0, -300));
      await tester.pumpAndSettle();
    });

    testWidgets('Dark mode applies light text color seamlessly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: EmailHtmlView(
              html: '<p>Dark mode message</p>',
              text: 'Dark mode message',
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final htmlWidget = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
      expect(htmlWidget.textStyle?.color, const Color(0xFFE2E8F0));
    });

    testWidgets('Empty content displays fallback italic text with minimal height',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailHtmlView(
              html: '',
              text: '',
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('(No Content)'), findsOneWidget);
      final size = tester.getSize(find.byType(EmailHtmlView));
      expect(size.height, lessThan(60.0));
    });

    testWidgets('Text email bodies align to the left side on desktop matching subject and webmail',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailHtmlView(
              html: '<p>skdn n jnjhbwfhjb</p>',
              text: 'skdn n jnjhbwfhjb',
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boxFinder = find.descendant(
        of: find.byType(EmailHtmlView),
        matching: find.byType(ConstrainedBox),
      ).first;
      final topLeft = tester.getTopLeft(boxFinder);

      // On desktop, text emails must align to the left side (x = 0), matching the subject line
      expect(topLeft.dx, closeTo(0.0, 1.0),
          reason: 'Text emails should be aligned to the left side rather than pushed to center');
    });

    testWidgets('Rich template long format emails are horizontally centered on desktop',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const richTemplate = '''
        <div style="margin: 0 auto; max-width: 600px;">
          <table>
            <tr><td><img src="https://example.com/persona.png" /></td></tr>
            <tr><td><h2>Persona access is ending soon</h2></td></tr>
          </table>
        </div>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailHtmlView(
              html: richTemplate,
              text: 'Persona access is ending soon',
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boxFinder = find.descendant(
        of: find.byType(EmailHtmlView),
        matching: find.byType(ConstrainedBox),
      ).first;
      final topLeft = tester.getTopLeft(boxFinder);
      final size = tester.getSize(boxFinder);

      // On 1280px screen, 740px container should be horizontally centered:
      // (1280 - 740) / 2 = 270.0 px
      expect(size.width, equals(740.0));
      expect(topLeft.dx, closeTo(270.0, 5.0),
          reason: 'Rich template long formats must be centered horizontally on desktop');

      // The content inside should be left-aligned within the centered container
      final htmlFinder = find.byType(HtmlWidget);
      final htmlTopLeft = tester.getTopLeft(htmlFinder);
      expect(htmlTopLeft.dx, closeTo(270.0, 5.0),
          reason: 'Html content should be left-aligned within the centered 740px reading container');
    });

    testWidgets('On mobile OS, EmailHtmlView dynamically sizes to content without internal SingleChildScrollView',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailHtmlView(
              html: '<p>Re: okay mobile content line 1</p><p>Line 2</p>',
              text: 'Re: okay mobile content line 1\nLine 2',
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On mobile OS, there should NOT be an internal nested SingleChildScrollView in EmailHtmlView
      expect(
        find.descendant(
          of: find.byType(EmailHtmlView),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
        reason: 'EmailHtmlView must not trap scroll in a nested view on mobile OS',
      );

      // HtmlWidget should be rendered directly and naturally
      expect(find.byType(HtmlWidget), findsOneWidget);
    });
  });

  group('EmailBody Adaptive Layout Integration Tests', () {
    testWidgets('EmailBody renders short email with attachments and actions compactly matching webmail',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testEmail = EmailModel(
        id: 'test_okay_123',
        subject: 'okay',
        body: 'docu',
        htmlBody: '<p>docu</p>',
        senderName: 'chandran123',
        senderEmail: 'chandran123@bnxmail.com',
        recipient: 'ravinew2004@bnxmail.com',
        date: DateTime(2026, 10, 28, 14, 7),
        attachments: [
          AttachmentModel(fileName: 'Pasted 28-10-2026.png', fileSize: '124 KB', fileType: 'IMG'),
          AttachmentModel(fileName: '# BNX Mail - Casbox.pdf', fileSize: '340 KB', fileType: 'PDF'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emailListProvider.overrideWithValue([testEmail]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EmailBody(emailId: 'test_okay_123'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header, body, attachments and buttons exist
      expect(find.text('okay'), findsOneWidget);
      expect(find.text('chandran123'), findsOneWidget);
      expect(find.text('ATTACHMENTS (2)'), findsOneWidget);
      expect(find.text('Pasted 28-10-2026.png'), findsOneWidget);
      expect(find.text('# BNX Mail - Casbox.pdf'), findsOneWidget);
      expect(find.text('Image File'), findsOneWidget);
      expect(find.text('PDF File'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget); // Pill badge
      expect(find.byIcon(Icons.visibility_outlined), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.download_rounded), findsAtLeastNWidgets(2));
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Forward'), findsOneWidget);

      // Verify the vertical layout is compact and all elements fit on screen without being pushed far away
      final subjectTop = tester.getTopLeft(find.text('okay')).dy;
      final replyTop = tester.getTopLeft(find.text('Reply')).dy;

      // Distance from subject to reply button should be compact (< 600px) because email body is only "docu"
      // and attachment cards are 152px two-tier preview cards matching webmail
      final distance = replyTop - subjectTop;
      expect(distance, lessThan(600.0),
          reason: 'Reply button must sit directly below attachments when email body is short (~$distance px)');
    });

    testWidgets('Tapping download button triggers attachment download snackbar',
        (WidgetTester tester) async {
      final testEmail = EmailModel(
        id: 'test_download_123',
        subject: 'Download Test',
        body: 'Click download test',
        htmlBody: '<p>Click download test</p>',
        senderName: 'chandran123',
        senderEmail: 'chandran123@bnxmail.com',
        recipient: 'ravinew2004@bnxmail.com',
        date: DateTime.now(),
        attachments: [
          AttachmentModel(fileName: 'Report.pdf', fileSize: '50 KB', fileType: 'PDF'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emailListProvider.overrideWithValue([testEmail]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EmailBody(emailId: 'test_download_123'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final downloadBtn = find.byIcon(Icons.download_rounded).first;
      await tester.tap(downloadBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify download attempt produces snackbar feedback for user
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to download Report.pdf'), findsOneWidget);
    });
  });
}
