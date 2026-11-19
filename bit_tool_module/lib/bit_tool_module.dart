library bit_tool_module;

// API Facade, Client, and Configuration
export 'src/api/facade/bit_tool_api_facade.dart';
export 'src/api/client/api_client.dart';
export 'src/api/client/api_exceptions.dart';
export 'src/api/config/api_config.dart';
export 'src/api/config/endpoint_descriptor.dart';
export 'src/api/registry/bit_tool_api_registry.dart';

// API Services
export 'src/api/modules/user_profile/user_profile_api_service.dart';
export 'src/api/modules/contacts/contacts_api_service.dart';
export 'src/api/modules/notes/notes_api_service.dart';
export 'src/api/modules/calendar/calendar_api_service.dart';
export 'src/api/modules/calculator/calculator_api_service.dart';
export 'src/api/modules/notifications/notifications_api_service.dart';
export 'src/api/modules/weather/weather_api_service.dart';
export 'src/api/modules/currency/currency_rate_service.dart';

// Data Models
export 'src/api/modules/user_profile/user_profile_model.dart';
export 'src/api/modules/contacts/contact_model.dart';
export 'src/api/modules/notes/note_model.dart';
export 'src/api/modules/calendar/calendar_models.dart';
export 'src/api/modules/calculator/calculator_models.dart';
export 'src/api/modules/notifications/notification_model.dart';
export 'src/api/modules/weather/weather_model.dart';
export 'src/api/modules/currency/currency_models.dart';

// Riverpod Providers & State
export 'src/providers/bit_tool_providers.dart';

// UI Components
export 'src/ui/bit_tool_right_utility_rail.dart';
export 'src/ui/calculator/bit_tool_calculator.dart';
export 'src/api/ui/bit_tool_api_directory_view.dart';
