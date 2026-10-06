import 'dart:convert';
import 'package:http/http.dart' as http;
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
  /// POST /api/mail/unsubscribe?senderEmail=... (with fallback to POST /api/blocked-contacts)
  static Future<void> unsubscribe(String email) async {
    final cleanEmail = email.trim();
    try {
      await ApiClient.post(
        '/api/mail/unsubscribe',
        queryParams: {'senderEmail': cleanEmail},
      );
    } catch (_) {
      await ApiClient.post(
        '/api/blocked-contacts',
        body: {'email': cleanEmail},
      );
    }
  }

  /// Unblocks a sender / resubscribes to them.
  /// POST /api/mail/subscribe?senderEmail=... (with fallback to DELETE /api/blocked-contacts/{email})
  static Future<void> subscribe(String email) async {
    final cleanEmail = email.trim();
    try {
      await ApiClient.post(
        '/api/mail/subscribe',
        queryParams: {'senderEmail': cleanEmail},
      );
    } catch (_) {
      final encodedEmail = Uri.encodeComponent(cleanEmail);
      await ApiClient.delete('/api/blocked-contacts/$encodedEmail');
    }
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

  /// 6.1 Get Active Subscription (External API)
  /// GET https://cliks.beta-softnet.com/api/v1/business/subscription/{userEmail}
  static Future<Map<String, dynamic>?> getBusinessSubscription(String userEmail) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    try {
      final uri = Uri.parse('https://cliks.beta-softnet.com/api/v1/business/subscription/$cleanEmail');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(decoded['data'])
              : decoded;
        }
      }
    } catch (e) {
      print('[BUSINESS SUBSCRIPTION API ERROR] $e');
    }
    return null;
  }
}
