import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/core/network/token_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CasboxMessage Archive Per-User Resolution Tests', () {
    test('Recipient only sees message as archived if receiverArchived is true', () {
      final jsonWhereSenderArchived = {
        'id': 1001,
        'sender': 'sender@bnxmail.com',
        'recipient': 'recipient@bnxmail.com',
        'subject': 'Test Subject',
        'body': 'Hello recipient',
        'isArchived': false,
        'senderArchived': true,
        'receiverArchived': false,
      };

      // When parsed for recipient, it should NOT be archived
      final msgForRecipient = CasboxMessage.fromJson(jsonWhereSenderArchived, 'recipient@bnxmail.com');
      expect(msgForRecipient.isArchived, isFalse);

      // When parsed for sender, it SHOULD be archived
      final msgForSender = CasboxMessage.fromJson(jsonWhereSenderArchived, 'sender@bnxmail.com');
      expect(msgForSender.isArchived, isTrue);
    });

    test('Supports snake_case sender_archived and receiver_archived from backend', () {
      final jsonSnakeCase = {
        'id': 1002,
        'sender': 'sender@bnxmail.com',
        'recipient': 'recipient@bnxmail.com',
        'subject': 'Snake Case Test',
        'body': 'Testing snake_case fields',
        'sender_archived': false,
        'receiver_archived': true,
      };

      final msgSender = CasboxMessage.fromJson(jsonSnakeCase, 'sender@bnxmail.com');
      final msgReceiver = CasboxMessage.fromJson(jsonSnakeCase, 'recipient@bnxmail.com');

      expect(msgSender.isArchived, isFalse);
      expect(msgReceiver.isArchived, isTrue);
    });

    test('Matches user handle correctly with full email address', () {
      final jsonHandleOnly = {
        'id': 1003,
        'sender': 'chandran123',
        'recipient': 'ravinew2004',
        'subject': 'Handle Test',
        'body': 'Testing handle match',
        'sender_archived': true,
        'receiver_archived': false,
      };

      final msgSender = CasboxMessage.fromJson(jsonHandleOnly, 'chandran123@bnxmail.com');
      final msgReceiver = CasboxMessage.fromJson(jsonHandleOnly, 'ravinew2004@bnxmail.com');

      expect(msgSender.isArchived, isTrue);
      expect(msgReceiver.isArchived, isFalse);
    });

    test('Receiver archiving message archives for receiver, not sender', () {
      final jsonWhereReceiverArchived = {
        'id': 1002,
        'sender': 'sender@bnxmail.com',
        'recipient': 'recipient@bnxmail.com',
        'subject': 'Another Subject',
        'body': 'Hello again',
        'isArchived': false,
        'senderArchived': false,
        'receiverArchived': true,
      };

      // When parsed for recipient, it SHOULD be archived
      final msgForRecipient = CasboxMessage.fromJson(jsonWhereReceiverArchived, 'recipient@bnxmail.com');
      expect(msgForRecipient.isArchived, isTrue);

      // When parsed for sender, it should NOT be archived
      final msgForSender = CasboxMessage.fromJson(jsonWhereReceiverArchived, 'sender@bnxmail.com');
      expect(msgForSender.isArchived, isFalse);
    });

    test('Different messages with different subjects do not cross-archive in scoping', () {
      final allMsgs = [
        CasboxMessage(
          id: '1',
          sender: 'contact@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: 'manoj subject',
          body: 'Checking last msg',
          timestamp: DateTime.now(),
        ),
        CasboxMessage(
          id: '2',
          sender: 'contact@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: '728281991919',
          body: '9742450298',
          timestamp: DateTime.now(),
        ),
        CasboxMessage(
          id: '3',
          sender: 'contact@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: 'yuck',
          body: 'hii',
          timestamp: DateTime.now(),
        ),
      ];

      final selectedMsg = allMsgs[0]; // 'manoj subject'

      // Subject-scoped thread filtering:
      final targetIds = allMsgs
          .where((m) =>
              selectedMsg.subject.trim().isEmpty ||
              m.subject.trim().toLowerCase() == selectedMsg.subject.trim().toLowerCase())
          .map((m) => m.id)
          .toList();

      expect(targetIds, equals(['1']));
      expect(targetIds.contains('2'), isFalse);
      expect(targetIds.contains('3'), isFalse);
    });
  });

  group('Colab Group Archive and Star Status Tests', () {
    test('ColabGroup copyWith properly updates isArchived and isStarred', () {
      final group = ColabGroup(
        id: 'group_test_1',
        name: 'alpha ok',
        members: ['chandran123@bnxmail.com'],
        isArchived: false,
        isStarred: false,
      );

      final archivedGroup = group.copyWith(isArchived: true);
      expect(archivedGroup.isArchived, isTrue);
      expect(archivedGroup.isStarred, isFalse);

      final starredGroup = archivedGroup.copyWith(isStarred: true);
      expect(starredGroup.isArchived, isTrue);
      expect(starredGroup.isStarred, isTrue);
    });

    test('TokenService preserves and unarchives group 35 cleanly', () async {
      final testEmail = 'chandran123@bnxmail.com';

      // 1. Archive group 35
      await TokenService.saveArchivedColabGroupIds({'35'}, testEmail);
      final archived = await TokenService.getArchivedColabGroupIds(testEmail);
      expect(archived.contains('35'), isTrue);

      // 2. Unarchive group 35
      await TokenService.saveArchivedColabGroupIds({}, testEmail);
      final unarchived = await TokenService.getArchivedColabGroupIds(testEmail);
      expect(unarchived.contains('35'), isFalse);
      expect(unarchived.isEmpty, isTrue);
    });

    test('TokenService preserves and toggles starred Colab groups', () async {
      final testEmail = 'chandran123@bnxmail.com';

      // 1. Star group 35
      await TokenService.saveStarredColabGroupIds({'35'}, testEmail);
      final starred = await TokenService.getStarredColabGroupIds(testEmail);
      expect(starred.contains('35'), isTrue);

      // 2. Unstar group 35
      await TokenService.saveStarredColabGroupIds({}, testEmail);
      final unstarred = await TokenService.getStarredColabGroupIds(testEmail);
      expect(unstarred.contains('35'), isFalse);
    });

    test('TokenService preserves and toggles starred Casbox messages', () async {
      final testEmail = 'chandran123@bnxmail.com';

      // 1. Star message 1050
      await TokenService.toggleStarredCasboxId('1050', true, testEmail);
      var starredMsgs = await TokenService.getStarredCasboxIds(testEmail);
      var unstarredMsgs = await TokenService.getUnstarredCasboxIds(testEmail);
      expect(starredMsgs.contains('1050'), isTrue);
      expect(unstarredMsgs.contains('1050'), isFalse);

      // 2. Unstar message 1050
      await TokenService.toggleStarredCasboxId('1050', false, testEmail);
      starredMsgs = await TokenService.getStarredCasboxIds(testEmail);
      unstarredMsgs = await TokenService.getUnstarredCasboxIds(testEmail);
      expect(starredMsgs.contains('1050'), isFalse);
      expect(unstarredMsgs.contains('1050'), isTrue);
    });

    test('CasboxMessage parses star status from isStarred, starred, or is_starred', () {
      final m1 = CasboxMessage.fromJson({'id': 1, 'isStarred': true, 'sender': 'a@b.c'});
      expect(m1.isStarred, isTrue);

      final m2 = CasboxMessage.fromJson({'id': 2, 'starred': true, 'sender': 'a@b.c'});
      expect(m2.isStarred, isTrue);

      final m3 = CasboxMessage.fromJson({'id': 3, 'is_starred': true, 'sender': 'a@b.c'});
      expect(m3.isStarred, isTrue);

      final m4 = CasboxMessage.fromJson({'id': 4, 'isStarred': false, 'sender': 'a@b.c'});
      expect(m4.isStarred, isFalse);
    });

    test('ColabListNotifier toggles star and archive cleanly', () async {
      final notifier = ColabListNotifier();
      final g1 = ColabGroup(id: '35', name: 'alpha ok', members: ['chandran123@bnxmail.com']);
      notifier.setGroupsForTesting([g1]);

      expect(notifier.state.first.isStarred, isFalse);
      expect(notifier.state.first.isArchived, isFalse);

      // Star group
      await notifier.toggleStarGroup('35');
      expect(notifier.state.first.isStarred, isTrue);

      // Archive group
      await notifier.toggleArchiveGroup('35');
      expect(notifier.state.first.isArchived, isTrue);
      expect(notifier.state.first.isStarred, isTrue);

      // Unarchive group
      await notifier.toggleArchiveGroup('35');
      expect(notifier.state.first.isArchived, isFalse);
      expect(notifier.state.first.isStarred, isTrue);

      // Unstar group
      await notifier.toggleStarGroup('35');
      expect(notifier.state.first.isStarred, isFalse);
    });

    test('CasboxMessagesNotifier stars and unstars thread messages seamlessly', () async {
      final notifier = CasboxMessagesNotifier();
      while (notifier.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      final m1 = CasboxMessage(
        id: '402',
        sender: 'ravinew2004@bnxmail.com',
        to: 'chandran123@bnxmail.com',
        subject: 'Thread A',
        body: 'Message 1',
        timestamp: DateTime.now(),
      );
      final m2 = CasboxMessage(
        id: '403',
        sender: 'ravinew2004@bnxmail.com',
        to: 'chandran123@bnxmail.com',
        subject: 'Thread A',
        body: 'Message 2',
        timestamp: DateTime.now(),
      );
      notifier.clear();
      notifier.setMessagesForTesting([m1, m2]);

      // Star message 402 - should star the conversation (both 402 and 403)
      await notifier.toggleStar('402');
      expect(notifier.state.firstWhere((m) => m.id == '402').isStarred, isTrue);
      expect(notifier.state.firstWhere((m) => m.id == '403').isStarred, isTrue);

      // Unstar message 403 - should unstar the conversation
      await notifier.toggleStar('403');
      expect(notifier.state.firstWhere((m) => m.id == '402').isStarred, isFalse);
      expect(notifier.state.firstWhere((m) => m.id == '403').isStarred, isFalse);
    });
  });
}

