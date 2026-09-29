import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure wrapper around [FlutterSecureStorage] for JWT token persistence.
/// Tokens survive app restarts and cannot be read by other apps on device.
/// Includes an in-memory and local disk fallback for desktop/macOS platforms
/// where macOS Keychain entitlements (-34018) prevent access in development builds.
class TokenService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  static const _kAccess = 'bnx_access_token';
  static const _kRefresh = 'bnx_refresh_token';
  static const _kEmail = 'bnx_user_email';
  static const _kName = 'bnx_user_name';

  static String? cachedAccessToken;

  // On desktop platforms (macOS/Linux/Windows) or Web, use resilient local disk storage
  // directly to avoid Keychain OSStatus error 13 / -34018 entitlement blockers.
  // Mobile platforms (Android/iOS) continue to use native FlutterSecureStorage.
  static bool get _useFallbackDirectly =>
      kIsWeb || (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  // ── Resilient Fallback Storage ───────────────────────────────────────────
  static final Map<String, String> _memoryFallback = {};
  static bool _fallbackLoaded = false;

  static File? _resolveFallbackFile() {
    try {
      if (kIsWeb) return null;
      Directory? baseDir;
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          baseDir = Directory('$home/Library/Application Support/com.bnxmail.app');
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          baseDir = Directory('$home/.config/com.bnxmail.app');
        }
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          baseDir = Directory('$appData/com.bnxmail.app');
        }
      }
      baseDir ??= Directory('${Directory.systemTemp.path}/com.bnxmail.app');
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }
      return File('${baseDir.path}/.bnx_local_store.json');
    } catch (_) {
      return null;
    }
  }

  static void _ensureFallbackLoaded() {
    if (_fallbackLoaded) return;
    _fallbackLoaded = true;
    try {
      final file = _resolveFallbackFile();
      if (file != null && file.existsSync()) {
        final content = file.readAsStringSync();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (k != null && v != null) {
                _memoryFallback[k.toString()] = v.toString();
              }
            });
          }
        }
      }
    } catch (e) {
      print('[TOKEN SERVICE] Fallback storage read error: $e');
    }
  }

  static void _persistFallback() {
    try {
      final file = _resolveFallbackFile();
      if (file != null) {
        file.writeAsStringSync(jsonEncode(_memoryFallback));
      }
    } catch (e) {
      print('[TOKEN SERVICE] Fallback storage persist error: $e');
    }
  }

  static Future<void> _safeWrite({required String key, required String value}) async {
    _ensureFallbackLoaded();
    _memoryFallback[key] = value;
    _persistFallback();

    if (!_useFallbackDirectly) {
      try {
        await _storage.write(key: key, value: value);
      } catch (e) {
        print('[TOKEN SERVICE] Secure storage write warning for key "$key" ($e). Using local fallback store.');
      }
    }
  }

  static Future<String?> _safeRead({required String key}) async {
    _ensureFallbackLoaded();

    if (!_useFallbackDirectly) {
      try {
        final val = await _storage.read(key: key);
        if (val != null) {
          _memoryFallback[key] = val;
          return val;
        }
      } catch (e) {
        print('[TOKEN SERVICE] Secure storage read warning for key "$key" ($e). Reading from fallback store.');
      }
    }

    return _memoryFallback[key];
  }

  static Future<void> _safeDelete({required String key}) async {
    _ensureFallbackLoaded();
    _memoryFallback.remove(key);
    _persistFallback();

    if (!_useFallbackDirectly) {
      try {
        await _storage.delete(key: key);
      } catch (e) {
        print('[TOKEN SERVICE] Secure storage delete warning for key "$key" ($e).');
      }
    }
  }

  static Future<void> _safeDeleteAll() async {
    _ensureFallbackLoaded();
    _memoryFallback.clear();
    _persistFallback();

    if (!_useFallbackDirectly) {
      try {
        await _storage.deleteAll();
      } catch (e) {
        print('[TOKEN SERVICE] Secure storage deleteAll warning ($e).');
      }
    }
  }

  // ── Write ────────────────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    cachedAccessToken = accessToken;
    await _safeWrite(key: _kAccess, value: accessToken);
    await _safeWrite(key: _kRefresh, value: refreshToken);
  }

  static Future<void> clearTokens() async {
    cachedAccessToken = null;
    await _safeDelete(key: _kAccess);
    await _safeDelete(key: _kRefresh);
    await _safeDelete(key: _kEmail);
    await _safeDelete(key: _kName);
  }

  static Future<void> saveUserInfo({
    required String email,
    required String name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    await _safeWrite(key: _kEmail, value: cleanEmail);
    await _safeWrite(key: _kName, value: name);
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty && cleanEmail.isNotEmpty) {
      await saveAccountToRegistry(
        email: cleanEmail,
        name: name,
        accessToken: token,
      );
    }
  }

  // ── Multi-Account Registry ───────────────────────────────────────────────
  static const _kSavedAccountsRegistry = 'bnx_saved_accounts_registry';

  /// Save account credentials to multi-account registry
  static Future<void> saveAccountToRegistry({
    required String email,
    required String name,
    required String accessToken,
    String? refreshToken,
    String? avatarUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    final existing = await getSavedAccountsFromRegistry();
    final updated = existing.where((a) => a['email']?.toString().trim().toLowerCase() != cleanEmail).toList();

    updated.add({
      'email': cleanEmail,
      'name': name.isNotEmpty ? name : cleanEmail.split('@').first,
      'accessToken': accessToken,
      'refreshToken': refreshToken ?? '',
      'avatarUrl': avatarUrl ?? '',
    });

    await _safeWrite(key: _kSavedAccountsRegistry, value: jsonEncode(updated));
    print('[TOKEN SERVICE] Account $cleanEmail saved to registry. Total accounts: ${updated.length}');
  }

  /// Get list of all saved accounts from registry
  static Future<List<Map<String, dynamic>>> getSavedAccountsFromRegistry() async {
    final raw = await _safeRead(key: _kSavedAccountsRegistry);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      print('[TOKEN SERVICE ERROR] Failed to parse saved accounts registry: $e');
    }
    return [];
  }

  /// Set selected account as active session
  static Future<void> switchActiveAccountSession(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    final accounts = await getSavedAccountsFromRegistry();
    final target = accounts.firstWhere(
      (a) => a['email']?.toString().trim().toLowerCase() == cleanEmail,
      orElse: () => {},
    );

    if (target.isNotEmpty) {
      final accessToken = target['accessToken']?.toString() ?? '';
      final refreshToken = target['refreshToken']?.toString() ?? '';
      final name = target['name']?.toString() ?? cleanEmail.split('@').first;
      final avatar = target['avatarUrl']?.toString() ?? '';

      if (accessToken.isNotEmpty) {
        await saveTokens(accessToken: accessToken, refreshToken: refreshToken);
        await _safeWrite(key: _kEmail, value: cleanEmail);
        await _safeWrite(key: _kName, value: name);
        if (avatar.isNotEmpty) {
          await saveUserAvatar(cleanEmail, avatar);
        }
        print('[TOKEN SERVICE] Active session switched to: $cleanEmail');
      }
    }
  }

  /// Remove account from registry (on logout)
  static Future<void> removeAccountFromRegistry(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final existing = await getSavedAccountsFromRegistry();
    final updated = existing.where((a) => a['email']?.toString().trim().toLowerCase() != cleanEmail).toList();
    await _safeWrite(key: _kSavedAccountsRegistry, value: jsonEncode(updated));
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  static Future<String?> getAccessToken() async {
    if (cachedAccessToken != null && cachedAccessToken!.isNotEmpty) {
      return cachedAccessToken;
    }
    cachedAccessToken = await _safeRead(key: _kAccess);
    return cachedAccessToken;
  }

  static Future<String?> getRefreshToken() async =>
      _safeRead(key: _kRefresh);

  static Future<String?> getUserEmail() async => _safeRead(key: _kEmail);

  static Future<String?> getUserName() async => _safeRead(key: _kName);

  static const _kGlobalAvatar = 'bnx_user_avatar_global';

  static String _kAvatarKey(String email) =>
      'bnx_user_avatar_${email.trim().toLowerCase()}';

  static Future<void> saveUserAvatar(String email, String avatarUrl) async {
    final cleanEmail = email.trim().toLowerCase();
    if (avatarUrl.isNotEmpty) {
      await _safeWrite(key: _kGlobalAvatar, value: avatarUrl);
      if (cleanEmail.isNotEmpty) {
        await _safeWrite(key: _kAvatarKey(cleanEmail), value: avatarUrl);
      }
    }
  }

  static Future<String?> getUserAvatar(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isNotEmpty) {
      final val = await _safeRead(key: _kAvatarKey(cleanEmail));
      if (val != null && val.isNotEmpty) return val;
    }
    return await _safeRead(key: _kGlobalAvatar);
  }

  static String _kSettingsKey(String email) =>
      'bnx_user_settings_${email.trim().toLowerCase()}';

  static Future<void> saveUserSettings(String email, Map<String, dynamic> settings) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isNotEmpty) {
      await _safeWrite(key: _kSettingsKey(cleanEmail), value: jsonEncode(settings));
    }
  }

  static Future<Map<String, dynamic>?> getUserSettings(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    final str = await _safeRead(key: _kSettingsKey(cleanEmail));
    if (str != null && str.isNotEmpty) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static String _kTemplatesKey(String email) =>
      'bnx_user_templates_${email.trim().toLowerCase()}';

  static Future<void> saveUserTemplates(String email, List<Map<String, dynamic>> templates) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isNotEmpty) {
      await _safeWrite(key: _kTemplatesKey(cleanEmail), value: jsonEncode(templates));
    }
  }

  static Future<List<Map<String, dynamic>>> getUserTemplates(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return [];
    final str = await _safeRead(key: _kTemplatesKey(cleanEmail));
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str);
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Returns true if a valid access token is stored (session is persisted).
  static Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Casbox Install Timestamp ─────────────────────────────────────────────
  // Stores the timestamp of first app launch after install.
  // Messages with timestamps BEFORE this are "old" → auto-Received.
  // Messages with timestamps AFTER this are "new" → go to Requests.
  // Wiped on uninstall, so reinstall resets the boundary.
  static const _kInstallTimestamp = 'bnx_casbox_install_timestamp';

  /// Returns the install timestamp. If none exists (first launch), stores NOW and returns it.
  static Future<DateTime> getInstallTimestamp() async {
    final str = await _safeRead(key: _kInstallTimestamp);
    if (str != null && str.isNotEmpty) {
      try {
        return DateTime.parse(str);
      } catch (_) {}
    }
    // First launch after install — record current time
    final now = DateTime.now();
    await _safeWrite(key: _kInstallTimestamp, value: now.toIso8601String());
    print('[TOKEN SERVICE] First launch detected. Install timestamp set to: ${now.toIso8601String()}');
    return now;
  }

  static String _kAcceptedCasboxIds(String email) => 'bnx_accepted_casbox_ids_${email.trim().toLowerCase()}';
  static String _kRejectedCasboxIds(String email) => 'bnx_rejected_casbox_ids_${email.trim().toLowerCase()}';
  static String _kAcceptedCasboxSenders(String email) => 'bnx_accepted_casbox_senders_${email.trim().toLowerCase()}';
  static String _kRejectedCasboxSenders(String email) => 'bnx_rejected_casbox_senders_${email.trim().toLowerCase()}';

  static Future<List<String>> getAcceptedCasboxIds() async {
    final email = await getUserEmail() ?? '';
    final str = await _safeRead(key: _kAcceptedCasboxIds(email));
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List;
        return list.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveAcceptedCasboxId(String id) async {
    final email = await getUserEmail() ?? '';
    final current = await getAcceptedCasboxIds();
    if (!current.contains(id)) {
      current.add(id);
      await _safeWrite(key: _kAcceptedCasboxIds(email), value: jsonEncode(current));
    }
  }

  static Future<List<String>> getRejectedCasboxIds() async {
    final email = await getUserEmail() ?? '';
    final str = await _safeRead(key: _kRejectedCasboxIds(email));
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List;
        return list.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveRejectedCasboxId(String id) async {
    final email = await getUserEmail() ?? '';
    final current = await getRejectedCasboxIds();
    if (!current.contains(id)) {
      current.add(id);
      await _safeWrite(key: _kRejectedCasboxIds(email), value: jsonEncode(current));
    }
  }

  static Future<Set<String>> getAcceptedCasboxSenders() async {
    final email = await getUserEmail() ?? '';
    final str = await _safeRead(key: _kAcceptedCasboxSenders(email));
    if (str == null || str.isEmpty) return {};
    try {
      final List list = jsonDecode(str);
      return list.map((e) => e.toString().trim().toLowerCase()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveAcceptedCasboxSender(String senderEmail) async {
    final email = await getUserEmail() ?? '';
    final normalized = senderEmail.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final set = await getAcceptedCasboxSenders();
    set.add(normalized);
    await _safeWrite(key: _kAcceptedCasboxSenders(email), value: jsonEncode(set.toList()));
  }

  static Future<Set<String>> getRejectedCasboxSenders() async {
    final email = await getUserEmail() ?? '';
    final str = await _safeRead(key: _kRejectedCasboxSenders(email));
    if (str == null || str.isEmpty) return {};
    try {
      final List list = jsonDecode(str);
      return list.map((e) => e.toString().trim().toLowerCase()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveRejectedCasboxSender(String senderEmail) async {
    final email = await getUserEmail() ?? '';
    final normalized = senderEmail.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final set = await getRejectedCasboxSenders();
    set.add(normalized);
    await _safeWrite(key: _kRejectedCasboxSenders(email), value: jsonEncode(set.toList()));
  }

  static String _kReadCasboxIdsForEmail(String email) => 'bnx_read_casbox_ids_${email.trim().toLowerCase()}';

  static Future<List<String>> getReadCasboxIds() async {
    final email = await getUserEmail() ?? '';
    final str = await _safeRead(key: _kReadCasboxIdsForEmail(email));
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List;
        return list.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> markCasboxRead(String id) async {
    final email = await getUserEmail() ?? '';
    final current = await getReadCasboxIds();
    if (!current.contains(id)) {
      current.add(id);
      await _safeWrite(key: _kReadCasboxIdsForEmail(email), value: jsonEncode(current));
    }
  }

  // ── Persistent Label Storage ──────────────────────────────────────────────

  static const _kAssignedEmailLabels = 'bnx_assigned_email_labels';

  static Future<Map<String, List<String>>> getAssignedEmailLabels() async {
    final str = await _safeRead(key: _kAssignedEmailLabels);
    if (str == null || str.isEmpty) return {};
    try {
      final decoded = jsonDecode(str) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(
          k,
          (v as List).map((e) => e.toString()).toList(),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveAssignedEmailLabel(
    String emailId,
    String labelName,
  ) async {
    if (emailId.isEmpty || labelName.isEmpty) return;
    final current = await getAssignedEmailLabels();
    final list = current[emailId] ?? [];
    if (!list.any((l) => l.trim().toLowerCase() == labelName.trim().toLowerCase())) {
      list.add(labelName);
      current[emailId] = list;
      await _safeWrite(
        key: _kAssignedEmailLabels,
        value: jsonEncode(current),
      );
    }
  }

  static Future<void> removeAssignedEmailLabel(
    String emailId,
    String labelName,
  ) async {
    if (emailId.isEmpty || labelName.isEmpty) return;
    final current = await getAssignedEmailLabels();
    final list = current[emailId] ?? [];
    list.removeWhere((l) => l.trim().toLowerCase() == labelName.trim().toLowerCase());
    if (list.isEmpty) {
      current.remove(emailId);
    } else {
      current[emailId] = list;
    }
    await _safeWrite(
      key: _kAssignedEmailLabels,
      value: jsonEncode(current),
    );
  }

  static Future<void> removeLabelFromAllEmails(String labelName) async {
    if (labelName.isEmpty) return;
    final target = labelName.trim().toLowerCase();
    final current = await getAssignedEmailLabels();
    bool changed = false;

    final updated = <String, List<String>>{};
    for (final entry in current.entries) {
      final list = entry.value;
      if (list.any((l) => l.trim().toLowerCase() == target)) {
        changed = true;
        final newList = list.where((l) => l.trim().toLowerCase() != target).toList();
        if (newList.isNotEmpty) {
          updated[entry.key] = newList;
        }
      } else {
        updated[entry.key] = list;
      }
    }

    if (changed) {
      await _safeWrite(
        key: _kAssignedEmailLabels,
        value: jsonEncode(updated),
      );
    }
  }

  // ── Colab Groups Persistence ─────────────────────────────────────────────

  static Future<void> saveLocalColabGroupsRaw(String jsonStr) async {
    await _safeWrite(key: 'bnx_local_colab_groups', value: jsonStr);
  }

  static Future<String?> loadLocalColabGroupsRaw() async {
    return await _safeRead(key: 'bnx_local_colab_groups');
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  /// Clears active session tokens AND wipes the saved accounts registry completely
  static Future<void> clearAll() async {
    try {
      await _safeDeleteAll();
      print('[TOKEN SERVICE] All tokens and account registries wiped completely.');
    } catch (e) {
      print('[TOKEN SERVICE] Warning during clearAll: $e');
    }
  }
}
