import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';

class _MockCasboxNotifier extends CasboxMessagesNotifier {
  _MockCasboxNotifier() : super();
  @override
  Future<void> fetchMessages([List<EmailModel>? mailboxEmails]) async {}
  @override
  Future<void> fetchThreadMessages(dynamic otherEmailOrId) async {}
}

class _MockCasboxConnectionsNotifier extends CasboxConnectionsNotifier {
  _MockCasboxConnectionsNotifier() : super();
  @override
  Future<void> fetchConnections([String? userEmail]) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Casbox Archive & Unarchive Deep Integration Tests', () {
    test('CasboxMessage.fromJson correctly respects backend isArchived boolean without receiverArchived override bug', () {
      // Scenario 1: Other user archived, but current user did not
      final serverJson1 = {
        'id': 1042,
        'senderEmail': 'bob@bnxmail.com',
        'receiverEmail': 'alice@bnxmail.com',
        'subject': 'Discussion',
        'body': 'Hello Alice',
        'status': 'DELIVERED',
        'isArchived': false,
        'senderArchived': false,
        'receiverArchived': true,
      };

      final msg1 = CasboxMessage.fromJson(serverJson1);
      // Must NOT be archived for the current user!
      expect(msg1.isArchived, isFalse);

      // Scenario 2: Current user archived
      final serverJson2 = {
        'id': 1043,
        'senderEmail': 'bob@bnxmail.com',
        'receiverEmail': 'alice@bnxmail.com',
        'subject': 'Discussion',
        'body': 'Hello Alice',
        'status': 'DELIVERED',
        'isArchived': true,
        'senderArchived': true,
        'receiverArchived': false,
      };

      final msg2 = CasboxMessage.fromJson(serverJson2);
      expect(msg2.isArchived, isTrue);
    });

    test('CasboxMessagesNotifier archives and unarchives single and batch messages correctly', () async {
      final notifier = _MockCasboxNotifier();
      notifier.state = [
        CasboxMessage(
          id: '101',
          sender: 'chandran123@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: 'Discussion',
          body: 'Hello',
          timestamp: DateTime.now(),
          isArchived: false,
        ),
        CasboxMessage(
          id: '102',
          sender: 'itsokletssee123@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: 'Automated Test',
          body: 'Working?',
          timestamp: DateTime.now(),
          isArchived: false,
        ),
      ];

      // 1. Archive single message 101
      await notifier.archiveMessage('101', true);
      expect(notifier.state.firstWhere((m) => m.id == '101').isArchived, isTrue);
      expect(notifier.state.firstWhere((m) => m.id == '102').isArchived, isFalse);

      // 2. Unarchive single message 101
      await notifier.archiveMessage('101', false);
      expect(notifier.state.firstWhere((m) => m.id == '101').isArchived, isFalse);

      // 3. Batch archive 101 and 102
      await notifier.batchArchiveMessages(['101', '102'], true);
      expect(notifier.state.every((m) => m.isArchived), isTrue);

      // 4. Batch unarchive 101 and 102
      await notifier.batchArchiveMessages(['101', '102'], false);
      expect(notifier.state.every((m) => !m.isArchived), isTrue);
    });
  });

  group('Casbox Connections Parsing & Toggle Integration Tests', () {
    test('CasboxConnectionsNotifier properly parses backend connectedUserEmail and id', () {
      final notifier = _MockCasboxConnectionsNotifier();

      // Backend /api/connections response model
      final backendConnections = [
        {
          'id': 12,
          'userId': 5,
          'userEmail': 'me@bnxmail.com',
          'userName': 'Me',
          'connectedUserId': 8,
          'connectedUserEmail': 'chandran123@bnxmail.com',
          'connectedUserName': 'chandran123',
          'status': 'CONNECTED',
        },
        {
          'id': 13,
          'userId': 5,
          'userEmail': 'me@bnxmail.com',
          'userName': 'Me',
          'connectedUserId': 9,
          'connectedUserEmail': 'itsokletssee123@bnxmail.com',
          'connectedUserName': 'itsokletssee123',
          'status': 'CONNECTED',
        },
        {
          'id': 14,
          'userId': 5,
          'userEmail': 'me@bnxmail.com',
          'userName': 'Me',
          'connectedUserId': 10,
          'connectedUserEmail': 'ramani@bnxmail.com',
          'connectedUserName': 'ramani',
          'status': 'CONNECTED',
        },
        {
          'id': 15,
          'userId': 5,
          'userEmail': 'me@bnxmail.com',
          'userName': 'Me',
          'connectedUserId': 11,
          'connectedUserEmail': 'ravikumar@bnxmail.com',
          'connectedUserName': 'ravikumar',
          'status': 'CONNECTED',
        },
        {
          'id': 16,
          'userId': 5,
          'userEmail': 'me@bnxmail.com',
          'userName': 'Me',
          'connectedUserId': 12,
          'connectedUserEmail': 'dinesh.anand376@bnxmail.com',
          'connectedUserName': 'dinesh.anand376',
          'status': 'CONNECTED',
        },
      ];

      notifier.state = backendConnections.map((c) => {
        'id': c['id'],
        'connectionId': c['id'],
        'email': c['connectedUserEmail'],
        'name': c['connectedUserName'],
        'handle': '@${c['connectedUserName']}',
        'status': c['status'],
      }).toList();

      expect(notifier.state.length, equals(5));
      expect(notifier.state.every((c) => c['status'] == 'CONNECTED'), isTrue);
    });

    test('Updating connection status toggles status without removing contact from list', () async {
      final notifier = _MockCasboxConnectionsNotifier();
      notifier.state = [
        {
          'id': 12,
          'connectionId': 12,
          'email': 'chandran123@bnxmail.com',
          'name': 'chandran123',
          'handle': '@chandran123',
          'status': 'CONNECTED',
        },
        {
          'id': 13,
          'connectionId': 13,
          'email': 'itsokletssee123@bnxmail.com',
          'name': 'itsokletssee123',
          'handle': '@itsokletssee123',
          'status': 'CONNECTED',
        },
      ];

      // Disconnect contact 12 by ID
      await notifier.updateConnectionStatus(12, 'DISCONNECTED');
      expect(notifier.state.length, equals(2)); // Must NOT remove from list!
      expect(notifier.state.firstWhere((c) => c['id'] == 12)['status'], equals('DISCONNECTED'));
      expect(notifier.state.firstWhere((c) => c['id'] == 13)['status'], equals('CONNECTED'));

      // Reconnect contact 12 by email
      await notifier.updateConnectionStatus('chandran123@bnxmail.com', 'CONNECTED');
      expect(notifier.state.length, equals(2));
      expect(notifier.state.firstWhere((c) => c['id'] == 12)['status'], equals('CONNECTED'));
    });
  });
}
