/// Metadata descriptor representing an API endpoint in the Bit Tool suite.
class EndpointDescriptor {
  /// Module name (e.g., 'Contacts', 'Notes', 'Calendar', 'Calculator', 'Notifications', 'Weather', 'Currency', 'User Profile').
  final String module;

  /// Specific feature or action name.
  final String title;

  /// HTTP Method: GET, POST, PUT, DELETE, PATCH.
  final String method;

  /// Endpoint path relative to the module's base URL.
  final String path;

  /// Complete example or default URL.
  final String fullUrl;

  /// Plain description of what the endpoint does.
  final String description;

  /// Whether an Authorization Bearer token is required.
  final bool requiresAuth;

  /// Expected query parameters (key -> description/type).
  final Map<String, String>? queryParameters;

  /// Expected JSON request body structure or schema notes.
  final Map<String, dynamic>? requestBodySchema;

  /// Sample or typical response structure.
  final Map<String, dynamic>? sampleResponse;

  const EndpointDescriptor({
    required this.module,
    required this.title,
    required this.method,
    required this.path,
    required this.fullUrl,
    required this.description,
    this.requiresAuth = true,
    this.queryParameters,
    this.requestBodySchema,
    this.sampleResponse,
  });

  Map<String, dynamic> toJson() => {
    'module': module,
    'title': title,
    'method': method,
    'path': path,
    'fullUrl': fullUrl,
    'description': description,
    'requiresAuth': requiresAuth,
    if (queryParameters != null) 'queryParameters': queryParameters,
    if (requestBodySchema != null) 'requestBodySchema': requestBodySchema,
    if (sampleResponse != null) 'sampleResponse': sampleResponse,
  };
}

