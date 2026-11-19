import 'package:flutter/foundation.dart';

/// Hourly forecast item.
@immutable
class WeatherHourlyItem {
  final DateTime time;
  final double temperature;

  const WeatherHourlyItem({required this.time, required this.temperature});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'temperature': temperature,
  };
}

/// Daily forecast summary.
@immutable
class WeatherDailyItem {
  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;

  const WeatherDailyItem({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weatherCode': weatherCode,
    'maxTemp': maxTemp,
    'minTemp': minTemp,
  };
}

/// Current live conditions.
@immutable
class WeatherCurrentModel {
  final double temperature;
  final int isDay;
  final int weatherCode;
  final double humidity;
  final double windSpeed;

  const WeatherCurrentModel({
    required this.temperature,
    required this.isDay,
    required this.weatherCode,
    required this.humidity,
    required this.windSpeed,
  });

  String get condition {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Cloudy';
    }
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'isDay': isDay,
    'weatherCode': weatherCode,
    'humidity': humidity,
    'windSpeed': windSpeed,
    'condition': condition,
  };
}

/// Complete weather data model.
@immutable
class WeatherDataModel {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final WeatherCurrentModel current;
  final List<WeatherDailyItem> daily;
  final List<WeatherHourlyItem> hourly;

  const WeatherDataModel({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.current,
    this.daily = const [],
    this.hourly = const [],
  });

  factory WeatherDataModel.fromOpenMeteoJson({
    required Map<String, dynamic> json,
    required double latitude,
    required double longitude,
    required String city,
    required String country,
  }) {
    final curMap = (json['current'] as Map<String, dynamic>?) ?? {};
    final cur = WeatherCurrentModel(
      temperature: (curMap['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      isDay: (curMap['is_day'] as num?)?.toInt() ?? 1,
      weatherCode: (curMap['weathercode'] as num?)?.toInt() ?? 0,
      humidity: (curMap['relative_humidity_2m'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (curMap['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
    );

    final dailyList = <WeatherDailyItem>[];
    if (json['daily'] is Map<String, dynamic>) {
      final d = json['daily'] as Map<String, dynamic>;
      final times = (d['time'] as List?) ?? [];
      final codes = (d['weathercode'] as List?) ?? [];
      final maxs = (d['temperature_2m_max'] as List?) ?? [];
      final mins = (d['temperature_2m_min'] as List?) ?? [];

      for (int i = 0; i < times.length; i++) {
        dailyList.add(
          WeatherDailyItem(
            date: DateTime.tryParse(times[i].toString()) ?? DateTime.now(),
            weatherCode: (codes.length > i ? codes[i] as num? : 0)?.toInt() ?? 0,
            maxTemp: (maxs.length > i ? maxs[i] as num? : 0)?.toDouble() ?? 0.0,
            minTemp: (mins.length > i ? mins[i] as num? : 0)?.toDouble() ?? 0.0,
          ),
        );
      }
    }

    final hourlyList = <WeatherHourlyItem>[];
    if (json['hourly'] is Map<String, dynamic>) {
      final h = json['hourly'] as Map<String, dynamic>;
      final times = (h['time'] as List?) ?? [];
      final temps = (h['temperature_2m'] as List?) ?? [];

      for (int i = 0; i < times.length && i < 24; i++) {
        hourlyList.add(
          WeatherHourlyItem(
            time: DateTime.tryParse(times[i].toString()) ?? DateTime.now(),
            temperature: (temps.length > i ? temps[i] as num? : 0)?.toDouble() ?? 0.0,
          ),
        );
      }
    }

    return WeatherDataModel(
      latitude: latitude,
      longitude: longitude,
      city: city,
      country: country,
      current: cur,
      daily: dailyList,
      hourly: hourlyList,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'city': city,
    'country': country,
    'current': current.toJson(),
    'daily': daily.map((d) => d.toJson()).toList(),
    'hourly': hourly.map((h) => h.toJson()).toList(),
  };
}

