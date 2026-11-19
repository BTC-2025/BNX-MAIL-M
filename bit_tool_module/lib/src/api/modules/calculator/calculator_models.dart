import 'package:flutter/foundation.dart';

double _parseDouble(dynamic val, double fallback) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? fallback;
}

int _parseInt(dynamic val, int fallback) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? fallback;
}

DateTime? _parseDateTime(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  try {
    return DateTime.parse(val.toString());
  } catch (_) {
    return null;
  }
}

/// A persisted calculator tape operation item.
@immutable
class CalculatorTapeItem {
  final String id;
  final String? sessionId;
  final int sequence;
  final double value;
  final String operator;
  final double runningTotal;
  final String? label;
  final DateTime? createdAt;

  const CalculatorTapeItem({
    required this.id,
    this.sessionId,
    required this.sequence,
    required this.value,
    required this.operator,
    required this.runningTotal,
    this.label,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    if (sessionId != null) 'sessionId': sessionId,
    'sequence': sequence,
    'value': value,
    'operator': operator,
    'runningTotal': runningTotal,
    'label': label ?? '',
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory CalculatorTapeItem.fromJson(Map<String, dynamic> json) {
    return CalculatorTapeItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      sessionId:
          json['sessionId']?.toString() ?? json['session_id']?.toString(),
      sequence: _parseInt(json['sequence'] ?? json['seq'], 1),
      value: _parseDouble(json['value'], 0.0),
      operator: (json['operator'] ?? json['op'] ?? '+').toString(),
      runningTotal: _parseDouble(
        json['runningTotal'] ?? json['running_total'] ?? json['total'],
        0.0,
      ),
      label: json['label']?.toString(),
      createdAt: _parseDateTime(
        json['createdAt'] ?? json['created_at'] ?? json['timestamp'],
      ),
    );
  }
}

/// A persisted standard calculator session.
@immutable
class CalculatorSession {
  final String id;
  final String title;
  final String mode;
  final String currency;
  final String applicationName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? totalAmount;
  final int? itemCount;
  final List<CalculatorTapeItem> items;

  const CalculatorSession({
    required this.id,
    required this.title,
    this.mode = 'business',
    this.currency = 'INR',
    this.applicationName = 'Bit Tool',
    this.createdAt,
    this.updatedAt,
    this.totalAmount,
    this.itemCount,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mode': mode,
    'currency': currency,
    'applicationName': applicationName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (totalAmount != null) 'totalAmount': totalAmount,
    if (itemCount != null) 'itemCount': itemCount,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory CalculatorSession.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['tape_items'] ?? json['data'];
    final itemsList = <CalculatorTapeItem>[];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is Map) {
          try {
            itemsList.add(
              CalculatorTapeItem.fromJson(Map<String, dynamic>.from(rawItem)),
            );
          } catch (_) {}
        }
      }
      itemsList.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    final rawTitle = (json['title'] ?? 'Tape - Untitled').toString();
    final total = _parseDouble(
      json['totalAmount'] ??
          json['total_amount'] ??
          json['runningTotal'] ??
          json['total'],
      itemsList.isNotEmpty ? itemsList.last.runningTotal : 0.0,
    );

    return CalculatorSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: rawTitle,
      mode: (json['mode'] ?? 'business').toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      applicationName: (json['applicationName'] ?? 'Bit Tool').toString(),
      createdAt: _parseDateTime(
        json['createdAt'] ?? json['created_at'] ?? json['timestamp'],
      ),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
      totalAmount: total,
      itemCount: json['itemCount'] is int
          ? json['itemCount'] as int
          : itemsList.length,
      items: itemsList,
    );
  }
}

/// A line item in a compare session.
@immutable
class CompareItem {
  final String id;
  final String? sessionId;
  final String description;
  final double? valueA;
  final double? valueB;
  final double qtyA;
  final double qtyB;
  final double discountA;
  final double discountB;
  final int sequence;
  final DateTime? createdAt;

  const CompareItem({
    required this.id,
    this.sessionId,
    required this.description,
    this.valueA,
    this.valueB,
    this.qtyA = 1.0,
    this.qtyB = 1.0,
    this.discountA = 0.0,
    this.discountB = 0.0,
    this.sequence = 1,
    this.createdAt,
  });

  double get finalA {
    final base = (valueA ?? 0.0) * qtyA;
    return base - (base * (discountA / 100.0));
  }

  double get finalB {
    final base = (valueB ?? 0.0) * qtyB;
    return base - (base * (discountB / 100.0));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (sessionId != null) 'sessionId': sessionId,
    'description': description,
    if (valueA != null) 'valueA': valueA,
    if (valueB != null) 'valueB': valueB,
    'qtyA': qtyA,
    'qtyB': qtyB,
    'discountA': discountA,
    'discountB': discountB,
    'sequence': sequence,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory CompareItem.fromJson(Map<String, dynamic> json) {
    return CompareItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      sessionId:
          json['sessionId']?.toString() ?? json['session_id']?.toString(),
      description: (json['description'] ?? json['name'] ?? '').toString(),
      valueA: json['valueA'] != null ? _parseDouble(json['valueA'], 0.0) : null,
      valueB: json['valueB'] != null ? _parseDouble(json['valueB'], 0.0) : null,
      qtyA: _parseDouble(json['qtyA'], 1.0),
      qtyB: _parseDouble(json['qtyB'], 1.0),
      discountA: _parseDouble(json['discountA'], 0.0),
      discountB: _parseDouble(json['discountB'], 0.0),
      sequence: _parseInt(json['sequence'] ?? json['seq'], 1),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
    );
  }
}

/// A persisted compare mode session.
@immutable
class CompareSession {
  final String id;
  final String title;
  final String mode;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<CompareItem> items;

  const CompareSession({
    required this.id,
    required this.title,
    this.mode = 'compare',
    this.currency = 'INR',
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mode': mode,
    'currency': currency,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory CompareSession.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['compare_items'] ?? json['rows'];
    final itemsList = <CompareItem>[];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is Map) {
          try {
            itemsList.add(
              CompareItem.fromJson(Map<String, dynamic>.from(rawItem)),
            );
          } catch (_) {}
        }
      }
      itemsList.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    return CompareSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? 'Comparison - Untitled').toString(),
      mode: (json['mode'] ?? 'compare').toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
      items: itemsList,
    );
  }
}

