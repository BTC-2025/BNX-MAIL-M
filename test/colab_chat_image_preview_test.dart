import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/models/attachment_model.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/features/dashboard/presentation/colab_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Colab Chat & Attachment Tests', () {
    test('AttachmentModel preserves filePath/url in toJson for chat attachments', () {
      final att = AttachmentModel(
        fileName: 'screenshot.png',
        fileType: 'PNG',
        fileSize: '565 KB',
        filePath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

      final json = att.toJson();
      expect(json['filename'], equals('screenshot.png'));
      expect(json['url'], equals(att.filePath));
      expect(json['filePath'], equals(att.filePath));

      final restored = AttachmentModel.fromJson(json);
      expect(restored.fileName, equals('screenshot.png'));
      expect(restored.filePath, equals(att.filePath));
    });

    testWidgets('CommentsSection renders image thumbnail card with view and download actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyGroup = ColabGroup(
        id: 'group_1',
        name: 'alpha ok',
        desc: 'Test Group',
        members: ['ravinew2004@bnxmail.com', 'chandran123@bnxmail.com'],
        creatorEmail: 'ravinew2004@bnxmail.com',
        comments: [
          ColabComment(
            sender: 'chandran123@bnxmail.com',
            message: 'Check this image',
            timestamp: DateTime(2026, 10, 30, 9, 12),
            attachments: [
              AttachmentModel(
                fileName: 'sample_photo.png',
                fileType: 'PNG',
                fileSize: '120 KB',
                filePath: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
              ),
            ],
          ),
        ],
        broadcasts: [],
      );

      messagesLoadedIds.add('group_1');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 700,
                child: Consumer(
                  builder: (context, ref, _) {
                    return CommentsSection(
                      group: dummyGroup,
                      isDark: false,
                      ref: ref,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Comments'), findsOneWidget);

      // Check message content
      expect(find.text('Check this image'), findsOneWidget);
      expect(find.text('sample_photo.png'), findsOneWidget);
      expect(find.text('120 KB'), findsOneWidget);

      // Check action icons
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsWidgets);

      // Check input bar elements
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_satisfied_alt_outlined), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // Tap Eye icon to open image preview dialog
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Verify dialog opened with InteractiveViewer
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
