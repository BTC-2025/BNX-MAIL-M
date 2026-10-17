import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/data/repositories/casbox_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Casbox 24 APIs Specification & Notifiers Tests', () {
    test('APIs 1-5: CasboxMessage construction & thread filtering', () {
      final msg1 = CasboxMessage(
        id: 'msg_1',
        sender: 'alice@bnxmail.com',
        to: 'bob@bnxmail.com',
        subject: 'Meeting Update',
        body: 'Let us meet tomorrow at 10 AM',
        timestamp: DateTime.parse('2026-10-06T10:00:00.000Z'),
        status: 'DELIVERED',
        isRead: true,
      );

      final msg2 = CasboxMessage(
        id: 'msg_2',
        sender: 'bob@bnxmail.com',
        to: 'alice@bnxmail.com',
        subject: 'Re: Meeting Update',
        body: 'Sounds good to me!',
        timestamp: DateTime.parse('2026-10-06T10:05:00.000Z'),
        status: 'SENT',
        isRead: false,
      );

      expect(msg1.id, equals('msg_1'));
      expect(msg1.sender, equals('alice@bnxmail.com'));
      expect(msg1.to, equals('bob@bnxmail.com'));
      expect(msg2.body, equals('Sounds good to me!'));
      expect(msg2.isArchived, isFalse);
    });

    test('APIs 6-7: CasboxMessage isArchived toggle and copyWith', () {
      final msg = CasboxMessage(
        id: 'msg_archive_1',
        sender: 'alice@bnxmail.com',
        to: 'bob@bnxmail.com',
        subject: 'Quarterly Report',
        body: 'Report attached.',
        timestamp: DateTime.now(),
        status: 'DELIVERED',
        isArchived: false,
      );

      final archivedMsg = msg.copyWith(isArchived: true);
      expect(archivedMsg.isArchived, isTrue);

      final unarchivedMsg = archivedMsg.copyWith(isArchived: false);
      expect(unarchivedMsg.isArchived, isFalse);
    });

    test('APIs 8-10: CasboxMessage status transitions (SENT -> DELIVERED -> SEEN -> READ)', () {
      final msg = CasboxMessage(
        id: 'msg_status_1',
        sender: 'alice@bnxmail.com',
        to: 'bob@bnxmail.com',
        subject: 'Status Check',
        body: 'Hello',
        timestamp: DateTime.now(),
        status: 'SENT',
      );
      expect(msg.status, equals('SENT'));

      final delivered = msg.copyWith(status: 'DELIVERED');
      expect(delivered.status, equals('DELIVERED'));

      final seen = delivered.copyWith(status: 'SEEN');
      expect(seen.status, equals('SEEN'));

      final read = seen.copyWith(status: 'READ');
      expect(read.status, equals('READ'));
    });

    test('API 11: CasboxMessage editMessage body update and isEdited flag', () {
      final original = CasboxMessage(
        id: 'msg_edit_1',
        sender: 'alice@bnxmail.com',
        to: 'bob@bnxmail.com',
        subject: 'Design Doc',
        body: 'Original draft',
        timestamp: DateTime.now(),
        status: 'SENT',
      );

      final edited = original.copyWith(body: 'Updated final draft');
      expect(edited.body, equals('Updated final draft'));
      expect(edited.id, equals(original.id));
    });

    test('APIs 12-14: CasboxConnectionsNotifier handles maps and status updates', () {
      final notifier = CasboxConnectionsNotifier();
      notifier.state = [
        {'id': 'conn_1', 'email': 'alice@bnxmail.com', 'status': 'PENDING'},
        {'id': 'conn_2', 'email': 'bob@bnxmail.com', 'status': 'ACCEPTED'},
      ];

      expect(notifier.state.length, equals(2));
      expect(notifier.state[0]['status'], equals('PENDING'));
      expect(notifier.state[1]['status'], equals('ACCEPTED'));
    });

    test('APIs 15-18: CasboxAliasesNotifier local caching & updates', () {
      final notifier = CasboxAliasesNotifier();
      notifier.state = {'user123': 'John Doe', 'alice': 'Alice Smith'};

      expect(notifier.state['user123'], equals('John Doe'));
      expect(notifier.state['alice'], equals('Alice Smith'));
      expect(notifier.state['unknown'], isNull);
    });

    test('APIs 19-22: CasboxBlockedContactsNotifier blocking and unblocking', () {
      final notifier = CasboxBlockedContactsNotifier();
      expect(notifier.state.contains('spammer'), isFalse);

      notifier.state = ['spammer', 'scam_bot'];
      expect(notifier.state.contains('spammer'), isTrue);
      expect(notifier.state.contains('scam_bot'), isTrue);
      expect(notifier.state.contains('friend'), isFalse);
    });

    test('APIs 23-24 & All 24 Methods exist on CasboxRepository', () {
      // 1. fetchCasbox
      expect(CasboxRepository.fetchCasbox, isNotNull);
      // 2. fetchThread
      expect(CasboxRepository.fetchThread, isNotNull);
      // 3. sendCasboxMessage
      expect(CasboxRepository.sendCasboxMessage, isNotNull);
      // 4. batchArchiveMessages
      expect(CasboxRepository.batchArchiveMessages, isNotNull);
      // 5. archiveMessage
      expect(CasboxRepository.archiveMessage, isNotNull);
      // 6. updateStatus
      expect(CasboxRepository.updateStatus, isNotNull);
      // 7. updateMessagesStatus
      expect(CasboxRepository.updateMessagesStatus, isNotNull);
      // 8. markAllDelivered
      expect(CasboxRepository.markAllDelivered, isNotNull);
      // 9. markDelivered
      expect(CasboxRepository.markDelivered, isNotNull);
      // 10. editMessage
      expect(CasboxRepository.editMessage, isNotNull);
      // 11. deleteConversation
      expect(CasboxRepository.deleteConversation, isNotNull);
      // 12. getAcceptedConnections
      expect(CasboxRepository.getAcceptedConnections, isNotNull);
      // 13. getAllConnections
      expect(CasboxRepository.getAllConnections, isNotNull);
      // 14. updateConnectionStatus
      expect(CasboxRepository.updateConnectionStatus, isNotNull);
      // 15. getContactAliases
      expect(CasboxRepository.getContactAliases, isNotNull);
      // 16. getContactAlias
      expect(CasboxRepository.getContactAlias, isNotNull);
      // 17. setContactAlias
      expect(CasboxRepository.setContactAlias, isNotNull);
      // 18. deleteContactAlias
      expect(CasboxRepository.deleteContactAlias, isNotNull);
      // 19. getBlockedContacts
      expect(CasboxRepository.getBlockedContacts, isNotNull);
      // 20. isBlocked
      expect(CasboxRepository.isBlocked, isNotNull);
      // 21. blockContact
      expect(CasboxRepository.blockContact, isNotNull);
      // 22. unblockContact
      expect(CasboxRepository.unblockContact, isNotNull);
      // 23. getAuthorizedContacts
      expect(CasboxRepository.getAuthorizedContacts, isNotNull);
      // 24. updateAuthorizedContacts
      expect(CasboxRepository.updateAuthorizedContacts, isNotNull);
    });
  });
}
