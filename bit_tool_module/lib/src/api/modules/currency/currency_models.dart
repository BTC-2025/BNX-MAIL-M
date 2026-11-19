import 'package:flutter/foundation.dart';

/// Supported currency definition.
@immutable
class CurrencyItem {
  final String code;
  final String name;
  final String symbol;
  final String countryOrRegion;
  final String flag;

  const CurrencyItem({
    required this.code,
    required this.name,
    required this.symbol,
    required this.countryOrRegion,
    required this.flag,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'symbol': symbol,
    'countryOrRegion': countryOrRegion,
    'flag': flag,
  };
}

/// Exchange rate result between a base and quote currency.
@immutable
class CurrencyRate {
  final String base;
  final String quote;
  final double rate;
  final DateTime date;
  final DateTime fetchedAt;

  const CurrencyRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.date,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'base': base,
    'quote': quote,
    'rate': rate,
    'date': date.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };
}

