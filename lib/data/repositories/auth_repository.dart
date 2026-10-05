import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/token_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../models/user_model.dart';
import 'user_repository.dart';

/// Handles all authentication API calls.
/// Saves/clears tokens after successful login/logout.
class AuthRepository {
  // ── Login ────────────────────────────────────────────────────────────────

  /// Authenticates the user and persists tokens.
  /// Returns the [UserModel] on success.
  /// Throws [ApiException] on failure.
  static Future<UserModel> login(String email, String password) async {
    final res = await ApiClient.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    final data = res['data'] as Map<String, dynamic>? ?? res;
    final accessToken = data['accessToken']?.toString() ?? '';
    final refreshToken = data['refreshToken']?.toString() ?? '';

    if (accessToken.isEmpty) {
      throw const ApiException(statusCode: 401, message: 'Invalid credentials');
    }

    await TokenService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    // Build a minimal user model from login response
    final userJson = data['user'] as Map<String, dynamic>? ?? {};
    final user = userJson.isNotEmpty
        ? UserModel.fromJson(userJson)
        : UserModel(name: email.split('@').first, email: email);

    await TokenService.saveUserInfo(email: user.email, name: user.name);
    final avatarFromResponse = userJson['avatarUrl']?.toString() ?? userJson['avatar']?.toString();
    if (avatarFromResponse != null && avatarFromResponse.isNotEmpty) {
      await TokenService.saveUserAvatar(user.email, avatarFromResponse);
    } else {
      // Non-blocking background fetch of user profile avatar
      UserRepository.getProfile().then((profile) {
        if (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty) {
          TokenService.saveUserAvatar(user.email, profile.avatarUrl!);
        }
      }).catchError((_) {});
    }

    // Register FCM device token with backend API immediately after login
    try {
      final fcmToken = NotificationService.instance.fcmToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        UserRepository.registerDeviceToken(fcmToken).catchError((_) {});
      }
    } catch (_) {}

    return user;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    try {
      final fcmToken = NotificationService.instance.fcmToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await UserRepository.unregisterDeviceToken(fcmToken);
      }
    } catch (_) {}

    try {
      await ApiClient.post('/api/auth/logout');
    } catch (_) {
      // Always clear local tokens even if the server call fails
    } finally {
      await TokenService.clearTokens();
    }
  }

  static Future<void> logoutSpecificAccount(String email) async {
    try {
      final fcmToken = NotificationService.instance.fcmToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await UserRepository.unregisterDeviceToken(fcmToken);
      }
    } catch (_) {}

    try {
      await ApiClient.post('/api/auth/logout');
    } catch (_) {}
    await TokenService.removeAccountFromRegistry(email);
    await TokenService.clearTokens();
  }

  // ── Token Refresh ─────────────────────────────────────────────────────────

  static Future<void> refreshToken() async {
    final refresh = await TokenService.getRefreshToken();
    if (refresh == null) {
      throw const ApiException(statusCode: 401, message: 'No refresh token');
    }
    final res = await ApiClient.post(
      '/api/auth/refresh',
      body: {'refreshToken': refresh},
      auth: false,
    );
    final data = res['data'] as Map<String, dynamic>? ?? res;
    await TokenService.saveTokens(
      accessToken: data['accessToken']?.toString() ?? '',
      refreshToken: data['refreshToken']?.toString() ?? refresh,
    );
  }

  // ── Registration — Step 1 ─────────────────────────────────────────────────

  /// Registers a new account and returns the tempToken for Step 2 (email creation).
  static Future<String> register({
    required String mode, // 'PERSONAL' | 'BUSINESS' | 'CHILD'
    required String firstName,
    required String lastName,
    required String username,
    required String password,
    required String dob,
    String? businessName,
    String? customDomain,
    String? parentEmail,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    final isChildMode = mode.toUpperCase() == 'CHILD';
    final initialMode = isChildMode ? 'PERSONAL' : mode;

    final body = <String, dynamic>{
      'mode': initialMode,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'password': password,
      'dob': dob,
    };

    if (isChildMode || (parentEmail != null && parentEmail.isNotEmpty)) {
      body['isChild'] = true;
      body['accountType'] = 'CHILD';
    }

    if (businessName != null && businessName.isNotEmpty) {
      body['businessName'] = businessName;
    }
    if (customDomain != null && customDomain.isNotEmpty) {
      body['customDomain'] = customDomain;
      body['domain'] = customDomain;
    }
    if (parentEmail != null && parentEmail.isNotEmpty) {
      body['parentEmail'] = parentEmail;
    }
    if (securityQuestion != null) body['securityQuestion'] = securityQuestion;
    if (securityAnswer != null) body['securityAnswer'] = securityAnswer;

    Map<String, dynamic> res;
    try {
      res = await ApiClient.post(
        '/api/auth/register',
        body: body,
        auth: false,
      );
    } catch (e) {
      if (e.toString().toLowerCase().contains('unsupported registration mode')) {
        body['mode'] = isChildMode ? 'child' : mode.toLowerCase();
        res = await ApiClient.post(
          '/api/auth/register',
          body: body,
          auth: false,
        );
      } else {
        rethrow;
      }
    }

    final data = res['data'] as Map<String, dynamic>? ?? res;
    final tempToken = data['tempToken']?.toString() ?? '';
    if (tempToken.isEmpty) {
      throw const ApiException(
        statusCode: 500,
        message: 'Registration failed: no temp token returned',
      );
    }
    return tempToken;
  }

  // ── Registration — Step 2 (Email Handle) ─────────────────────────────────

  /// Creates the email handle (mailbox) using the tempToken from Step 1.
  /// Automatically logs in and saves real tokens afterwards.
  static Future<UserModel> createMailbox({
    required String tempToken,
    required String emailName,
    required String password,
    bool isPrimary = true,
  }) async {
    final res = await ApiClient.post(
      '/api/emails/create',
      body: {
        'emailName': emailName,
        'password': password,
        'isPrimary': isPrimary,
      },
      tempToken: tempToken,
    );
    final data = res['data'] as Map<String, dynamic>? ?? res;

    // If the API returns tokens directly after creation, save them
    final accessToken = data['accessToken']?.toString() ?? '';
    final refreshToken = data['refreshToken']?.toString() ?? '';
    if (accessToken.isNotEmpty) {
      await TokenService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      final userJson = data['user'] as Map<String, dynamic>? ?? {};
      final user = userJson.isNotEmpty
          ? UserModel.fromJson(userJson)
          : UserModel(name: emailName, email: '$emailName@bnxmail.com');
      await TokenService.saveUserInfo(email: user.email, name: user.name);
      return user;
    }

    // Otherwise build a placeholder — caller will login separately
    return UserModel(name: emailName, email: '$emailName@bnxmail.com');
  }

  // ── Child Registration — Parent OTP ───────────────────────────────────────

  static Future<void> sendParentOtp(String parentEmail) async {
    await ApiClient.post(
      '/api/auth/child/send-parent-otp',
      body: {'parentEmail': parentEmail},
      auth: false,
    );
  }

  static Future<void> verifyParentOtp(String parentEmail, String otp) async {
    await ApiClient.post(
      '/api/auth/child/verify-parent-otp',
      body: {'parentEmail': parentEmail, 'otp': otp},
      auth: false,
    );
  }

  // ── Username Suggestions ─────────────────────────────────────────────────

  static Future<List<String>> getUsernameSuggestions({
    required String firstName,
    required String lastName,
    required String dob,
  }) async {
    try {
      final res = await ApiClient.get(
        '/api/auth/username-suggestions',
        queryParams: {'firstName': firstName, 'lastName': lastName, 'dob': dob},
        auth: false,
      );
      final data = res['data'];
      if (data is List) return data.map((s) => s.toString()).toList();
    } catch (_) {}
    return [];
  }
}
