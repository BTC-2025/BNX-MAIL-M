import 'dart:convert';
import 'dart:io';
import '../../core/network/api_client.dart';
import '../../core/network/token_service.dart';
import '../../models/account_model.dart';
import '../../models/user_model.dart';

/// Handles user-profile and mailbox-list API calls.
class UserRepository {
  // ── Current User Profile ─────────────────────────────────────────────────

  static Future<UserModel?> getProfile() async {
    try {
      // Primary official endpoint: GET /api/users/settings
      var res = await ApiClient.get('/api/users/settings');
      var data = res['data'] as Map<String, dynamic>? ?? res;
      print('[PROFILE SETTINGS LOG] GET /api/users/settings returned: $data');

      // Fallback
      if (data.isEmpty) {
        try {
          res = await ApiClient.get('/api/user/profile');
          data = res['data'] as Map<String, dynamic>? ?? res;
          print(
            '[PROFILE SETTINGS LOG] Fallback GET /api/user/profile returned: $data',
          );
        } catch (_) {}
      }

      if (data.isEmpty) return null;
      final user = UserModel.fromJson(data);
      final savedAvatar = await TokenService.getUserAvatar(user.email);
      final loggedInEmail = await TokenService.getUserEmail() ?? '';
      final savedAvatarAlt = await TokenService.getUserAvatar(loggedInEmail);

      final avatarToUse = (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
          ? user.avatarUrl
          : (savedAvatar ?? savedAvatarAlt);

      if (avatarToUse != null && avatarToUse.isNotEmpty) {
        await TokenService.saveUserAvatar(user.email, avatarToUse);
        if (loggedInEmail.isNotEmpty) {
          await TokenService.saveUserAvatar(loggedInEmail, avatarToUse);
        }
        return user.copyWith(avatarUrl: avatarToUse);
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> fields) async {
    final email = await TokenService.getUserEmail() ?? '';
    if (email.isNotEmpty) {
      final existing = await TokenService.getUserSettings(email) ?? {};
      await TokenService.saveUserSettings(email, {...existing, ...fields});
    }
    try {
      // 5.7 Update Profile: PATCH /api/users/profile
      try {
        await ApiClient.patch('/api/users/profile', body: fields);
      } catch (_) {
        // Fallback 1: PATCH /api/users/settings
        try {
          await ApiClient.patch('/api/users/settings', body: fields);
        } catch (_) {
          // Fallback 2: PUT /api/user/profile
          await ApiClient.put('/api/user/profile', body: fields);
        }
      }
    } catch (e) {
      print('[PROFILE UPDATE API LOG] $e');
    }
  }

  static Future<String?> uploadAvatar(String email, String imagePath) async {
    await TokenService.saveUserAvatar(email, imagePath);
    final loggedInEmail = await TokenService.getUserEmail();
    if (loggedInEmail != null && loggedInEmail.isNotEmpty) {
      await TokenService.saveUserAvatar(loggedInEmail, imagePath);
    }
    try {
      String? uploadFilePath;
      if (imagePath.startsWith('data:image/')) {
        try {
          final uriParts = imagePath.split(',').last;
          final bytes = base64Decode(uriParts);
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/avatar_temp.jpg');
          await tempFile.writeAsBytes(bytes);
          uploadFilePath = tempFile.path;
        } catch (e) {
          print('[BASE64 DECODE ERROR] $e');
        }
      } else {
        uploadFilePath = imagePath;
      }

      if (uploadFilePath != null) {
        final res = await ApiClient.uploadProfilePicture(uploadFilePath);
        final remoteData = res['data'] as Map<String, dynamic>? ?? res;
        final serverAvatarUrl =
            remoteData['avatarUrl']?.toString() ??
            remoteData['avatar']?.toString() ??
            remoteData['url']?.toString();
        if (serverAvatarUrl != null && serverAvatarUrl.isNotEmpty) {
          await TokenService.saveUserAvatar(email, serverAvatarUrl);
          if (loggedInEmail != null && loggedInEmail.isNotEmpty) {
            await TokenService.saveUserAvatar(loggedInEmail, serverAvatarUrl);
          }
          return serverAvatarUrl;
        }
      }
    } catch (e) {
      print('[AVATAR UPLOAD ERROR] $e');
    }
    return imagePath;
  }

  // ── Mailboxes (multiple accounts) ────────────────────────────────────────

  static List<dynamic>? _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      final listKeys = [
        'emails',
        'messages',
        'items',
        'content',
        'data',
        'list',
        'mailboxes',
      ];
      for (final key in listKeys) {
        if (json.containsKey(key)) {
          final val = json[key];
          if (val is List) return val;
          if (val is Map) {
            final nested = _extractList(val);
            if (nested is List) return nested;
          }
        }
      }
      for (final val in json.values) {
        if (val is List) return val;
        if (val is Map) {
          final nested = _extractList(val);
          if (nested is List) return nested;
        }
      }
    }
    return null;
  }

  /// Returns all mailboxes/accounts linked to the authenticated user.
  static Future<List<AccountModel>> getMailboxes() async {
    try {
      final res = await ApiClient.get('/api/emails/list');
      print('[MAILBOXES LIST LOG] GET /api/emails/list returned: $res');
      final raw = _extractList(res);
      if (raw == null) return [];

      final list = raw
          .whereType<Map<String, dynamic>>()
          .map((json) => AccountModel.fromJson(json))
          .toList();

      if (list.isNotEmpty && !list.any((a) => a.isActive)) {
        list[0] = list[0].copyWith(isActive: true);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getSettings() async {
    final email = await TokenService.getUserEmail() ?? '';
    final localSettings = await TokenService.getUserSettings(email) ?? {};

    try {
      // Primary official endpoint: GET /api/users/settings
      final res = await ApiClient.get('/api/users/settings');
      final remoteData = (res['data'] as Map<String, dynamic>?) ?? (res);
      final merged = {...localSettings, ...remoteData};
      if (email.isNotEmpty && merged.isNotEmpty) {
        await TokenService.saveUserSettings(email, merged);
      }
      return merged.isNotEmpty ? merged : null;
    } catch (_) {
      return localSettings.isNotEmpty ? localSettings : null;
    }
  }

  static Future<void> updateSettings(Map<String, dynamic> settings) async {
    final email = await TokenService.getUserEmail() ?? '';
    final existing = await TokenService.getUserSettings(email) ?? {};

    // Prepare cleaned payload: parse String undoSendDelay to int if needed
    final payload = Map<String, dynamic>.from(settings);
    if (payload.containsKey('undoSendDelay')) {
      final val = payload['undoSendDelay'];
      if (val is String) {
        final match = RegExp(r'\d+').firstMatch(val);
        if (match != null) {
          payload['undoSendDelay'] = int.tryParse(match.group(0)!) ?? 0;
        } else {
          payload['undoSendDelay'] = 0;
        }
      }
    }

    final updated = {...existing, ...payload};

    if (email.isNotEmpty) {
      await TokenService.saveUserSettings(email, updated);
    }

    try {
      // Official endpoint: PATCH /api/users/settings
      try {
        await ApiClient.patch('/api/users/settings', body: payload);
      } catch (_) {
        // Fallback: PUT /api/users/settings (Plural /users/)
        await ApiClient.put('/api/users/settings', body: payload);
      }
    } catch (e) {
      print('[SETTINGS UPDATE API LOG] $e');
    }
  }

  // ── Recovery ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getRecovery() async {
    try {
      final res = await ApiClient.get('/api/users/recovery');
      return res['data'] as Map<String, dynamic>? ?? res;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateRecovery(
    String recoveryEmail,
    String phoneNumber,
  ) async {
    final body = {'recoveryEmail': recoveryEmail, 'phoneNumber': phoneNumber};
    try {
      await ApiClient.patch('/api/users/recovery', body: body);
    } catch (_) {
      await ApiClient.put('/api/user/profile', body: body);
    }
  }

  // ── Signatures ────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSignatures() async {
    try {
      final res = await ApiClient.get('/api/signatures');
      final list = res['data'] ?? res['signatures'] ?? res;
      if (list is List) {
        return list
            .map(
              (e) =>
                  e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> createSignature({
    required String name,
    required String content,
    bool isDefault = true,
  }) async {
    try {
      await ApiClient.post(
        '/api/signatures',
        body: {'name': name, 'content': content, 'isDefault': isDefault},
      );
    } catch (_) {}
  }

  static Future<void> updateSignature({
    required String id,
    required String name,
    required String content,
    bool isDefault = true,
  }) async {
    try {
      await ApiClient.put(
        '/api/signatures/$id',
        body: {'name': name, 'content': content, 'isDefault': isDefault},
      );
    } catch (_) {}
  }

  static Future<void> deleteSignature(String id) async {
    try {
      await ApiClient.delete('/api/signatures/$id');
    } catch (_) {}
  }

  static Future<void> setDefaultSignature(String id) async {
    try {
      await ApiClient.patch('/api/signatures/$id/default');
    } catch (_) {}
  }

  // ── Change Password ───────────────────────────────────────────────────────

  static Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await ApiClient.post(
        '/api/auth/change-password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } catch (_) {
      await ApiClient.post(
        '/api/user/change-password',
        body: {'oldPassword': currentPassword, 'newPassword': newPassword},
      );
    }
  }

  // ── Section 5: Manage Accounts & Sub-IDs ───────────────────────────────────

  /// 5.1 List Connected Mail Accounts (GET /api/emails/list)
  static Future<List<Map<String, dynamic>>> getConnectedEmails() async {
    try {
      final res = await ApiClient.get('/api/emails/list');
      final data = res['data'];
      dynamic list;
      if (data is Map && data.containsKey('emails')) {
        list = data['emails'];
      } else if (data is List) {
        list = data;
      } else if (res['emails'] is List) {
        list = res['emails'];
      } else {
        list = _extractList(res);
      }
      if (list is List) {
        return list
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      print('[GET CONNECTED EMAILS ERROR] $e');
      return [];
    }
  }

  /// 5.2 Create New Mailbox / Alias (POST /api/emails/create)
  static Future<Map<String, dynamic>?> createMailbox({
    required String emailName,
    required String password,
  }) async {
    try {
      final res = await ApiClient.post(
        '/api/emails/create',
        body: {
          'emailName': emailName.trim(),
          'password': password,
        },
      );
      final data = res['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data['email'] ?? data);
      }
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('[CREATE MAILBOX ERROR] $e');
      rethrow;
    }
  }

  /// 5.3 Switch Primary Mailbox (POST /api/emails/{emailId}/set-primary)
  static Future<bool> switchPrimaryMailbox(dynamic emailId) async {
    try {
      final res = await ApiClient.post('/api/emails/$emailId/set-primary');
      return res['success'] == true || res['data'] != null;
    } catch (e) {
      print('[SWITCH PRIMARY MAILBOX ERROR] $e');
      return false;
    }
  }

  /// Alias for switchPrimaryMailbox for backward compatibility
  static Future<void> setPrimaryMailbox(dynamic emailId) async {
    await switchPrimaryMailbox(emailId);
  }

  /// 5.4 Create Sub-ID Account (POST /api/subid/create)
  static Future<Map<String, dynamic>?> createSubId({
    required String prefix,
    required String password,
    required String firstName,
    required String lastName,
    String accountType = 'BUSINESS',
    List<int> permissions = const [],
  }) async {
    try {
      // Backend Jackson deserializer strictly expects List<Integer> for permissions
      final List<int> intPermissions = permissions;

      final normAccountType = accountType.toUpperCase().contains('PERSONAL')
          ? 'PERSONAL'
          : (accountType.toUpperCase().contains('CHILD') ? 'CHILD' : 'BUSINESS');

      final body = {
        'prefix': prefix.trim(),
        'password': password,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'accountType': normAccountType,
        'permissions': intPermissions,
      };
      final res = await ApiClient.post('/api/subid/create', body: body);
      final data = res['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('[CREATE SUBID ERROR] $e');
      rethrow;
    }
  }

  /// 5.5 List Sub-ID Accounts (GET /api/subid/list)
  static Future<List<Map<String, dynamic>>> listSubIds() async {
    try {
      final res = await ApiClient.get('/api/subid/list');
      final data = res['data'];
      dynamic list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['subIds'] is List) {
        list = data['subIds'];
      } else if (res['subids'] is List) {
        list = res['subids'];
      } else {
        list = _extractList(res);
      }
      if (list is List) {
        return list
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      print('[LIST SUB-IDS ERROR] $e');
      return [];
    }
  }

  /// Delete Sub-ID Account (DELETE /api/subid/{id})
  static Future<bool> deleteSubId(dynamic id) async {
    try {
      print('[SUBID DELETE] Calling DELETE endpoint: /api/subid/$id');
      final res = await ApiClient.delete('/api/subid/$id');
      print('[SUBID DELETE] Response body: $res');
      return res['success'] == true || res['error'] == null;
    } catch (e) {
      print('[SUBID DELETE ERROR] $e');
      rethrow;
    }
  }

  /// 5.6 Parent Approval for Child Accounts (PATCH /api/users/{id}/approve)
  static Future<bool> approveChildAccount(dynamic userId) async {
    try {
      final res = await ApiClient.patch('/api/users/$userId/approve');
      return res['success'] == true || (res['data'] is Map && res['data']['approved'] == true);
    } catch (e) {
      print('[APPROVE CHILD ACCOUNT ERROR] $e');
      return false;
    }
  }

  // ── Sessions & Activity Logs ──────────────────────────────────────────────

  /// Fetches active authenticated login sessions from GET /api/auth/sessions
  static Future<List<Map<String, String>>> getSessions() async {
    try {
      final res = await ApiClient.get('/api/auth/sessions');
      final list = res['data'] ?? res['sessions'] ?? res;
      if (list is List) {
        return list.map((item) {
          final map = item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{};
          final ua = map['userAgent']?.toString() ?? '';
          String deviceTitle = 'Web Browser Session';
          if (ua.contains('Dart')) {
            deviceTitle = 'BNX Mail Desktop App';
          } else if (ua.contains('Macintosh') || ua.contains('Mac OS')) {
            deviceTitle = 'macOS Browser';
          } else if (ua.contains('Windows')) {
            deviceTitle = 'Windows Browser';
          } else if (ua.contains('Android')) {
            deviceTitle = 'Android Mobile';
          } else if (ua.contains('iPhone') || ua.contains('iPad')) {
            deviceTitle = 'iOS Mobile';
          }

          final loc = map['location']?.toString();
          final ip = map['ipAddress']?.toString() ?? map['ip']?.toString() ?? '127.0.0.1';
          final ipAndLoc = (loc != null && loc.isNotEmpty) ? '$ip — $loc' : ip;

          return {
            'id': map['id']?.toString() ?? '',
            'title': deviceTitle,
            'ip': ipAndLoc,
            'userAgent': ua,
            'lastActive': map['createdAt']?.toString() ?? map['lastActive']?.toString() ?? 'Active Now',
            'currentSession': (map['currentSession'] == true).toString(),
          };
        }).toList();
      }
    } catch (e) {
      print('[USER_REPOSITORY] getSessions error: $e');
    }
    return [];
  }

  /// Revokes an active session via DELETE /api/auth/sessions/{id}
  static Future<bool> revokeSession(String sessionId) async {
    try {
      final res = await ApiClient.delete('/api/auth/sessions/$sessionId');
      return res['success'] == true;
    } catch (e) {
      print('[USER_REPOSITORY] revokeSession error: $e');
      return false;
    }
  }

  /// Fetches recent security and activity logs from GET /api/users/activity-logs
  static Future<List<Map<String, String>>> getActivityLogs() async {
    try {
      final res = await ApiClient.get('/api/users/activity-logs');
      final list = res['data'] ?? res['activityLogs'] ?? res;
      if (list is List) {
        return list.map((item) {
          final map = item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{};
          return {
            'activity': map['activity']?.toString() ?? 'Account Event',
            'ip': map['ipAddress']?.toString() ?? map['ip']?.toString() ?? '',
            'details': map['details']?.toString() ?? '',
            'timestamp': map['timestamp']?.toString() ?? '',
          };
        }).toList();
      }
    } catch (e) {
      print('[USER_REPOSITORY] getActivityLogs error: $e');
    }
    return [];
  }

  // ── Device Token API for FCM Push Notifications ──────────────────────────

  /// Registers FCM device token with backend API after login or token refresh.
  static Future<void> registerDeviceToken(String deviceToken) async {
    if (deviceToken.trim().isEmpty) return;
    final deviceType = Platform.isIOS ? 'ios' : 'android';
    try {
      print('[DEVICE TOKEN API] Registering FCM device token with backend...');
      await ApiClient.post(
        '/api/users/device-token',
        body: {'deviceToken': deviceToken.trim(), 'deviceType': deviceType},
      );
      print('[DEVICE TOKEN API] FCM device token registered successfully');
    } catch (e) {
      print('[DEVICE TOKEN API ERROR] Failed to register device token: $e');
    }
  }

  /// Unregisters FCM device token from backend API on logout.
  static Future<void> unregisterDeviceToken(String deviceToken) async {
    if (deviceToken.trim().isEmpty) return;
    try {
      print(
        '[DEVICE TOKEN API] Unregistering FCM device token from backend...',
      );
      final encodedToken = Uri.encodeComponent(deviceToken.trim());
      await ApiClient.delete('/api/users/device-token/$encodedToken');
      print('[DEVICE TOKEN API] FCM device token unregistered successfully');
    } catch (e) {
      print('[DEVICE TOKEN API ERROR] Failed to unregister device token: $e');
    }
  }
}
