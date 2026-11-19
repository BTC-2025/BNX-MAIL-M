import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../config/api_config.dart';
import 'currency_models.dart';

/// Dedicated service for live currency rates and listings via Frankfurter public API.
class CurrencyRateService {
  final BitToolApiClient _client;
  final Map<String, CurrencyRate> _rateCache = {};

  CurrencyRateService({required BitToolApiClient client}) : _client = client;

  /// Guaranteed fallback currency list.
  static const List<CurrencyItem> defaultFallbackCurrencies = [
    CurrencyItem(code: 'USD', name: 'US Dollar', symbol: '\$', countryOrRegion: 'United States', flag: '🇺🇸'),
    CurrencyItem(code: 'INR', name: 'Indian Rupee', symbol: '₹', countryOrRegion: 'India', flag: '🇮🇳'),
    CurrencyItem(code: 'EUR', name: 'Euro', symbol: '€', countryOrRegion: 'European Union', flag: '🇪🇺'),
    CurrencyItem(code: 'GBP', name: 'British Pound', symbol: '£', countryOrRegion: 'United Kingdom', flag: '🇬🇧'),
    CurrencyItem(code: 'JPY', name: 'Japanese Yen', symbol: '¥', countryOrRegion: 'Japan', flag: '🇯🇵'),
    CurrencyItem(code: 'CAD', name: 'Canadian Dollar', symbol: '\$', countryOrRegion: 'Canada', flag: '🇨🇦'),
    CurrencyItem(code: 'AUD', name: 'Australian Dollar', symbol: '\$', countryOrRegion: 'Australia', flag: '🇦🇺'),
    CurrencyItem(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', countryOrRegion: 'UAE', flag: '🇦🇪'),
    CurrencyItem(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', countryOrRegion: 'Singapore', flag: '🇸🇬'),
  ];

  /// Retrieves supported currencies.
  Future<List<CurrencyItem>> getCurrencies() async {
    final uri = BitToolApiConfig.currencyListUri;
    try {
      final dynamic raw = await _client.get(uri);
      if (raw is Map<String, dynamic>) {
        final list = <CurrencyItem>[];
        raw.forEach((code, name) {
          list.add(
            CurrencyItem(
              code: code,
              name: name.toString(),
              symbol: code,
              countryOrRegion: code,
              flag: '🌐',
            ),
          );
        });
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CurrencyAPI] getCurrencies error: $e');
    }
    return defaultFallbackCurrencies;
  }

  /// Fetches live exchange rate for a given base and quote currency.
  Future<CurrencyRate?> getExchangeRate({
    required String from,
    required String to,
  }) async {
    final cleanFrom = from.trim().toUpperCase();
    final cleanTo = to.trim().toUpperCase();

    if (cleanFrom == cleanTo) {
      return CurrencyRate(
        base: cleanFrom,
        quote: cleanTo,
        rate: 1.0,
        date: DateTime.now(),
        fetchedAt: DateTime.now(),
      );
    }

    final cacheKey = '${cleanFrom}_$cleanTo';
    final cached = _rateCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMinutes < 30) {
      return cached;
    }

    final uri = BitToolApiConfig.currencyRatesUri(base: cleanFrom, quotes: cleanTo);

    try {
      final dynamic raw = await _client.get(uri);
      if (raw is Map<String, dynamic>) {
        final rates = raw['rates'];
        if (rates is Map && rates.containsKey(cleanTo)) {
          final rateVal = (rates[cleanTo] as num).toDouble();
          final dateVal = DateTime.tryParse(raw['date']?.toString() ?? '') ?? DateTime.now();

          final result = CurrencyRate(
            base: cleanFrom,
            quote: cleanTo,
            rate: rateVal,
            date: dateVal,
            fetchedAt: DateTime.now(),
          );
          _rateCache[cacheKey] = result;
          return result;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CurrencyAPI] getExchangeRate error: $e');
    }

    return null;
  }
}

