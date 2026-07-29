/// Typed exception thrown by [ApiClient] for all non-2xx HTTP responses
/// and network/timeout failures.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  /// Whether this exception represents an expired / invalid token.
  bool get isAuthError => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
