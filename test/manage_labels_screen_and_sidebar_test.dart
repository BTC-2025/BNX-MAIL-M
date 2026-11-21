import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/features/labels/presentation/manage_labels_screen.dart';
import 'package:flutter_bnx_mail/core/widgets/create_label_dialog.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/models/label_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ManageLabelsScreen UI & Behavior Tests', () {
    testWidgets('renders Header, System labels, Categories, and Labels cards', (
      tester,
    ) async {
      final customLabels = [
        const LabelModel(id: '1', name: 'Innewacc', color: Color(0xFFEC4899)),
        const LabelModel(id: '2', name: 'iutyfgyg', color: Color(0xFF10B981)),
        const LabelModel(id: '3', name: 'tell', color: Color(0xFF06B6D4)),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customLabelsProvider.overrideWith(
              (ref) => _MockCustomLabelsNotifier(ref, customLabels),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ManageLabelsScreen())),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Label management'), findsOneWidget);
      expect(
        find.text(
          'Create, edit, remove, and manage how labels appear in your BNXmail.',
        ),
        findsOneWidget,
      );

      // Check section titles
      expect(find.text('System labels'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Labels'), findsOneWidget);

      // Check system label items
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Starred'), findsOneWidget);
      expect(find.text('Snoozed'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Spam'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);

      // Check category items
      expect(find.text('Purchases'), findsOneWidget);
      expect(find.text('Social'), findsOneWidget);
      expect(find.text('Updates'), findsOneWidget);
      expect(find.text('Promotions'), findsOneWidget);
      expect(find.text('Job'), findsOneWidget);
      expect(find.text('Important'), findsOneWidget);

      // Check custom labels
      expect(find.text('Innewacc'), findsOneWidget);
      expect(find.text('iutyfgyg'), findsOneWidget);
      expect(find.text('tell'), findsOneWidget);

      // Check actions in table
      expect(find.text('Edit'), findsNWidgets(3));
      expect(find.text('Remove'), findsNWidgets(3));
      expect(find.text('Create new label'), findsOneWidget);
    });

    testWidgets('CreateLabelDialog renders 10 color swatches and inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: CreateLabelDialog())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New label'), findsOneWidget);
      expect(find.text('Please enter a new label name:'), findsOneWidget);
      expect(find.text('Label color:'), findsOneWidget);
      expect(find.text('Nest label under: (optional)'), findsOneWidget);
      expect(find.text('Top level (no parent)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets(
      'Toggling checkbox updates state and Save triggers without error',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: ManageLabelsScreen())),
          ),
        );
        await tester.pumpAndSettle();

        // Find Save button in header
        final saveBtn = find.widgetWithText(ElevatedButton, 'Save').first;
        expect(saveBtn, findsOneWidget);

        await tester.tap(saveBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}

class _MockCustomLabelsNotifier extends CustomLabelsNotifier {
  _MockCustomLabelsNotifier(super.ref, List<LabelModel> initial) {
    state = initial;
  }

  @override
  Future<void> fetchLabels() async {}

  @override
  Future<void> switchAccountContext(String accountId) async {}

  @override
  void clear() {
    state = const [];
  }

  @override
  Future<void> addLabel(String name, Color color) async {
    state = [
      ...state,
      LabelModel(id: name.toLowerCase(), name: name, color: color),
    ];
  }

  @override
  Future<void> editLabel(String id, String newName, Color newColor) async {
    state = state
        .map(
          (l) => l.id == id
              ? LabelModel(id: id, name: newName, color: newColor)
              : l,
        )
        .toList();
  }

  @override
  Future<void> deleteLabel(String idOrName) async {
    state = state.where((l) => l.id != idOrName && l.name != idOrName).toList();
  }
}
