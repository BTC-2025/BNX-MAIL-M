import '../../core/network/api_client.dart';
import '../../models/blocked_contact_model.dart';

/// Isolated repository for the BNXMail Subscription & Blocked Contacts APIs.
class SubscriptionRepository {
  /// Fetches the list of blocked/unsubscribed contacts for the active account.
  /// GET /api/blocked-contacts
  static Future<List<BlockedContact>> getBlockedContacts() async {
    final res = await ApiClient.get('/api/blocked-contacts');
    final rawList = res['data'];

    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((json) => BlockedContact.fromJson(json))
          .toList();
    }
    return [];
  }

  /// Blocks a sender / marks them as unsubscribed.
  /// POST /api/blocked-contacts
  /// Body: {"email": "..."}
  static Future<void> unsubscribe(String email) async {
    await ApiClient.post(
      '/api/blocked-contacts',
      body: {'email': email.trim()},
    );
  }

  /// Unblocks a sender / resubscribes to them.
  /// DELETE /api/blocked-contacts/{email}
  static Future<void> subscribe(String email) async {
    final encodedEmail = Uri.encodeComponent(email.trim());
    await ApiClient.delete('/api/blocked-contacts/$encodedEmail');
  }

  /// Checks the blocked status of an individual contact (optional helper).
  /// GET /api/blocked-contacts/check?email=...
  static Future<bool> checkStatus(String email) async {
    final res = await ApiClient.get(
      '/api/blocked-contacts/check',
      queryParams: {'email': email.trim()},
    );
    final data = res['data'];
    if (data is Map<String, dynamic>) {
      return data['blocked'] == true || data['isBlocked'] == true;
    }
    if (data is bool) return data;
    return res['blocked'] == true || res['isBlocked'] == true;
  }
}
