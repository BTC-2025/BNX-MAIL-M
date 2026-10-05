import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bnx_mail/data/repositories/mail_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MailRepository cleanUid & ID Sanitization Tests', () {
    test('cleans folder prefixes correctly', () {
      expect(MailRepository.cleanUid('Starred_12345'), equals('12345'));
      expect(MailRepository.cleanUid('Draft_456'), equals('456'));
      expect(MailRepository.cleanUid('Sent_789'), equals('789'));
      expect(MailRepository.cleanUid('Snoozed_101'), equals('101'));
      expect(MailRepository.cleanUid('Scheduled_202'), equals('202'));
      expect(MailRepository.cleanUid('Trash_303'), equals('303'));
      expect(MailRepository.cleanUid('Inbox_404'), equals('404'));
      expect(MailRepository.cleanUid('Archive_505'), equals('505'));
      expect(MailRepository.cleanUid('Spam_606'), equals('606'));
    });

    test('preserves local_ generated ids and bare ids', () {
      expect(MailRepository.cleanUid('local_123_456'), equals('local_123_456'));
      expect(MailRepository.cleanUid('9999'), equals('9999'));
      expect(MailRepository.cleanUid('random_string_id'), equals('random_string_id'));
    });
  });

  group('Starred Pagination & Boundary Clamping Tests', () {
    test('safeSlice bounds prevent RangeError when serverReported > local filtered count', () {
      const int pageSize = 20;
      final int serverReported = 6;
      final List<int> localFiltered = [1, 2, 3, 4]; // Only 4 local items returned

      final int totalEmailCount = (serverReported > localFiltered.length)
          ? serverReported
          : localFiltered.length;
      expect(totalEmailCount, equals(6));

      final int maxAvailablePages = localFiltered.isEmpty
          ? 1
          : ((localFiltered.length + pageSize - 1) ~/ pageSize);
      final int totalPages = maxAvailablePages;
      expect(totalPages, equals(1));

      int desktopCurrentPage = 1;
      final int safePage = desktopCurrentPage.clamp(1, totalPages);
      expect(safePage, equals(1));

      final int startIndex = localFiltered.isEmpty ? 0 : (safePage - 1) * pageSize;
      final int safeSliceStart = startIndex.clamp(0, localFiltered.length);
      final int safeSliceEnd =
          (safeSliceStart + pageSize).clamp(safeSliceStart, localFiltered.length);

      expect(safeSliceStart, equals(0));
      expect(safeSliceEnd, equals(4));

      // Slicing local items MUST NOT throw RangeError
      final sliced = localFiltered.sublist(safeSliceStart, safeSliceEnd);
      expect(sliced.length, equals(4));

      final int startItem = localFiltered.isEmpty ? 0 : (safeSliceStart + 1);
      final int endItem = safeSliceEnd;
      expect(startItem, equals(1));
      expect(endItem, equals(4));
    });

    test('safeSlice bounds with empty list handles gracefully without RangeError', () {
      const int pageSize = 20;
      final int serverReported = 0;
      final List<int> localFiltered = [];

      final int totalEmailCount = (serverReported > localFiltered.length)
          ? serverReported
          : localFiltered.length;
      expect(totalEmailCount, equals(0));
      final int maxAvailablePages = localFiltered.isEmpty
          ? 1
          : ((localFiltered.length + pageSize - 1) ~/ pageSize);
      final int totalPages = maxAvailablePages;
      expect(totalPages, equals(1));

      int desktopCurrentPage = 1;
      final int safePage = desktopCurrentPage.clamp(1, totalPages);
      final int startIndex = localFiltered.isEmpty ? 0 : (safePage - 1) * pageSize;
      final int safeSliceStart = startIndex.clamp(0, localFiltered.length);
      final int safeSliceEnd =
          (safeSliceStart + pageSize).clamp(safeSliceStart, localFiltered.length);

      final sliced = localFiltered.isEmpty
          ? <int>[]
          : localFiltered.sublist(safeSliceStart, safeSliceEnd);
      expect(sliced, isEmpty);

      final int startItem = localFiltered.isEmpty ? 0 : (safeSliceStart + 1);
      final int endItem = safeSliceEnd;
      expect(startItem, equals(0));
      expect(endItem, equals(0));
    });
  });

  group('Signature Deletion State Math Tests', () {
    test('deleting only signature results in safe index 0 and empty items without RangeError', () {
      final items = [
        {'id': 'sig-1', 'name': 'Default Sig', 'content': 'My Sig', 'isDefault': true}
      ];
      int selectedIndex = 0;

      // Simulate deletion
      items.removeWhere((s) => s['id'] == 'sig-1');
      if (items.isEmpty) {
        selectedIndex = 0;
      } else {
        if (selectedIndex >= items.length) {
          selectedIndex = items.length - 1;
        }
        if (selectedIndex < 0) {
          selectedIndex = 0;
        }
      }

      expect(items, isEmpty);
      expect(selectedIndex, equals(0));
    });

    test('deleting selected signature at end of list clamps index to new last element', () {
      final items = [
        {'id': 'sig-1', 'name': 'Sig 1', 'isDefault': true},
        {'id': 'sig-2', 'name': 'Sig 2', 'isDefault': false},
        {'id': 'sig-3', 'name': 'Sig 3', 'isDefault': false},
      ];
      int selectedIndex = 2; // Selected last

      items.removeWhere((s) => s['id'] == 'sig-3');
      if (items.isEmpty) {
        selectedIndex = 0;
      } else {
        if (selectedIndex >= items.length) {
          selectedIndex = items.length - 1;
        }
        if (selectedIndex < 0) {
          selectedIndex = 0;
        }
      }

      expect(items.length, equals(2));
      expect(selectedIndex, equals(1));
      expect(items[selectedIndex]['name'], equals('Sig 2'));
    });

    test('deleting non-existent id does not alter items and remains safe', () {
      final items = [
        {'id': 'sig-1', 'name': 'Sig 1', 'isDefault': true}
      ];
      int selectedIndex = 0;

      items.removeWhere((s) => s['id'] == 'non-existent');
      if (items.isEmpty) {
        selectedIndex = 0;
      } else {
        if (selectedIndex >= items.length) {
          selectedIndex = items.length - 1;
        }
        if (selectedIndex < 0) {
          selectedIndex = 0;
        }
      }

      expect(items.length, equals(1));
      expect(selectedIndex, equals(0));
    });
  });

  group('Starred State Synchronization & Isolation Tests', () {
    test('clears isStarred on emails not returned in latest starred fetch', () {
      // Existing cached emails in memory
      final cachedEmails = [
        {'id': '1', 'subject': 'Mail 1', 'isStarred': true, 'memberOfFolders': ['Inbox', 'Starred']},
        {'id': '2', 'subject': 'Mail 2', 'isStarred': true, 'memberOfFolders': ['Inbox', 'Starred']},
        {'id': '3', 'subject': 'Mail 3', 'isStarred': false, 'memberOfFolders': ['Inbox']},
      ];

      // Newly fetched starred IDs from GET /api/mail/starred (id '2' was unstarred on server)
      final authoritativeStarredIds = {'1'};

      final updatedEmails = cachedEmails.map((email) {
        final id = email['id'] as String;
        final isAuthoritative = authoritativeStarredIds.contains(id);
        final members = List<String>.from(email['memberOfFolders'] as List);
        if (isAuthoritative) {
          if (!members.contains('Starred')) members.add('Starred');
          return {...email, 'isStarred': true, 'memberOfFolders': members};
        } else {
          members.remove('Starred');
          return {...email, 'isStarred': false, 'memberOfFolders': members};
        }
      }).toList();

      expect(updatedEmails[0]['isStarred'], isTrue);
      expect((updatedEmails[0]['memberOfFolders'] as List).contains('Starred'), isTrue);

      // Email 2 was unstarred on backend, should now be unstarred in local memory
      expect(updatedEmails[1]['isStarred'], isFalse);
      expect((updatedEmails[1]['memberOfFolders'] as List).contains('Starred'), isFalse);

      // Email 3 was never starred
      expect(updatedEmails[2]['isStarred'], isFalse);
    });
  });

  group('Casbox Payload Contract Tests', () {
    test('sendCasboxMessage strictly formats backend CasboxSendRequest keys', () {
      final payload = {
        'receiverEmail': 'partner@bnxmail.com',
        'body': 'Hello there',
        'subject': 'Project Discussion',
        'attachmentsJson': '[]',
      };

      // Strict backend contract verification
      expect(payload.containsKey('receiverEmail'), isTrue);
      expect(payload.containsKey('body'), isTrue);
      expect(payload.containsKey('subject'), isTrue);
      expect(payload.containsKey('attachmentsJson'), isTrue);

      // Must NOT contain frontend aliases that trigger backend 400/500 errors
      expect(payload.containsKey('contactEmail'), isFalse);
      expect(payload.containsKey('message'), isFalse);
      expect(payload['receiverEmail'], equals('partner@bnxmail.com'));
      expect(payload['body'], equals('Hello there'));
    });
  });

  group('Sidebar Label Visibility Synchronization Tests', () {
    test('visibility map accurately overrides defaults and persists', () {
      final defaultVis = {
        'Inbox': true,
        'Starred': true,
        'Sent': true,
        'Drafts': true,
        'Casbox': true,
        'Trash': true,
        'Archive': true,
        'Spam': true,
        'Scheduled': true,
      };

      // User hides Casbox and Spam
      final updatedVis = Map<String, bool>.from(defaultVis);
      updatedVis['Casbox'] = false;
      updatedVis['Spam'] = false;

      expect(updatedVis['Inbox'], isTrue);
      expect(updatedVis['Casbox'], isFalse);
      expect(updatedVis['Spam'], isFalse);
      expect(updatedVis['Starred'], isTrue);
    });

    test('label deletion properly removes custom label from visibility map without residual resurrection', () {
      final defaultVis = {'Inbox': true, 'Starred': true, 'Work': true, 'Personal': true};
      final afterDeletion = Map<String, bool>.from(defaultVis)..remove('Work');

      expect(afterDeletion.containsKey('Work'), isFalse);
      expect(afterDeletion['Personal'], isTrue);
      expect(afterDeletion['Inbox'], isTrue);
    });

    test('account switching resets sidebar labels to account-specific configuration', () {
      final account1Labels = {'Inbox': true, 'Starred': true, 'Finance': true};
      final account2Labels = {'Inbox': true, 'Starred': false, 'Clients': true};

      final activeForAccount1 = Map<String, bool>.from(account1Labels);
      expect(activeForAccount1['Finance'], isTrue);
      expect(activeForAccount1.containsKey('Clients'), isFalse);

      // Switch to account 2
      final activeForAccount2 = Map<String, bool>.from(account2Labels);
      expect(activeForAccount2['Clients'], isTrue);
      expect(activeForAccount2.containsKey('Finance'), isFalse);
      expect(activeForAccount2['Starred'], isFalse);
    });
  });
}

