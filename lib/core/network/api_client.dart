import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'token_service.dart';
import 'package:http_parser/http_parser.dart';

/// Central HTTP client for all BNX Mail API calls.
///
/// Features:
/// - Reads BASE_URL from flutter_dotenv
/// - Automatically injects Authorization header
/// - 401 → auto refreshes token → retries once
/// - Uniform error parsing into [ApiException]
/// - 15-second timeout on all requests
class ApiClient {
  static String get baseUrl => _base;

  static String get _base =>
      dotenv.env['BASE_URL'] ?? 'https://api.bnxmail.com';

  static const Duration _timeout = Duration(seconds: 15);

  // ── Low-level helpers ───────────────────────────────────────────────────

  static Future<Map<String, String>> _headers({
    bool auth = true,
    String? tempToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = tempToken ?? await TokenService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Map<String, dynamic> _parseBody(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (_) {
      return {'message': response.body};
    }
  }

  static ApiException _toException(http.Response r) {
    final body = _parseBody(r);
    final msg =
        body['message']?.toString() ??
        body['error']?.toString() ??
        'Request failed (${r.statusCode})';
    return ApiException(statusCode: r.statusCode, message: msg);
  }

  static void _assertOk(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw _toException(r);
    }
  }

  // ── Token refresh ───────────────────────────────────────────────────────

  static Future<bool> _tryRefresh() async {
    final refresh = await TokenService.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final r = await http
          .post(
            Uri.parse('$_base/api/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'refreshToken': refresh}),
          )
          .timeout(_timeout);
      if (r.statusCode == 200) {
        final body = _parseBody(r);
        final data = body['data'] as Map<String, dynamic>? ?? body;
        final newAccess = data['accessToken']?.toString() ?? '';
        final newRefresh = data['refreshToken']?.toString() ?? refresh;
        if (newAccess.isNotEmpty) {
          await TokenService.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ── Public API methods ──────────────────────────────────────────────────

  /// GET request. Retries once on 401 after token refresh.
  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    bool auth = true,
    String? tempToken,
  }) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: queryParams);
    final headers = await _headers(auth: auth, tempToken: tempToken);
    final loggedHeaders = Map<String, String>.from(headers)
      ..remove('Authorization');

    // Using simple print/debugPrint to fulfill requirement: 'Add comprehensive logging for every API request and response'
    print('[API REQUEST] GET $uri | Headers: $loggedHeaders');

    http.Response r;
    try {
      r = await http.get(uri, headers: headers).timeout(_timeout);
      print(
        '[API RESPONSE] GET $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
      );
    } on SocketException catch (e) {
      print('[API ERROR] GET $uri | SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No internet connection',
      );
    } on TimeoutException catch (e) {
      print('[API ERROR] GET $uri | TimeoutException: $e');
      throw const ApiException(statusCode: 408, message: 'Request timed out');
    }

    if (r.statusCode == 401 && auth) {
      print('[API INFO] GET $uri returned 401. Attempting token refresh...');
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = await _headers(auth: auth);
        try {
          r = await http.get(uri, headers: retryHeaders).timeout(_timeout);
          print(
            '[API RESPONSE RETRY] GET $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
          );
        } catch (e) {
          print('[API ERROR RETRY] GET $uri | Exception: $e');
          throw const ApiException(
            statusCode: 401,
            message: 'Session expired. Please log in again.',
          );
        }
      } else {
        print('[API ERROR] Token refresh failed. Clearing tokens.');
        await TokenService.clearAll();
        throw const ApiException(
          statusCode: 401,
          message: 'Session expired. Please log in again.',
        );
      }
    }

    _assertOk(r);
    return _parseBody(r);
  }

  /// POST request. Retries once on 401 after token refresh.
  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool auth = true,
    String? tempToken,
  }) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: queryParams);
    final headers = await _headers(auth: auth, tempToken: tempToken);
    final loggedHeaders = Map<String, String>.from(headers)
      ..remove('Authorization');

    print('[API REQUEST] POST $uri | Headers: $loggedHeaders | Body: $body');

    http.Response r;
    try {
      r = await http
          .post(uri, headers: headers, body: json.encode(body ?? {}))
          .timeout(_timeout);
      print(
        '[API RESPONSE] POST $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
      );
    } on SocketException catch (e) {
      print('[API ERROR] POST $uri | SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No internet connection',
      );
    } on TimeoutException catch (e) {
      print('[API ERROR] POST $uri | TimeoutException: $e');
      throw const ApiException(statusCode: 408, message: 'Request timed out');
    }

    if (r.statusCode == 401 && auth) {
      print('[API INFO] POST $uri returned 401. Attempting token refresh...');
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = await _headers(auth: auth);
        try {
          r = await http
              .post(uri, headers: retryHeaders, body: json.encode(body ?? {}))
              .timeout(_timeout);
          print(
            '[API RESPONSE RETRY] POST $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
          );
        } catch (e) {
          print('[API ERROR RETRY] POST $uri | Exception: $e');
          throw const ApiException(
            statusCode: 401,
            message: 'Session expired. Please log in again.',
          );
        }
      } else {
        print('[API ERROR] Token refresh failed. Clearing tokens.');
        await TokenService.clearAll();
        throw const ApiException(
          statusCode: 401,
          message: 'Session expired. Please log in again.',
        );
      }
    }

    _assertOk(r);
    return _parseBody(r);
  }

  /// PUT request.
  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    String? tempToken,
  }) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers(auth: auth, tempToken: tempToken);
    final loggedHeaders = Map<String, String>.from(headers)
      ..remove('Authorization');

    print('[API REQUEST] PUT $uri | Headers: $loggedHeaders | Body: $body');

    http.Response r;
    try {
      r = await http
          .put(uri, headers: headers, body: json.encode(body ?? {}))
          .timeout(_timeout);
      print(
        '[API RESPONSE] PUT $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
      );
    } on SocketException catch (e) {
      print('[API ERROR] PUT $uri | SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No internet connection',
      );
    } on TimeoutException catch (e) {
      print('[API ERROR] PUT $uri | TimeoutException: $e');
      throw const ApiException(statusCode: 408, message: 'Request timed out');
    }

    if (r.statusCode == 401 && auth) {
      print('[API INFO] PUT $uri returned 401. Attempting token refresh...');
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = await _headers(auth: auth);
        r = await http
            .put(uri, headers: retryHeaders, body: json.encode(body ?? {}))
            .timeout(_timeout);
        print(
          '[API RESPONSE RETRY] PUT $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
        );
      } else {
        print('[API ERROR] Token refresh failed. Clearing tokens.');
        await TokenService.clearAll();
        throw const ApiException(statusCode: 401, message: 'Session expired.');
      }
    }
    _assertOk(r);
    return _parseBody(r);
  }

  /// PATCH request.
  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers(auth: auth);
    final loggedHeaders = Map<String, String>.from(headers)
      ..remove('Authorization');

    print('[API REQUEST] PATCH $uri | Headers: $loggedHeaders | Body: $body');

    http.Response r;
    try {
      r = await http
          .patch(uri, headers: headers, body: json.encode(body ?? {}))
          .timeout(_timeout);
      print(
        '[API RESPONSE] PATCH $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
      );
    } on SocketException catch (e) {
      print('[API ERROR] PATCH $uri | SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No internet connection',
      );
    } on TimeoutException catch (e) {
      print('[API ERROR] PATCH $uri | TimeoutException: $e');
      throw const ApiException(statusCode: 408, message: 'Request timed out');
    }

    if (r.statusCode == 401 && auth) {
      print('[API INFO] PATCH $uri returned 401. Attempting token refresh...');
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = await _headers(auth: auth);
        r = await http
            .patch(uri, headers: retryHeaders, body: json.encode(body ?? {}))
            .timeout(_timeout);
        print(
          '[API RESPONSE RETRY] PATCH $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
        );
      } else {
        print('[API ERROR] Token refresh failed. Clearing tokens.');
        await TokenService.clearAll();
        throw const ApiException(statusCode: 401, message: 'Session expired.');
      }
    }
    _assertOk(r);
    return _parseBody(r);
  }

  /// DELETE request.
  static Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? queryParams,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: queryParams);
    final headers = await _headers(auth: auth);
    final loggedHeaders = Map<String, String>.from(headers)
      ..remove('Authorization');

    print('[API REQUEST] DELETE $uri | Headers: $loggedHeaders');

    http.Response r;
    try {
      r = await http.delete(uri, headers: headers).timeout(_timeout);
      print(
        '[API RESPONSE] DELETE $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
      );
    } on SocketException catch (e) {
      print('[API ERROR] DELETE $uri | SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No internet connection',
      );
    } on TimeoutException catch (e) {
      print('[API ERROR] DELETE $uri | TimeoutException: $e');
      throw const ApiException(statusCode: 408, message: 'Request timed out');
    }

    if (r.statusCode == 401 && auth) {
      print('[API INFO] DELETE $uri returned 401. Attempting token refresh...');
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = await _headers(auth: auth);
        r = await http.delete(uri, headers: retryHeaders).timeout(_timeout);
        print(
          '[API RESPONSE RETRY] DELETE $uri | Status: ${r.statusCode} | Body: ${r.body.length > 300 ? "${r.body.substring(0, 300)}..." : r.body}',
        );
      } else {
        print('[API ERROR] Token refresh failed. Clearing tokens.');
        await TokenService.clearAll();
        throw const ApiException(statusCode: 401, message: 'Session expired.');
      }
    }
    _assertOk(r);
    return _parseBody(r);
  }

  /// Uploads attachment to draft via multipart/form-data.
  static Future<void> uploadAttachment(String draftId, String filePath) async {
    final uri = Uri.parse('$_base/api/mail/drafts/$draftId/attachments');
    final headers = await _headers(auth: true);
    headers.remove(
      'Content-Type',
    ); // Let http package handle Content-Type & boundary!

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);
    _assertOk(response);
  }

  /// Uploads user profile picture via multipart/form-data.
  static Future<Map<String, dynamic>> uploadProfilePicture(String filePath) async {
    final uri = Uri.parse('$_base/api/users/profile-picture');
    final headers = await _headers(auth: true);
    headers.remove('Content-Type'); // Let http package handle Content-Type & boundary!

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);

    final ext = filePath.split('.').last.toLowerCase();
    final isPng = ext == 'png';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      filePath,
      contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
    ));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);
    _assertOk(response);
    return _parseBody(response);
  }
}
