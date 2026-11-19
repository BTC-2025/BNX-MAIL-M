import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bit_tool_module/bit_tool_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BitToolModule API & Architecture Tests', () {
    test('BitToolApiModule initializes with all 8 modules', () {
      final module = BitToolApiModule(
        tokenProvider: () async => 'test-bearer-token',
      );

      expect(module.contacts, isNotNull);
      expect(module.notes, isNotNull);
      expect(module.calendar, isNotNull);
      expect(module.calculator, isNotNull);
      expect(module.notifications, isNotNull);
      expect(module.weather, isNotNull);
      expect(module.currency, isNotNull);
      expect(module.userProfile, isNotNull);
    });

    test('Contacts provider manages contacts and search query', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(bitToolContactsProvider);
      expect(state.contacts, isA<List<ContactModel>>());

      final added = await container.read(bitToolContactsProvider.notifier).addContact(
        firstName: 'Ananya',
        lastName: 'Iyer',
        email: 'ananya@bittool.dev',
        phone: '+91 9988776655',
        company: 'BitTool Inc',
        role: 'Tech Lead',
      );
      expect(added, isTrue);

      final updatedState = container.read(bitToolContactsProvider);
      expect(updatedState.contacts.any((c) => c.firstName == 'Ananya'), isTrue);

      container.read(bitToolContactsProvider.notifier).setSearchQuery('Ananya');
      expect(container.read(bitToolContactsProvider).filteredContacts.length, 1);
    });

    test('Notes provider creates, pins, and deletes notes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialNotes = container.read(bitToolNotesProvider);
      expect(initialNotes.notes, isA<List<NoteModel>>());

      final created = await container.read(bitToolNotesProvider.notifier).createNote(
        title: 'Standup Notes',
        content: 'Review deployment checklists',
        color: '#FED7D7',
        isPinned: true,
      );
      expect(created, isTrue);

      final updatedState = container.read(bitToolNotesProvider);
      final newNote = updatedState.notes.firstWhere((n) => n.title == 'Standup Notes');
      expect(newNote.isPinned, isTrue);

      final deleted = await container.read(bitToolNotesProvider.notifier).deleteNote(newNote.id);
      expect(deleted, isTrue);
    });

    test('Calculator provider manages tape state and sessions', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final calcState = container.read(bitToolCalculatorProvider);
      expect(calcState.sessions, isA<List<CalculatorSession>>());
    });
  });

  group('BitToolRightUtilityRail UI Tests', () {
    testWidgets('Renders rail and toggles panels correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: BitToolRightUtilityRail(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the rail is present with all tools
      expect(find.byType(BitToolRightUtilityRail), findsOneWidget);
      expect(find.byTooltip('Beta Apps'), findsOneWidget);
      expect(find.byTooltip('Calculator'), findsOneWidget);
      expect(find.byTooltip('Calendar'), findsOneWidget);
      expect(find.byTooltip('Notes'), findsOneWidget);
      expect(find.byTooltip('Contacts'), findsOneWidget);
      expect(find.byTooltip('Weather'), findsOneWidget);
      expect(find.byTooltip('Keyboard'), findsOneWidget);
      expect(find.byTooltip('Toggle Drawer'), findsOneWidget);

      // Verify obsolete popup menu button is GONE
      expect(find.byTooltip('More Utilities'), findsNothing);

      // 1. Open Calculator
      await tester.tap(find.byTooltip('Calculator'));
      await tester.pumpAndSettle();
      expect(find.text('CALCULATOR'), findsOneWidget);

      // 2. Open Calendar
      await tester.tap(find.byTooltip('Calendar'));
      await tester.pumpAndSettle();
      expect(find.text('CALENDAR'), findsOneWidget);

      // 3. Open Notes
      await tester.tap(find.byTooltip('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('NOTES'), findsOneWidget);

      // 4. Open Contacts
      await tester.tap(find.byTooltip('Contacts'));
      await tester.pumpAndSettle();
      expect(find.text('GLOBAL CONTACTS'), findsOneWidget);

      // 5. Open Weather
      await tester.tap(find.byTooltip('Weather'));
      await tester.pumpAndSettle();
      expect(find.text('WEATHER'), findsOneWidget);

      // 6. Open Keyboard
      await tester.tap(find.byTooltip('Keyboard'));
      await tester.pumpAndSettle();
      expect(find.text('KEYBOARD'), findsOneWidget);
    });
  });
}
