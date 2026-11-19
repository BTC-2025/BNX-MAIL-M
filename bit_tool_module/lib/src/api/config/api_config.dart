/// Centralized API configuration and URL resolution for all Bit Tool modules.
///
/// Designed to be embedded into host applications. All endpoints can use
/// default cloud URLs or custom host-specified base URLs.
/// Note: Authentication / Login APIs are intentionally excluded because the host
/// application provides authentication tokens directly.
class BitToolApiConfig {
  /// Base URL for Notifications & general Bit Tool endpoints.
  final String baseUrl;

  /// Base URL for Contacts module endpoints.
  final String contactsBaseUrl;

  /// Base URL for Notes module endpoints.
  final String notesBaseUrl;

  /// Base URL for Calendar module endpoints.
  final String calendarBaseUrl;

  /// Base URL for Calculator module endpoints.
  final String calculatorBaseUrl;

  /// Base URL for User Profile context (no login).
  final String userProfileBaseUrl;

  /// Request timeout duration.
  final Duration timeout;

  const BitToolApiConfig({
    this.baseUrl = 'https://api.bit-tool.com/api',
    this.contactsBaseUrl = 'https://api.bit-tool.com/api/contacts',
    this.notesBaseUrl = 'https://api.bit-tool.com/api/notes',
    this.calendarBaseUrl = 'https://api.bit-tool.com/api/calendar',
    this.calculatorBaseUrl = 'https://api.bit-tool.com/api/calculator',
    this.userProfileBaseUrl = 'https://api.bnxmail.com/api',
    this.timeout = const Duration(seconds: 15),
  });

  /// Normalizes base URL string by removing trailing slashes.
  static String normalize(String url) {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  // --- Contacts URIs ---
  Uri contactsGetUri([Map<String, dynamic>? queryParams]) =>
      _buildUri(contactsBaseUrl, '/get', queryParams);

  Uri contactsGetAllUri([Map<String, dynamic>? queryParams]) =>
      _buildUri(contactsBaseUrl, '/get-all', queryParams);

  Uri contactGetByIdUri(String id) =>
      _buildUri(contactsBaseUrl, '/get/$id');

  Uri get contactAddUri =>
      _buildUri(contactsBaseUrl, '/add');

  Uri contactUpdateUri(String id) =>
      _buildUri(contactsBaseUrl, '/update/$id');

  Uri contactDeleteUri(String id) =>
      _buildUri(contactsBaseUrl, '/delete/$id');

  // --- Notes URIs ---
  Uri notesGetUri({bool allApps = true}) =>
      _buildUri(notesBaseUrl, '', allApps ? {'allApps': 'true'} : null);

  Uri noteGetByIdUri(String id) =>
      _buildUri(notesBaseUrl, '/$id');

  Uri get noteCreateUri =>
      _buildUri(notesBaseUrl, '/create');

  Uri noteUpdateUri(String id) =>
      _buildUri(notesBaseUrl, '/update/$id');

  Uri noteDeleteUri(String id) =>
      _buildUri(notesBaseUrl, '/delete/$id');

  // --- Calendar URIs ---
  Uri get calendarCategoriesUri =>
      _buildUri(calendarBaseUrl, '/categories');

  Uri get calendarCategoryCreateUri =>
      _buildUri(calendarBaseUrl, '/categories');

  Uri calendarEventsMonthUri(int year, int month) =>
      _buildUri(calendarBaseUrl, '/events/month', {
        'year': year.toString(),
        'month': month.toString().padLeft(2, '0'),
      });

  Uri get calendarEventCreateUri =>
      _buildUri(calendarBaseUrl, '/events');

  Uri calendarEventUpdateUri(String id) =>
      _buildUri(calendarBaseUrl, '/events/$id');

  Uri calendarEventDeleteUri(String id) =>
      _buildUri(calendarBaseUrl, '/events/$id');

  Uri calendarRemindersUri(String date) =>
      _buildUri(calendarBaseUrl, '/reminders', {'date': date});

  Uri get calendarReminderCreateUri =>
      _buildUri(calendarBaseUrl, '/reminders');

  Uri calendarReminderUpdateUri(String id) =>
      _buildUri(calendarBaseUrl, '/reminders/$id');

  Uri calendarReminderCompleteUri(String id) =>
      _buildUri(calendarBaseUrl, '/reminders/$id/complete');

  Uri calendarReminderDeleteUri(String id) =>
      _buildUri(calendarBaseUrl, '/reminders/$id');

  Uri calendarNotesUri(String date) =>
      _buildUri(calendarBaseUrl, '/notes', {'date': date});

  Uri get calendarNoteCreateUri =>
      _buildUri(calendarBaseUrl, '/notes');

  Uri calendarNoteUpdateUri(String id) =>
      _buildUri(calendarBaseUrl, '/notes/$id');

  Uri calendarNoteDeleteUri(String id) =>
      _buildUri(calendarBaseUrl, '/notes/$id');

  Uri calendarSearchUri(String query) =>
      _buildUri(calendarBaseUrl, '/search', {'query': query});

  // --- Calculator URIs ---
  Uri get calculatorHistoryUri =>
      _buildUri(calculatorBaseUrl, '/history');

  Uri get calculatorHistoryAllUri =>
      _buildUri(calculatorBaseUrl, '/history/all');

  Uri get calculatorSessionsUri =>
      _buildUri(calculatorBaseUrl, '/sessions');

  Uri calculatorSessionUri(String id) =>
      _buildUri(calculatorBaseUrl, '/sessions/$id');

  Uri calculatorSessionItemsUri(String sessionId) =>
      _buildUri(calculatorBaseUrl, '/sessions/$sessionId/items');

  Uri get calculatorCompareHistoryUri =>
      _buildUri(calculatorBaseUrl, '/compare/history');

  Uri get calculatorCompareSessionsUri =>
      _buildUri(calculatorBaseUrl, '/compare/sessions');

  Uri calculatorCompareSessionUri(String id) =>
      _buildUri(calculatorBaseUrl, '/compare/sessions/$id');

  Uri calculatorCompareSessionItemsUri(String sessionId) =>
      _buildUri(calculatorBaseUrl, '/compare/sessions/$sessionId/items');

  Uri calculatorCompareSessionItemUri(String sessionId, String itemId) =>
      _buildUri(calculatorBaseUrl, '/compare/sessions/$sessionId/items/$itemId');

  // --- Notifications URIs ---
  Uri get notificationsUri =>
      _buildUri(baseUrl, '/notifications');

  Uri notificationReadUri(String id) =>
      _buildUri(baseUrl, '/notifications/$id/read');

  Uri get notificationsReadAllUri =>
      _buildUri(baseUrl, '/notifications/read-all');

  // --- User Profile URI (NO LOGIN) ---
  Uri get userProfileMeUri =>
      _buildUri(userProfileBaseUrl, '/users/me');

  // --- External Weather & Geocoding URIs ---
  static Uri weatherForecastUri({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min'
      '&hourly=temperature_2m'
      '&current=temperature_2m,is_day,relative_humidity_2m,wind_speed_10m'
      '&timezone=auto',
    );
  }

  static Uri reverseGeocodingUri({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse(
      'https://api.bigdatacloud.net/data/reverse-geocode-client'
      '?latitude=$latitude&longitude=$longitude&localityLanguage=en',
    );
  }

  // --- External Currency URIs ---
  static Uri get currencyListUri =>
      Uri.parse('https://api.frankfurter.dev/v2/currencies');

  static Uri currencyRatesUri({required String base, required String quotes}) =>
      Uri.parse('https://api.frankfurter.dev/v2/rates?base=$base&quotes=$quotes');

  // --- Helper URI Builder ---
  static Uri _buildUri(
    String base,
    String path, [
    Map<String, dynamic>? queryParams,
  ]) {
    final cleanBase = normalize(base);
    final cleanPath = path.isEmpty || path == '/'
        ? ''
        : (path.startsWith('/') ? path : '/$path');

    final uri = Uri.parse('$cleanBase$cleanPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      final sanitized = <String, String>{};
      queryParams.forEach((key, val) {
        if (val != null) {
          sanitized[key] = val.toString();
        }
      });
      return uri.replace(queryParameters: sanitized);
    }
    return uri;
  }
}
