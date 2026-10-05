/// Typed exception thrown by [ApiClient] for all non-2xx HTTP responses
/// and network/timeout failures.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  /// Whether this exception represents an expired / invalid token.
  bool get isAuthError => statusCode == 401;

  /// Whether this exception represents a missing / stale resource (e.g. "Email with UID X not found").
  bool get isNotFound =>
      statusCode == 404 ||
      message.toLowerCase().contains('not found') ||
      message.toLowerCase().contains('does not exist');

  @override
  String toString() => 'ApiException($statusCode): $message';
}
