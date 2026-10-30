import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/data/app_state_provider.dart';
import 'package:flutter_bnx_mail/features/dashboard/presentation/colab_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Colab Main Groups Page UI Tests (Image 1 & 4)', () {
    testWidgets('Renders empty state when no colab groups exist (Image 1)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith((ref) => MockColabListNotifier([])),
          appUiProvider.overrideWith((ref) => MockAppUiNotifier(activeFolder: 'Colab')),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header: Colab, Collaborate with your teams, New Colab button
      expect(find.text('Colab'), findsWidgets);
      expect(find.text('Collaborate with your teams'), findsOneWidget);
      expect(find.text('New Colab'), findsOneWidget);
      expect(find.text('Search colab groups...'), findsOneWidget);

      // Check empty state
      expect(find.text('No colab groups found'), findsOneWidget);
      expect(
        find.text('Create a colab group to start collaborating'),
        findsOneWidget,
      );
    });

    testWidgets('Renders group cards with GROUP badge, date, last message, and Open chat (Image 4)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testGroup = ColabGroup(
        id: 'group_101',
        name: 'alpha ok',
        desc: 'Testing group',
        members: ['chandran123@bnxmail.com', 'ravinew2004@bnxmail.com'],
        lastMessage: 'No messages yet',
        lastMessageTime: '30/10/2026',
        isArchived: false,
        isStarred: false,
      );

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith(
            (ref) => MockColabListNotifier([testGroup]),
          ),
          appUiProvider.overrideWith(
            (ref) => MockAppUiNotifier(activeFolder: 'Colab'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card elements
      expect(find.text('alpha ok'), findsOneWidget);
      expect(find.text('GROUP'), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('30/10/2026'), findsOneWidget);
      expect(find.text('Open chat'), findsOneWidget);

      // Tapping Open chat sets selectedColabIdProvider
      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();

      expect(container.read(selectedColabIdProvider), 'group_101');
    });

    testWidgets('Group card 3-dot menu opens Archive and Star options (Image 4)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testGroup = ColabGroup(
        id: 'group_102',
        name: 'alpha ok',
        members: ['chandran123@bnxmail.com'],
        lastMessage: 'Hello team',
        lastMessageTime: '30/10/2026',
      );

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith(
            (ref) => MockColabListNotifier([testGroup]),
          ),
          appUiProvider.overrideWith(
            (ref) => MockAppUiNotifier(activeFolder: 'Colab'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 3-dot popup menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Star'), findsOneWidget);
    });
  });

  group('Colab Archive Page UI Tests (Image 2)', () {
    testWidgets('Renders Archive header, filter tabs, sections, and archived items', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final archivedGroup = ColabGroup(
        id: 'group_archived_1',
        name: 'alpha ok',
        members: ['chandran123@bnxmail.com'],
        lastMessage: 'No messages yet',
        lastMessageTime: '30/10/2026',
        isArchived: true,
      );

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith(
            (ref) => MockColabListNotifier([archivedGroup]),
          ),
          appUiProvider.overrideWith(
            (ref) => MockAppUiNotifier(activeFolder: 'ColabArchive'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Archive'), findsOneWidget);
      expect(
        find.text(
          'View and manage your archived messages and colab conversations',
        ),
        findsOneWidget,
      );
      expect(find.text('Search archived items...'), findsOneWidget);

      // Check Filter Tabs
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Colab Conversations (1)'), findsOneWidget);
      expect(find.text('Messages (0)'), findsOneWidget);

      // Section header
      expect(find.text('COLAB CONVERSATIONS (1)'), findsOneWidget);

      // Card details
      expect(find.text('alpha ok'), findsOneWidget);
      expect(find.text('GROUP'), findsOneWidget);
      expect(find.text('Open chat'), findsOneWidget);

      // 3-dot popup menu in archive view shows Unarchive
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Unarchive'), findsOneWidget);
    });

    testWidgets('Empty archive state renders when no items are archived', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith((ref) => MockColabListNotifier([])),
          appUiProvider.overrideWith(
            (ref) => MockAppUiNotifier(activeFolder: 'ColabArchive'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No archived items found'), findsOneWidget);
      expect(
        find.text('Archived colab conversations and messages will appear here'),
        findsOneWidget,
      );
    });
  });

  group('Colab Starred Page UI Tests (Image 3)', () {
    testWidgets('Renders Starred Colab Groups empty state with gold star icon', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith((ref) => MockColabListNotifier([])),
          appUiProvider.overrideWith(
            (ref) => MockAppUiNotifier(activeFolder: 'ColabStar'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Starred Colab Groups'), findsOneWidget);
      expect(find.text('View your starred colab groups'), findsOneWidget);
      expect(find.text('Search starred colab groups...'), findsOneWidget);

      expect(find.text('No starred colab groups'), findsOneWidget);
      expect(
        find.text(
          'Click the three-dot menu on any group card and select Star to add it here',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Renders starred groups with Unstar option in menu', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final starredGroup = ColabGroup(
        id: 'group_starred_1',
        name: 'alpha ok',
        members: ['chandran123@bnxmail.com'],
        lastMessage: 'Starred group message',
        lastMessageTime: '30/10/2026',
        isStarred: true,
      );

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith(
            (ref) => MockColabListNotifier([starredGroup]),
          ),
          appUiProvider.overrideWith(
            (ref) => MockAppUiNotifier(activeFolder: 'ColabStar'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('alpha ok'), findsOneWidget);
      expect(find.text('GROUP'), findsOneWidget);

      // Tap 3-dots
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Unstar'), findsOneWidget);
    });
  });

  group('Colab Broadcast Dialog Quick Templates Tests (Image 5)', () {
    testWidgets('Opening broadcast dialog shows 5 templates and auto-populates on selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final group = ColabGroup(
        id: 'group_broadcast_1',
        name: 'alpha ok',
        members: ['chandran123@bnxmail.com', 'ravinew2004@bnxmail.com'],
      );

      final container = ProviderContainer(
        overrides: [
          colabListProvider.overrideWith(
            (ref) => MockColabListNotifier([group]),
          ),
          selectedColabIdProvider.overrideWith((ref) => 'group_broadcast_1'),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ColabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inside chat room, tap Compose New Broadcast
      expect(find.text('Compose New Broadcast'), findsOneWidget);
      await tester.tap(find.text('Compose New Broadcast'));
      await tester.pumpAndSettle();

      // Verify Dialog header, subtitle, labels
      expect(find.text('New Colab Broadcast'), findsOneWidget);
      expect(
        find.text(
          'Send a broadcast announcement to all members of this Colab group',
        ),
        findsOneWidget,
      );
      expect(find.text('QUICK TEMPLATES (OPTIONAL)'), findsOneWidget);
      expect(find.text('SUBJECT *'), findsOneWidget);
      expect(find.text('MESSAGE BODY *'), findsOneWidget);
      expect(find.text('Max 5MB per file'), findsOneWidget);
      expect(find.text('Send Broadcast'), findsOneWidget);

      // Tap template dropdown
      await tester.tap(
        find.text('✓ -- Choose a template to load --').first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Check all 5 templates exist in dropdown matching Image 5
      expect(find.text('Meeting Request'), findsWidgets);
      expect(find.text('Follow-Up Discussion'), findsWidgets);
      expect(find.text('Out of Office'), findsWidgets);
      expect(find.text('Thank You Note'), findsWidgets);
      expect(find.text('Request for Feedback'), findsWidgets);

      // Select 'Meeting Request'
      await tester.tap(find.text('Meeting Request').last);
      await tester.pumpAndSettle();

      // Verify Subject and Body were auto-populated
      expect(find.text('Meeting Request: [Topic/Project Name]'), findsOneWidget);
    });
  });
}

// ── Mock Notifiers for Tests ───────────────────────────────────────────────

class MockColabListNotifier extends ColabListNotifier {
  MockColabListNotifier(List<ColabGroup> initial) {
    state = initial;
  }

  @override
  Future<void> loadGroups([String? userEmail]) async {}

  @override
  Future<void> toggleArchiveGroup(String groupId) async {
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isArchived: !g.isArchived);
      }
      return g;
    }).toList();
  }

  @override
  Future<void> toggleStarGroup(String groupId) async {
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isStarred: !g.isStarred);
      }
      return g;
    }).toList();
  }
}

class MockAppUiNotifier extends AppUiNotifier {
  MockAppUiNotifier({String activeFolder = 'Colab'}) {
    state = state.copyWith(activeFolder: activeFolder);
  }
}
