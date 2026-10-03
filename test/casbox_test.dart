import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bnx_mail/data/colab_provider.dart';
import 'package:flutter_bnx_mail/models/email_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CasboxMessage Model & JSON Deserialization', () {
    test('parses CasboxMessageDto with attachmentsJson string', () {
      final jsonDto = {
        'id': 42,
        'senderEmail': 'alice@bnxmail.com',
        'receiverEmail': 'bob@bnxmail.com',
        'subject': 'Project Roadmap',
        'body': 'Here is the roadmap document.',
        'timestamp': '2026-10-03T09:30:00.000Z',
        'attachmentsJson': jsonEncode([
          {
            'filename': 'roadmap.pdf',
            'fileType': 'PDF',
            'fileSize': '2.4MB',
            'filePath': '/uploads/roadmap.pdf',
          }
        ]),
        'status': 'DELIVERED',
      };

      final msg = CasboxMessage.fromJson(jsonDto);

      expect(msg.id, equals('42'));
      expect(msg.sender, equals('alice@bnxmail.com'));
      expect(msg.to, equals('bob@bnxmail.com'));
      expect(msg.subject, equals('Project Roadmap'));
      expect(msg.body, equals('Here is the roadmap document.'));
      expect(msg.status, equals('DELIVERED'));
      expect(msg.isRead, isFalse);
      expect(msg.attachments.length, equals(1));
      expect(msg.attachments.first.fileName, equals('roadmap.pdf'));
      expect(msg.attachments.first.fileType, equals('PDF'));
      expect(msg.attachments.first.fileSize, equals('2.4MB'));
    });

    test('marks message as isRead when status is SEEN or READ', () {
      final seenJson = {
        'id': '101',
        'senderEmail': 'colleague@bnxmail.com',
        'receiverEmail': 'bob@bnxmail.com',
        'body': 'I read this already',
        'status': 'SEEN',
      };

      final readJson = {
        'id': '102',
        'senderEmail': 'colleague@bnxmail.com',
        'receiverEmail': 'bob@bnxmail.com',
        'body': 'I also read this',
        'status': 'READ',
      };

      final seenMsg = CasboxMessage.fromJson(seenJson);
      final readMsg = CasboxMessage.fromJson(readJson);

      expect(seenMsg.isRead, isTrue);
      expect(readMsg.isRead, isTrue);
    });

    test('parses raw attachments array fallback when attachmentsJson is omitted', () {
      final jsonWithList = {
        'id': '103',
        'sender': 'carol@bnxmail.com',
        'to': 'bob@bnxmail.com',
        'body': 'Check these pictures',
        'status': 'SENT',
        'attachments': [
          {
            'fileName': 'diagram.png',
            'fileType': 'IMG',
            'fileSize': '500KB',
          }
        ],
      };

      final msg = CasboxMessage.fromJson(jsonWithList);

      expect(msg.attachments.length, equals(1));
      expect(msg.attachments.first.fileName, equals('diagram.png'));
      expect(msg.status, equals('SENT'));
    });

    test('converts from EmailModel to CasboxMessage seamlessly', () {
      final email = EmailModel(
        id: 'email_999',
        senderName: 'BNX System',
        senderEmail: 'system@bnxmail.com',
        recipient: 'user@bnxmail.com',
        subject: 'Welcome to Casbox',
        body: 'Welcome to your real-time Casbox messaging experience!',
        date: DateTime.utc(2026, 10, 3, 12, 0),
        isStarred: true,
        isRead: false,
        labels: ['Casbox'],
      );

      final msg = CasboxMessage.fromEmailModel(email);

      expect(msg.id, equals('email_999'));
      expect(msg.sender, equals('system@bnxmail.com'));
      expect(msg.to, equals('user@bnxmail.com'));
      expect(msg.subject, equals('Welcome to Casbox'));
      expect(msg.isStarred, isTrue);
      expect(msg.isRead, isFalse);
    });
  });

  group('Tab Classification & Status Rules', () {
    test('separates Requests from accepted Messages cleanly', () {
      final pendingMsg = CasboxMessage(
        id: 'req_1',
        sender: 'stranger@bnxmail.com',
        to: 'me@bnxmail.com',
        subject: 'Connect?',
        body: 'Can we chat?',
        timestamp: DateTime.now(),
        status: 'PENDING',
      );

      final acceptedDeliveredMsg = CasboxMessage(
        id: 'msg_2',
        sender: 'friend@bnxmail.com',
        to: 'me@bnxmail.com',
        subject: 'Hello',
        body: 'Meeting at 3',
        timestamp: DateTime.now(),
        status: 'DELIVERED',
      );

      final acceptedSeenMsg = CasboxMessage(
        id: 'msg_3',
        sender: 'friend@bnxmail.com',
        to: 'me@bnxmail.com',
        subject: 'Re: Hello',
        body: 'See you there',
        timestamp: DateTime.now(),
        status: 'SEEN',
      );

      // Requests filter: !isSentByMe && (status == 'PENDING' || status == 'REQUEST')
      bool isRequest(CasboxMessage m) {
        final s = m.status.toUpperCase();
        return s == 'PENDING' || s == 'REQUEST';
      }

      // Received / Messages filter: status != 'PENDING' && status != 'REQUEST'
      bool isReceived(CasboxMessage m) {
        final s = m.status.toUpperCase();
        return s != 'PENDING' && s != 'REQUEST';
      }

      expect(isRequest(pendingMsg), isTrue);
      expect(isReceived(pendingMsg), isFalse);

      expect(isRequest(acceptedDeliveredMsg), isFalse);
      expect(isReceived(acceptedDeliveredMsg), isTrue);

      expect(isRequest(acceptedSeenMsg), isFalse);
      expect(isReceived(acceptedSeenMsg), isTrue);
    });
  });
}
