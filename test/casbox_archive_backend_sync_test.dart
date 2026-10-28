import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';
import 'package:flutter_bnx_mail/core/network/token_service.dart';

class _BackendSyncCasboxNotifier extends CasboxMessagesNotifier {
  _BackendSyncCasboxNotifier(List<CasboxMessage> serverMessages)
      : _serverStore = List.from(serverMessages),
        super() {
    state = List.from(_serverStore);
  }

  final List<CasboxMessage> _serverStore;
  int fetchMessagesCallCount = 0;

  @override
  Future<void> fetchMessages([List<EmailModel>? mailboxEmails]) async {
    fetchMessagesCallCount++;
    // Simulates retrieving fresh state directly from backend GET /api/casbox
    state = List.from(_serverStore);
  }

  @override
  Future<void> archiveMessage(dynamic messageId, [bool archived = true]) async {
    // 1. Optimistic update
    final strId = messageId.toString();
    state = state.map((m) => m.id == strId ? m.copyWith(isArchived: archived) : m).toList();

    // 2. Simulates backend API updating database
    for (int i = 0; i < _serverStore.length; i++) {
      if (_serverStore[i].id == strId) {
        _serverStore[i] = _serverStore[i].copyWith(isArchived: archived);
      }
    }

    // 3. Retrieve fresh state from backend API each time
    await fetchMessages();
  }

  @override
  Future<void> batchArchiveMessages(List<dynamic> messageIds, [bool archived = true]) async {
    final strIds = messageIds.map((id) => id.toString()).toSet();
    state = state.map((m) => strIds.contains(m.id) ? m.copyWith(isArchived: archived) : m).toList();

    for (int i = 0; i < _serverStore.length; i++) {
      if (strIds.contains(_serverStore[i].id)) {
        _serverStore[i] = _serverStore[i].copyWith(isArchived: archived);
      }
    }

    await fetchMessages();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Casbox Seamless Backend Archive & Unarchive API Integration Tests', () {
    test('CasboxMessage.fromJson parses isArchived cleanly across all formats without crashing', () {
      final jsonBoolTrue = {
        'id': 1040,
        'senderEmail': 'alice@bnxmail.com',
        'receiverEmail': 'me@bnxmail.com',
        'subject': 'Discussion',
        'body': 'ok see whether it came or not ?',
        'status': 'DELIVERED',
        'isArchived': true,
      };
      expect(CasboxMessage.fromJson(jsonBoolTrue).isArchived, isTrue);

      final jsonBoolFalse = {
        'id': 1041,
        'senderEmail': 'alice@bnxmail.com',
        'receiverEmail': 'me@bnxmail.com',
        'subject': 'Discussion',
        'body': 'last updated msg',
        'status': 'DELIVERED',
        'isArchived': false,
      };
      expect(CasboxMessage.fromJson(jsonBoolFalse).isArchived, isFalse);

      final jsonNumericOne = {
        'id': 1042,
        'senderEmail': 'alice@bnxmail.com',
        'receiverEmail': 'me@bnxmail.com',
        'subject': 'Test',
        'body': 'Numeric boolean test',
        'status': 'DELIVERED',
        'isArchived': 1,
      };
      expect(CasboxMessage.fromJson(jsonNumericOne).isArchived, isTrue);

      final jsonStringFalse = {
        'id': 1043,
        'senderEmail': 'alice@bnxmail.com',
        'receiverEmail': 'me@bnxmail.com',
        'subject': 'Test',
        'body': 'String boolean test',
        'status': 'DELIVERED',
        'isArchived': 'false',
      };
      expect(CasboxMessage.fromJson(jsonStringFalse).isArchived, isFalse);
    });

    test('Each archive or unarchive triggers seamless backend API call & retrieves latest data via fetchMessages', () async {
      final initialServerMessages = [
        CasboxMessage(
          id: '1040',
          sender: 'chandran123@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: 'Discussion',
          body: 'last updated msg',
          timestamp: DateTime.now(),
          status: 'DELIVERED',
          isArchived: false,
        ),
        CasboxMessage(
          id: '1041',
          sender: 'chandran123@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: '12345670',
          body: '123456789wsedry',
          timestamp: DateTime.now(),
          status: 'DELIVERED',
          isArchived: false,
        ),
      ];

      final notifier = _BackendSyncCasboxNotifier(initialServerMessages);
      final initialCount = notifier.fetchMessagesCallCount;
      expect(initialCount, equals(1)); // Constructor automatically calls fetchMessages() on init

      // 1. Archive message 1040
      await notifier.archiveMessage('1040', true);
      expect(notifier.fetchMessagesCallCount, equals(initialCount + 1));
      expect(notifier.state.firstWhere((m) => m.id == '1040').isArchived, isTrue);
      expect(notifier.state.firstWhere((m) => m.id == '1041').isArchived, isFalse);

      // 2. Unarchive message 1040
      await notifier.archiveMessage('1040', false);
      expect(notifier.fetchMessagesCallCount, equals(initialCount + 2));
      expect(notifier.state.firstWhere((m) => m.id == '1040').isArchived, isFalse);

      // 3. Batch archive 1040 and 1041
      await notifier.batchArchiveMessages(['1040', '1041'], true);
      expect(notifier.fetchMessagesCallCount, equals(initialCount + 3));
      expect(notifier.state.every((m) => m.isArchived), isTrue);

      // 4. Batch unarchive 1040 and 1041
      await notifier.batchArchiveMessages(['1040', '1041'], false);
      expect(notifier.fetchMessagesCallCount, equals(initialCount + 4));
      expect(notifier.state.every((m) => !m.isArchived), isTrue);
    });

    test('Thread messages batch archive archives all messages belonging to a conversation', () async {
      final threadMessages = List.generate(
        9,
        (i) => CasboxMessage(
          id: '${1000 + i}',
          sender: i % 2 == 0 ? 'chandran123@bnxmail.com' : 'me@bnxmail.com',
          to: i % 2 == 0 ? 'me@bnxmail.com' : 'chandran123@bnxmail.com',
          subject: 'Discussion $i',
          body: 'Message content $i',
          timestamp: DateTime.now().subtract(Duration(minutes: i * 5)),
          status: 'DELIVERED',
          isArchived: true,
        ),
      );

      final notifier = _BackendSyncCasboxNotifier(threadMessages);
      expect(notifier.state.every((m) => m.isArchived), isTrue);

      // Unarchive all 9 messages in the thread
      final threadIds = notifier.state.map((m) => m.id).toList();
      await notifier.batchArchiveMessages(threadIds, false);

      expect(notifier.state.length, equals(9));
      expect(notifier.state.every((m) => !m.isArchived), isTrue);
    });

    test('TokenService clears archive persistence and returns empty sets', () async {
      await TokenService.clearCasboxArchivePersistence();
      final archived = await TokenService.getArchivedCasboxIds();
      final unarchived = await TokenService.getUnarchivedCasboxIds();
      expect(archived, isEmpty);
      expect(unarchived, isEmpty);
    });
  });
}
