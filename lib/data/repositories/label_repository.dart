import '../../core/network/api_client.dart';
import '../../core/network/token_service.dart';
import '../../models/label_model.dart';
import '../../models/email_model.dart';

/// Handles all label- and category-related API calls.
class LabelRepository {
  static Future<List<LabelModel>> fetchLabels() async {
    try {
      final email = await TokenService.getUserEmail();
      final query = email != null && email.isNotEmpty ? '?userEmail=${Uri.encodeComponent(email)}' : '';
      final res = await ApiClient.get('/api/mail/labels$query');
      final raw = res['data'] ?? res['labels'] ?? res;
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((j) => LabelModel.fromJson(j))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<LabelModel?> createLabel(String name, String colorHex) async {
    try {
      final email = await TokenService.getUserEmail();
      final query = email != null && email.isNotEmpty ? '?userEmail=${Uri.encodeComponent(email)}' : '';
      final res = await ApiClient.post(
        '/api/mail/labels$query',
        body: {
          'name': name,
          'color': colorHex,
          'colorHex': colorHex,
          'color_hex': colorHex,
        },
      );
      final data = res['data'] as Map<String, dynamic>? ?? res;
      if (data.isEmpty) return null;
      return LabelModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteLabel(String id) async {
    try {
      final email = await TokenService.getUserEmail();
      final query = email != null && email.isNotEmpty ? '?userEmail=${Uri.encodeComponent(email)}' : '';
      await ApiClient.delete('/api/mail/labels/$id$query');
    } catch (_) {}
  }

  static Future<LabelModel?> updateLabel(
    String id,
    String name,
    String colorHex,
  ) async {
    try {
      final email = await TokenService.getUserEmail();
      final query = email != null && email.isNotEmpty ? '?userEmail=${Uri.encodeComponent(email)}' : '';
      final res = await ApiClient.put(
        '/api/mail/labels/$id$query',
        body: {
          'name': name,
          'color': colorHex,
          'colorHex': colorHex,
          'color_hex': colorHex,
        },
      );
      final data = res['data'] as Map<String, dynamic>? ?? res;
      if (data.isEmpty) return null;
      return LabelModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> applyLabel(
    String uid,
    String labelId, {
    String folder = 'Inbox',
  }) async {
    try {
      final email = await TokenService.getUserEmail();
      final userQuery = email != null && email.isNotEmpty ? '&userEmail=${Uri.encodeComponent(email)}' : '';
      final queryFolder = Uri.encodeComponent(folder);
      final queryLabel = Uri.encodeComponent(labelId);
      await ApiClient.post(
        '/api/mail/labels/apply/$uid?labelId=$queryLabel&folder=$queryFolder$userQuery',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> removeLabel(
    String uid,
    String labelId, {
    String folder = 'Inbox',
  }) async {
    try {
      final email = await TokenService.getUserEmail();
      final userQuery = email != null && email.isNotEmpty ? '&userEmail=${Uri.encodeComponent(email)}' : '';
      final queryFolder = Uri.encodeComponent(folder);
      final queryLabel = Uri.encodeComponent(labelId);
      await ApiClient.delete(
        '/api/mail/labels/remove/$uid?labelId=$queryLabel&folder=$queryFolder$userQuery',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<EmailModel>> fetchCategory(String category) async {
    try {
      final res = await ApiClient.get('/api/mail/category/$category');
      final raw = res['data'] ?? res['emails'] ?? res;
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((j) => EmailModel.fromJson(j))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
