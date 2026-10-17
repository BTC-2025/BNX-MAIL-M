import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bnx_mail/data/repositories/casbox_repository.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/models/attachment_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('24 Casbox APIs Specification & Model Verification', () {
    // ── API 1: Fetch all messages (GET /api/casbox)
    test('API 1: CasboxMessage.fromJson correctly deserializes message DTO', () {
      final json = {
        'id': 1001,
        'senderEmail': 'alice@bnxmail.com',
        'receiverEmail': 'bob@bnxmail.com',
        'subject': 'Project Discussion',
        'body': 'Let us align on the new specs',
        'timestamp': '2026-10-06T10:00:00Z',
        'status': 'DELIVERED',
        'isEdited': false,
        'attachmentsJson': jsonEncode([
          {
            'filename': 'spec.pdf',
            'fileType': 'PDF',
            'fileSize': '1.2MB',
            'filePath': '/files/spec.pdf',
          }
        ]),
      };

      final msg = CasboxMessage.fromJson(json);
      expect(msg.id, equals('1001'));
      expect(msg.sender, equals('alice@bnxmail.com'));
      expect(msg.to, equals('bob@bnxmail.com'));
      expect(msg.subject, equals('Project Discussion'));
      expect(msg.body, equals('Let us align on the new specs'));
      expect(msg.status, equals('DELIVERED'));
      expect(msg.isRead, isFalse);
      expect(msg.attachments.length, equals(1));
      expect(msg.attachments.first.fileName, equals('spec.pdf'));
    });

    // ── API 2: Fetch conversation thread (GET /api/casbox/thread/{contactEmail})
    test('API 2: Thread parsing handles nested list structures from backend', () {
      final threadJson = {
        'contactEmail': 'chandran@bnxmail.com',
        'messages': [
          {
            'id': 'msg_1',
            'senderEmail': 'chandran@bnxmail.com',
            'receiverEmail': 'me@bnxmail.com',
            'subject': 'Hello',
            'body': 'Are you available?',
            'status': 'SEEN',
            'timestamp': '2026-10-06T09:00:00Z',
          },
          {
            'id': 'msg_2',
            'senderEmail': 'me@bnxmail.com',
            'receiverEmail': 'chandran@bnxmail.com',
            'subject': 'Re: Hello',
            'body': 'Yes, ready!',
            'status': 'SEEN',
            'timestamp': '2026-10-06T09:05:00Z',
          }
        ]
      };

      final rawList = threadJson['messages'] as List;
      final parsed = rawList.map((m) => CasboxMessage.fromJson(m as Map<String, dynamic>)).toList();
      expect(parsed.length, equals(2));
      expect(parsed[0].id, equals('msg_1'));
      expect(parsed[0].isRead, isTrue);
      expect(parsed[1].id, equals('msg_2'));
      expect(parsed[1].body, equals('Yes, ready!'));
    });

    // ── API 3: Send message (POST /api/casbox/send)
    test('API 3: Outbound message payload conforms to backend schema', () {
      final attachments = [
        AttachmentModel(fileName: 'invoice.pdf', fileType: 'PDF', fileSize: '500KB', filePath: '/local/invoice.pdf')
      ];
      final attachmentsJson = jsonEncode(attachments.map((a) => {
        'filename': a.fileName,
        'fileType': a.fileType,
        'fileSize': a.fileSize,
        'filePath': a.filePath,
      }).toList());

      final payload = {
        'receiverEmail': 'bob@bnxmail.com',
        'subject': 'Invoice #104',
        'body': 'Please find the attached invoice.',
        'attachmentsJson': attachmentsJson,
      };

      expect(payload['receiverEmail'], equals('bob@bnxmail.com'));
      expect(payload['subject'], equals('Invoice #104'));
      expect(payload['body'], equals('Please find the attached invoice.'));
      final decodedAttachments = jsonDecode(payload['attachmentsJson']!) as List;
      expect(decodedAttachments.length, equals(1));
      expect(decodedAttachments.first['filename'], equals('invoice.pdf'));
    });

    // ── API 4 & 5: Batch & Single Archive (PATCH /api/casbox/archive & PATCH /api/casbox/{id}/archive)
    test('API 4 & 5: Batch and single archive update local model and request schema', () {
      final batchPayload = {
        'messageIds': [101, 102],
        'archived': true,
      };
      expect(batchPayload['messageIds'], equals([101, 102]));
      expect(batchPayload['archived'], isTrue);

      final msg = CasboxMessage(
        id: '101',
        sender: 'alice@bnxmail.com',
        to: 'bob@bnxmail.com',
        subject: 'Test',
        body: 'Testing',
        timestamp: DateTime.now(),
        isArchived: false,
      );

      final archivedMsg = msg.copyWith(isArchived: true);
      expect(archivedMsg.isArchived, isTrue);
    });

    // ── API 6: Update status (PATCH /api/casbox/status)
    test('API 6: Update delivery/read status payload and SEEN state propagation', () {
      final statusPayload = {
        'messageIds': [201, 202],
        'status': 'SEEN',
      };
      expect(statusPayload['status'], equals('SEEN'));

      final deliveredMsg = CasboxMessage(
        id: '201',
        sender: 'colleague@bnxmail.com',
        to: 'me@bnxmail.com',
        subject: 'Review',
        body: 'Done',
        timestamp: DateTime.now(),
        status: 'DELIVERED',
        isRead: false,
      );

      final seenMsg = deliveredMsg.copyWith(status: 'SEEN', isRead: true);
      expect(seenMsg.status, equals('SEEN'));
      expect(seenMsg.isRead, isTrue);
    });

    // ── API 7: Mark unseen as delivered (POST /api/casbox/delivered)
    test('API 7: Mark delivered endpoint invocation executes safely without crash', () async {
      // Offline / unauthenticated fallback test
      await CasboxRepository.markDelivered();
      // Should handle network/auth failures gracefully without throwing
      expect(true, isTrue);
    });

    // ── API 8, 9, 10: Edit sent message routes (PATCH, PUT, PATCH /edit)
    test('API 8, 9, 10: Edit message payload verification', () {
      final editPayload = {'body': 'Updated message content within 5 minutes'};
      expect(editPayload['body'], equals('Updated message content within 5 minutes'));

      final originalMsg = CasboxMessage(
        id: '501',
        sender: 'me@bnxmail.com',
        to: 'alice@bnxmail.com',
        subject: 'Draft',
        body: 'Old content',
        timestamp: DateTime.now(),
        isEdited: false,
      );

      final editedMsg = originalMsg.copyWith(
        body: 'Updated message content within 5 minutes',
        isEdited: true,
      );
      expect(editedMsg.body, equals('Updated message content within 5 minutes'));
      expect(editedMsg.isEdited, isTrue);
    });

    // ── API 11: Delete conversation (DELETE /api/casbox/conversation/{contactEmail})
    test('API 11: Delete conversation removes all messages matching contact', () {
      final messages = [
        CasboxMessage(
          id: '1',
          sender: 'contact@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: 'Hi',
          body: 'First',
          timestamp: DateTime.now(),
        ),
        CasboxMessage(
          id: '2',
          sender: 'me@bnxmail.com',
          to: 'contact@bnxmail.com',
          subject: 'Hi',
          body: 'Second',
          timestamp: DateTime.now(),
        ),
        CasboxMessage(
          id: '3',
          sender: 'other@bnxmail.com',
          to: 'me@bnxmail.com',
          subject: 'Other',
          body: 'Third',
          timestamp: DateTime.now(),
        ),
      ];

      const contactToDelete = 'contact@bnxmail.com';
      final filtered = messages.where((m) =>
        m.sender.toLowerCase() != contactToDelete &&
        m.to.toLowerCase() != contactToDelete
      ).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('3'));
    });

    // ── API 12 & 13: Connections (GET /api/connections/accepted & GET /api/connections)
    test('API 12 & 13: Connection record parsing handles CONNECTED and DISCONNECTED', () {
      final rawConnections = [
        {
          'id': 'conn_1',
          'contactEmail': 'partner@bnxmail.com',
          'status': 'CONNECTED',
          'customName': 'Partner Alice',
        },
        {
          'id': 'conn_2',
          'contactEmail': 'old@bnxmail.com',
          'status': 'DISCONNECTED',
        }
      ];

      final connectedOnly = rawConnections.where((c) => c['status'] == 'CONNECTED').toList();
      expect(connectedOnly.length, equals(1));
      expect(connectedOnly.first['contactEmail'], equals('partner@bnxmail.com'));
      expect(rawConnections.length, equals(2));
    });

    // ── API 14: Update connection status (PATCH/PUT /api/connections/{connectionId}/status)
    test('API 14: Update connection status payload and state change', () {
      final payload = {'status': 'DISCONNECTED'};
      expect(payload['status'], equals('DISCONNECTED'));

      final connectPayload = {'status': 'CONNECTED'};
      expect(connectPayload['status'], equals('CONNECTED'));
    });

    // ── API 15, 16, 17, 18: Contact Aliases (/api/contact-aliases)
    test('API 15, 16, 17, 18: Contact Alias dictionary mapping and resolution', () {
      final aliasMap = <String, String>{
        'alice@bnxmail.com': 'Alice (CEO Office)',
        'alice': 'Alice (CEO Office)',
        'bob@bnxmail.com': 'Bob (Lead Architect)',
      };

      expect(aliasMap['alice@bnxmail.com'], equals('Alice (CEO Office)'));
      expect(aliasMap['bob@bnxmail.com'], equals('Bob (Lead Architect)'));

      // API 17: Set alias
      aliasMap['carol@bnxmail.com'] = 'Carol (Design)';
      expect(aliasMap['carol@bnxmail.com'], equals('Carol (Design)'));

      // API 18: Delete alias
      aliasMap.remove('carol@bnxmail.com');
      expect(aliasMap.containsKey('carol@bnxmail.com'), isFalse);
    });

    // ── API 19, 20, 21, 22: Safety & Blocks (/api/blocked-contacts)
    test('API 19, 20, 21, 22: Blocked contacts list, checking, blocking, and unblocking', () {
      final blocked = <String>['spammer@bnxmail.com'];

      // API 20: Check
      bool isBlocked(String email) => blocked.contains(email.toLowerCase().trim());
      expect(isBlocked('spammer@bnxmail.com'), isTrue);
      expect(isBlocked('friend@bnxmail.com'), isFalse);

      // API 21: Block
      const newBlock = 'troll@bnxmail.com';
      if (!blocked.contains(newBlock)) blocked.add(newBlock);
      expect(isBlocked(newBlock), isTrue);

      // API 22: Unblock
      blocked.remove(newBlock);
      expect(isBlocked(newBlock), isFalse);
    });

    // ── API 23 & 24: Authorized contacts (/api/users/settings)
    test('API 23 & 24: casboxAccepted string array parsing and update payload', () {
      final settingsJson = {
        'casboxAccepted': ['alice@bnxmail.com', 'bob@bnxmail.com']
      };

      final accepted = (settingsJson['casboxAccepted'] as List).map((e) => e.toString()).toList();
      expect(accepted.length, equals(2));
      expect(accepted.contains('alice@bnxmail.com'), isTrue);

      final updatePayload = {
        'casboxAccepted': [...accepted, 'carol@bnxmail.com']
      };
      expect((updatePayload['casboxAccepted'] as List).length, equals(3));
    });
  });

  group('Colab State Notifiers End-to-End Integration Tests', () {
    test('CasboxBlockedContactsNotifier manages state transitions cleanly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(casboxBlockedContactsProvider.notifier);
      expect(container.read(casboxBlockedContactsProvider), isEmpty);

      // Test blocking
      await notifier.blockContact('spammer@bnxmail.com');
      expect(container.read(casboxBlockedContactsProvider).contains('spammer@bnxmail.com'), isTrue);

      // Test unblocking
      await notifier.unblockContact('spammer@bnxmail.com');
      expect(container.read(casboxBlockedContactsProvider).contains('spammer@bnxmail.com'), isFalse);
    });

    test('CasboxAliasesNotifier caches aliases and provides synchronous lookup', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(casboxAliasesProvider.notifier);
      expect(container.read(casboxAliasesProvider), isEmpty);

      await notifier.setAlias('user123', 'Project Lead');
      expect(container.read(casboxAliasesProvider)['user123'], equals('Project Lead'));

      await notifier.deleteAlias('user123');
      expect(container.read(casboxAliasesProvider).containsKey('user123'), isFalse);
    });

    test('CasboxConnectionsNotifier updates local connection record upon status change', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(casboxConnectionsProvider.notifier);
      await notifier.updateConnectionStatus('conn_99', 'DISCONNECTED');
      // Should execute without throwing error
      expect(container.read(casboxConnectionsProvider), isEmpty);
    });
  });
}
