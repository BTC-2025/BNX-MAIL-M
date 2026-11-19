/// Base class for all Bit Tool API exceptions.
class BitToolApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  const BitToolApiException(this.message, {this.statusCode, this.responseBody});

  @override
  String toString() {
    if (statusCode != null) {
      return 'BitToolApiException: [$statusCode] $message';
    }
    return 'BitToolApiException: $message';
  }
}

/// Thrown when an endpoint returns 401 Unauthorized or no token was provided.
class BitToolUnauthorizedException extends BitToolApiException {
  const BitToolUnauthorizedException([
    super.message = 'Unauthorized: Token is missing, invalid, or expired.',
  ]) : super(statusCode: 401);
}

/// Thrown when an endpoint returns 403 Forbidden.
class BitToolForbiddenException extends BitToolApiException {
  const BitToolForbiddenException([
    super.message = 'Forbidden: Access denied to this resource.',
  ]) : super(statusCode: 403);
}

/// Thrown when a requested resource is not found (404).
class BitToolNotFoundException extends BitToolApiException {
  const BitToolNotFoundException([
    super.message = 'Resource not found.',
  ]) : super(statusCode: 404);
}

/// Thrown when validation fails or request format is bad (400 / 422).
class BitToolValidationException extends BitToolApiException {
  const BitToolValidationException(
    super.message, {
    super.statusCode = 400,
    super.responseBody,
  });
}

/// Thrown when network is disconnected or server host cannot be resolved.
class BitToolNetworkException extends BitToolApiException {
  const BitToolNetworkException([
    super.message = 'Network connection failed. Please check your internet connection.',
  ]);
}

/// Thrown when request exceeds timeout threshold.
class BitToolTimeoutException extends BitToolApiException {
  const BitToolTimeoutException([
    super.message = 'Request timed out waiting for server response.',
  ]) : super(statusCode: 408);
}

/// Thrown when server returns 5xx error.
class BitToolServerException extends BitToolApiException {
  const BitToolServerException(
    super.message, {
    super.statusCode = 500,
    super.responseBody,
  });
}

/// Thrown when server returns non-JSON or malformed payload.
class BitToolInvalidResponseException extends BitToolApiException {
  const BitToolInvalidResponseException([
    super.message = 'Malformed response received from server.',
  ]);
}
