import '../../core/network/api_client.dart';
import '../../models/signature_model.dart';
import '../../models/two_factor_model.dart';
import '../../models/user_settings_model.dart';

/// Repository for BNXmail Settings backend integration.
/// Implements all documented endpoints from Section 4 of API specifications.
class SettingsRepository {
  // ── 1. Full Settings ────────────────────────────────────────────────────────

  /// GET /api/users/settings
  static Future<UserSettings> getSettings() async {
    print('[SETTINGS] GET /api/users/settings');
    final res = await ApiClient.get('/api/users/settings');
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return UserSettings.fromJson(data);
  }

  /// PATCH /api/users/settings
  /// Supports partial updates. Only sends specified keys.
  static Future<UserSettings> updateSettings(
    Map<String, dynamic> partialUpdates,
  ) async {
    print('[SETTINGS] PATCH /api/users/settings');
    final res = await ApiClient.patch(
      '/api/users/settings',
      body: partialUpdates,
    );
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return UserSettings.fromJson(data);
  }

  // ── 2. Language ─────────────────────────────────────────────────────────────

  /// GET /api/settings/language
  static Future<String> getLanguage() async {
    print('[SETTINGS] GET /api/settings/language');
    final res = await ApiClient.get('/api/settings/language');
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return data['language']?.toString() ?? 'en';
  }

  /// PUT /api/settings/language
  static Future<void> updateLanguage(String languageCode) async {
    print('[SETTINGS] PUT /api/settings/language');
    await ApiClient.put(
      '/api/settings/language',
      body: {'language': languageCode},
    );
  }

  // ── 3. Composing & Smart AI ────────────────────────────────────────────────

  /// GET /api/settings/composing
  static Future<Map<String, bool>> getComposing() async {
    print('[SETTINGS] GET /api/settings/composing');
    final res = await ApiClient.get('/api/settings/composing');
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return {
      'spellingCheckEnabled': data['spellingCheckEnabled'] != false,
      'grammarCheckEnabled': data['grammarCheckEnabled'] != false,
      'autoCorrectEnabled': data['autoCorrectEnabled'] != false,
      'smartComposeEnabled': data['smartComposeEnabled'] != false,
    };
  }

  /// PUT /api/settings/composing
  static Future<void> updateComposing({
    required bool spellingCheckEnabled,
    required bool grammarCheckEnabled,
    required bool autoCorrectEnabled,
    required bool smartComposeEnabled,
  }) async {
    print('[SETTINGS] PUT /api/settings/composing');
    await ApiClient.put(
      '/api/settings/composing',
      body: {
        'spellingCheckEnabled': spellingCheckEnabled,
        'grammarCheckEnabled': grammarCheckEnabled,
        'autoCorrectEnabled': autoCorrectEnabled,
        'smartComposeEnabled': smartComposeEnabled,
      },
    );
  }

  // ── 4. Typography / Text Style ──────────────────────────────────────────────

  /// GET /api/settings/text-style
  static Future<Map<String, String>> getTextStyle() async {
    print('[SETTINGS] GET /api/settings/text-style');
    final res = await ApiClient.get('/api/settings/text-style');
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return {
      'fontFamily': data['fontFamily']?.toString() ?? 'Arial',
      'fontSize': data['fontSize']?.toString() ?? 'Normal',
      'textColor': data['textColor']?.toString() ?? '#000000',
    };
  }

  /// PUT /api/settings/text-style
  static Future<void> updateTextStyle({
    required String fontFamily,
    required String fontSize,
    String textColor = '#000000',
  }) async {
    print('[SETTINGS] PUT /api/settings/text-style');
    await ApiClient.put(
      '/api/settings/text-style',
      body: {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'textColor': textColor,
      },
    );
  }

  // ── 5. Wallpaper & Theme Customization ─────────────────────────────────────

  /// GET /api/settings/wallpaper
  static Future<String?> getWallpaper() async {
    print('[SETTINGS] GET /api/settings/wallpaper');
    final res = await ApiClient.get('/api/settings/wallpaper');
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return data['wallpaper']?.toString();
  }

  /// PUT /api/settings/wallpaper
  static Future<void> updateWallpaper(String wallpaper) async {
    print('[SETTINGS] PUT /api/settings/wallpaper');
    await ApiClient.put(
      '/api/settings/wallpaper',
      body: {'wallpaper': wallpaper},
    );
  }

  /// POST/PUT /api/settings/wallpaper/reset
  static Future<void> resetWallpaper() async {
    print('[SETTINGS] POST /api/settings/wallpaper/reset');
    try {
      await ApiClient.post('/api/settings/wallpaper/reset');
    } catch (_) {
      print('[SETTINGS] PUT /api/settings/wallpaper/reset');
      await ApiClient.put('/api/settings/wallpaper/reset');
    }
  }

  // ── 6. Signatures ──────────────────────────────────────────────────────────

  /// GET /api/signatures
  static Future<List<SignatureModel>> getSignatures() async {
    print('[SETTINGS] GET /api/signatures');
    final res = await ApiClient.get('/api/signatures');
    final rawList = res['data'] ?? res['signatures'] ?? res;
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((m) => SignatureModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  /// POST /api/signatures
  static Future<SignatureModel> createSignature({
    required String name,
    required String content,
    bool isDefault = false,
  }) async {
    print('[SETTINGS] POST /api/signatures');
    final res = await ApiClient.post(
      '/api/signatures',
      body: {
        'name': name,
        'content': content,
        'isDefault': isDefault,
      },
    );
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return SignatureModel.fromJson(data);
  }

  /// PUT /api/signatures/{id}
  static Future<SignatureModel> updateSignature({
    required String id,
    required String name,
    required String content,
    bool isDefault = false,
  }) async {
    print('[SETTINGS] PUT /api/signatures/$id');
    final res = await ApiClient.put(
      '/api/signatures/$id',
      body: {
        'name': name,
        'content': content,
        'isDefault': isDefault,
      },
    );
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return SignatureModel.fromJson(data);
  }

  /// DELETE /api/signatures/{id}
  static Future<void> deleteSignature(String id) async {
    print('[SETTINGS] DELETE /api/signatures/$id');
    await ApiClient.delete('/api/signatures/$id');
  }

  /// PATCH /api/signatures/{id}/default
  static Future<void> setDefaultSignature(String id) async {
    print('[SETTINGS] PATCH /api/signatures/$id/default');
    await ApiClient.patch('/api/signatures/$id/default');
  }

  // ── 7. Two-Factor Authentication (2FA) ─────────────────────────────────────

  /// POST /api/users/2fa/setup
  static Future<TwoFactorSetupData> setup2FA() async {
    print('[SETTINGS] POST /api/users/2fa/setup');
    final res = await ApiClient.post('/api/users/2fa/setup');
    final data = res['data'] as Map<String, dynamic>? ?? res;
    return TwoFactorSetupData.fromJson(data);
  }

  /// POST /api/users/2fa/verify
  static Future<bool> verify2FA(String code) async {
    print('[SETTINGS] POST /api/users/2fa/verify');
    final res = await ApiClient.post(
      '/api/users/2fa/verify',
      body: {'code': code.trim()},
    );
    final success = res['success'] == true ||
        res['verified'] == true ||
        res['status'] == 'success' ||
        res['data']?['twoFactorEnabled'] == true;
    return success;
  }
}
