import 'package:http/http.dart' as http;

import '../client/api_client.dart';
import '../config/api_config.dart';
import '../config/endpoint_descriptor.dart';
import '../modules/calculator/calculator_api_service.dart';
import '../modules/calendar/calendar_api_service.dart';
import '../modules/contacts/contacts_api_service.dart';
import '../modules/currency/currency_rate_service.dart';
import '../modules/notes/notes_api_service.dart';
import '../modules/notifications/notifications_api_service.dart';
import '../modules/user_profile/user_profile_api_service.dart';
import '../modules/weather/weather_api_service.dart';
import '../registry/bit_tool_api_registry.dart';

/// Unified entrypoint for integrating Bit Tool module APIs into a host application.
///
/// Authentication is decoupled: provide a [tokenProvider] callback or [staticToken]
/// from the host app (such as Cliks Business). Login APIs are intentionally excluded.
class BitToolApiModule {
  final BitToolApiConfig config;
  final BitToolApiClient client;

  // Feature Module Services
  final ContactsApiService contacts;
  final NotesApiService notes;
  final CalendarApiService calendar;
  final CalculatorApiService calculator;
  final NotificationsApiService notifications;
  final WeatherApiService weather;
  final CurrencyRateService currency;
  final UserProfileApiService userProfile;

  BitToolApiModule({
    BitToolApiConfig? config,
    BitToolTokenProvider? tokenProvider,
    String? staticToken,
    http.Client? customHttpClient,
  })  : config = config ?? const BitToolApiConfig(),
        client = BitToolApiClient(
          client: customHttpClient,
          tokenProvider: tokenProvider,
          staticToken: staticToken,
          timeout: config?.timeout ?? const Duration(seconds: 15),
        ),
        contacts = ContactsApiService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
          config: config ?? const BitToolApiConfig(),
        ),
        notes = NotesApiService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
          config: config ?? const BitToolApiConfig(),
        ),
        calendar = CalendarApiService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
          config: config ?? const BitToolApiConfig(),
        ),
        calculator = CalculatorApiService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
          config: config ?? const BitToolApiConfig(),
        ),
        notifications = NotificationsApiService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
          config: config ?? const BitToolApiConfig(),
        ),
        weather = WeatherApiService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
        ),
        currency = CurrencyRateService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
        ),
        userProfile = UserProfileApiService(
          client: BitToolApiClient(
            client: customHttpClient,
            tokenProvider: tokenProvider,
            staticToken: staticToken,
            timeout: config?.timeout ?? const Duration(seconds: 15),
          ),
          config: config ?? const BitToolApiConfig(),
        );

  /// Access to the central API metadata registry listing all module endpoints.
  List<EndpointDescriptor> get allEndpoints => BitToolApiRegistry.allEndpoints;

  /// Returns endpoints filtered by module name.
  List<EndpointDescriptor> getEndpointsByModule(String module) =>
      BitToolApiRegistry.getEndpointsByModule(module);

  /// Searches endpoints by keyword.
  List<EndpointDescriptor> searchEndpoints(String query) =>
      BitToolApiRegistry.search(query);
}

