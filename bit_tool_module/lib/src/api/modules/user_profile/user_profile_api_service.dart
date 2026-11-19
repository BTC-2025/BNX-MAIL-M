import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../client/api_exceptions.dart';
import '../../config/api_config.dart';
import 'user_profile_model.dart';

/// Dedicated service responsible for retrieving the current user's profile context.
///
/// NOTE: Login and authentication endpoints are intentionally excluded.
/// This service consumes the authentication token provided by the host application.
class UserProfileApiService {
  final BitToolApiClient _client;
  final BitToolApiConfig _config;

  UserProfileApiService({
    required BitToolApiClient client,
    BitToolApiConfig config = const BitToolApiConfig(),
  })  : _client = client,
        _config = config;

  /// Retrieves the current authenticated user profile via GET /api/users/me.
  Future<UserProfileModel> getCurrentUser() async {
    final uri = _config.userProfileMeUri;

    try {
      final dynamic raw = await _client.get(uri);
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final success = map['success'] == true;
        if (!success && map.containsKey('message') && map['success'] == false) {
          throw BitToolApiException(map['message']?.toString() ?? 'Failed to retrieve profile.');
        }

        final data = map['data'] ?? map['user'] ?? map;
        if (data is Map) {
          return UserProfileModel.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw const BitToolInvalidResponseException(
        'User profile data missing from server response.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[UserProfileAPI] getCurrentUser error: $e');
      rethrow;
    }
  }
}

