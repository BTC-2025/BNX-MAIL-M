import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_exceptions.dart';

/// Callback signature allowing host application to supply its current auth token.
typedef BitToolTokenProvider = Future<String?> Function();

/// Central HTTP Client for making API requests across Bit Tool modules.
///
/// Designed to be host-agnostic: authentication tokens are provided dynamically
/// by the host application through [tokenProvider] or [staticToken], ensuring
/// zero dependency on login screens or local storage within this module.
class BitToolApiClient {
  final http.Client _client;
  final BitToolTokenProvider? _tokenProvider;
  final String? _staticToken;
  final Duration _timeout;

  BitToolApiClient({
    http.Client? client,
    BitToolTokenProvider? tokenProvider,
    String? staticToken,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider,
        _staticToken = staticToken,
        _timeout = timeout;

  /// Resolves the current authentication token from static token or provider callback.
  Future<String?> _resolveToken({String? overrideToken}) async {
    if (overrideToken != null && overrideToken.trim().isNotEmpty) {
      return overrideToken.trim();
    }
    final staticToken = _staticToken;
    if (staticToken != null && staticToken.trim().isNotEmpty) {
      return staticToken.trim();
    }
    final tokenProvider = _tokenProvider;
    if (tokenProvider != null) {
      try {
        final token = await tokenProvider();
        return token?.trim();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BitToolApiClient] Error resolving token from provider: $e');
        }
      }
    }
    return null;
  }

  /// Builds standard headers including Authorization if token exists.
  Future<Map<String, String>> _buildHeaders({
    String? overrideToken,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await _resolveToken(overrideToken: overrideToken);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Executes an HTTP GET request.
  Future<dynamic> get(
    Uri uri, {
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _buildHeaders(
      overrideToken: token,
      extraHeaders: extraHeaders,
    );

    _logRequest('GET', uri, headers);

    try {
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      _logResponse('GET', uri, response);
      return _handleResponse(response, uri);
    } on TimeoutException {
      throw const BitToolTimeoutException();
    } on http.ClientException catch (e) {
      throw BitToolNetworkException('Connection failed: ${e.message}');
    } on FormatException catch (e) {
      throw BitToolInvalidResponseException('Malformed JSON: ${e.message}');
    } catch (e) {
      if (e is BitToolApiException) rethrow;
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Network is unreachable')) {
        throw const BitToolNetworkException();
      }
      throw BitToolApiException(msg);
    }
  }

  /// Executes an HTTP POST request.
  Future<dynamic> post(
    Uri uri, {
    dynamic body,
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _buildHeaders(
      overrideToken: token,
      extraHeaders: extraHeaders,
    );

    _logRequest('POST', uri, headers, body);

    try {
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _client
          .post(uri, headers: headers, body: encodedBody)
          .timeout(_timeout);
      _logResponse('POST', uri, response);
      return _handleResponse(response, uri);
    } on TimeoutException {
      throw const BitToolTimeoutException();
    } on http.ClientException catch (e) {
      throw BitToolNetworkException('Connection failed: ${e.message}');
    } on FormatException catch (e) {
      throw BitToolInvalidResponseException('Malformed JSON: ${e.message}');
    } catch (e) {
      if (e is BitToolApiException) rethrow;
      throw BitToolApiException(e.toString());
    }
  }

  /// Executes an HTTP PUT request.
  Future<dynamic> put(
    Uri uri, {
    dynamic body,
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _buildHeaders(
      overrideToken: token,
      extraHeaders: extraHeaders,
    );

    _logRequest('PUT', uri, headers, body);

    try {
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _client
          .put(uri, headers: headers, body: encodedBody)
          .timeout(_timeout);
      _logResponse('PUT', uri, response);
      return _handleResponse(response, uri);
    } on TimeoutException {
      throw const BitToolTimeoutException();
    } on http.ClientException catch (e) {
      throw BitToolNetworkException('Connection failed: ${e.message}');
    } on FormatException catch (e) {
      throw BitToolInvalidResponseException('Malformed JSON: ${e.message}');
    } catch (e) {
      if (e is BitToolApiException) rethrow;
      throw BitToolApiException(e.toString());
    }
  }

  /// Executes an HTTP DELETE request.
  Future<dynamic> delete(
    Uri uri, {
    dynamic body,
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _buildHeaders(
      overrideToken: token,
      extraHeaders: extraHeaders,
    );

    _logRequest('DELETE', uri, headers, body);

    try {
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await _client
          .delete(uri, headers: headers, body: encodedBody)
          .timeout(_timeout);
      _logResponse('DELETE', uri, response);
      return _handleResponse(response, uri);
    } on TimeoutException {
      throw const BitToolTimeoutException();
    } on http.ClientException catch (e) {
      throw BitToolNetworkException('Connection failed: ${e.message}');
    } catch (e) {
      if (e is BitToolApiException) rethrow;
      throw BitToolApiException(e.toString());
    }
  }

  /// Standardized response validator and decoder.
  dynamic _handleResponse(http.Response response, Uri uri) {
    final code = response.statusCode;
    final body = response.body.trim();

    if (code == 204 || body.isEmpty) {
      return {'success': true, 'statusCode': code};
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      if (code >= 200 && code < 300) {
        return body;
      }
      throw BitToolInvalidResponseException(
        'Server returned status $code with non-JSON body: $body',
      );
    }

    if (code >= 200 && code < 300) {
      return decoded;
    }

    String errorMsg = 'HTTP $code';
    if (decoded is Map) {
      errorMsg = decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          decoded['msg']?.toString() ??
          'HTTP $code Error';
    }

    switch (code) {
      case 401:
        throw BitToolUnauthorizedException(errorMsg);
      case 403:
        throw BitToolForbiddenException(errorMsg);
      case 404:
        throw BitToolNotFoundException(errorMsg);
      case 400:
      case 422:
        throw BitToolValidationException(
          errorMsg,
          statusCode: code,
          responseBody: body,
        );
      default:
        if (code >= 500) {
          throw BitToolServerException(
            errorMsg,
            statusCode: code,
            responseBody: body,
          );
        }
        throw BitToolApiException(
          errorMsg,
          statusCode: code,
          responseBody: body,
        );
    }
  }

  void _logRequest(String method, Uri uri, Map<String, String> headers, [dynamic body]) {
    if (!kDebugMode) return;
    final sanitizedHeaders = Map<String, String>.from(headers);
    if (sanitizedHeaders.containsKey('Authorization')) {
      sanitizedHeaders['Authorization'] = 'Bearer [REDACTED]';
    }
    debugPrint('[BitToolApiClient] --> $method $uri');
  }

  void _logResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    debugPrint(
      '[BitToolApiClient] <-- $method $uri [Status: ${response.statusCode}]',
    );
  }
}
