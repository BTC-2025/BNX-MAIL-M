import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../config/api_config.dart';
import 'weather_model.dart';

/// Dedicated service responsible for Weather & Geocoding APIs.
class WeatherApiService {
  final BitToolApiClient _client;

  WeatherApiService({required BitToolApiClient client}) : _client = client;

  /// Retrieves weather forecast data from Open-Meteo.
  Future<WeatherDataModel?> fetchForecast({
    required double latitude,
    required double longitude,
    required String city,
    required String country,
  }) async {
    final uri = BitToolApiConfig.weatherForecastUri(
      latitude: latitude,
      longitude: longitude,
    );

    try {
      final dynamic raw = await _client.get(uri);
      if (raw is Map<String, dynamic>) {
        return WeatherDataModel.fromOpenMeteoJson(
          json: raw,
          latitude: latitude,
          longitude: longitude,
          city: city,
          country: country,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WeatherAPI] fetchForecast error: $e');
    }
    return null;
  }

  /// Resolves location name (city, region/country) from coordinates using BigDataCloud reverse geocoding.
  Future<Map<String, String>> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = BitToolApiConfig.reverseGeocodingUri(
      latitude: latitude,
      longitude: longitude,
    );

    try {
      final dynamic raw = await _client.get(uri);
      if (raw is Map<String, dynamic>) {
        final cityField = raw['city']?.toString().trim() ?? '';
        final localityField = raw['locality']?.toString().trim() ?? '';
        final stateRaw = raw['principalSubdivision'] ?? '';
        final countryRaw = raw['countryName'] ?? '';

        String city = cityField.isNotEmpty ? cityField : localityField;
        String country = stateRaw.toString().trim();
        if (country.isEmpty) {
          country = countryRaw.toString().trim();
        }

        return {
          'city': city.isNotEmpty ? city : 'Unknown Location',
          'country': country.isNotEmpty ? country : 'Unknown Region',
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WeatherAPI] reverseGeocode error: $e');
    }

    return {
      'city': 'Unknown Location',
      'country': 'Unknown Region',
    };
  }
}

