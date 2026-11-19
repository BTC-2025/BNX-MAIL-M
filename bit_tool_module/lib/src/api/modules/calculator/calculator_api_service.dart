import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../config/api_config.dart';
import 'calculator_models.dart';

/// Dedicated service responsible for Calculator backend API communications.
///
/// Supports Standard Calculator History and Compare Mode History endpoints.
/// Base URL: `https://api.bit-tool.com/api/calculator` (configurable).
class CalculatorApiService {
  final BitToolApiClient _client;
  final BitToolApiConfig _config;

  CalculatorApiService({
    required BitToolApiClient client,
    BitToolApiConfig config = const BitToolApiConfig(),
  })  : _client = client,
        _config = config;

  // ==========================================
  // Standard Calculator History Endpoints
  // ==========================================

  /// Fetches saved calculator history sessions via GET /history.
  Future<List<CalculatorSession>> getHistory() async {
    final uri = _config.calculatorHistoryUri;
    try {
      final dynamic raw = await _client.get(uri);
      if (kDebugMode) debugPrint('[CalculatorAPI] GET $uri response: $raw');
      var rawList = _extractList(raw);
      if (rawList.isEmpty) {
        try {
          final dynamic rawAll = await _client.get(_config.calculatorHistoryAllUri);
          if (kDebugMode) debugPrint('[CalculatorAPI] GET ${_config.calculatorHistoryAllUri} response: $rawAll');
          final allList = _extractList(rawAll);
          if (allList.isNotEmpty) {
            rawList = allList;
          }
        } catch (_) {}
      }
      final sessions = <CalculatorSession>[];

      for (final item in rawList) {
        if (item is Map) {
          try {
            sessions.add(
              CalculatorSession.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (e) {
            if (kDebugMode) debugPrint('[CalculatorAPI] Session parsing error: $e, item: $item');
          }
        }
      }
      return sessions;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] getHistory error: $e');
      rethrow;
    }
  }

  /// Fetches cross-app calculator history sessions across all apps via GET /history/all.
  Future<List<CalculatorSession>> getHistoryAll() async {
    final uri = _config.calculatorHistoryAllUri;
    try {
      final dynamic raw = await _client.get(uri);
      final rawList = _extractList(raw);
      final sessions = <CalculatorSession>[];

      for (final item in rawList) {
        if (item is Map) {
          try {
            sessions.add(
              CalculatorSession.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
      }
      return sessions;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] getHistoryAll error: $e');
      rethrow;
    }
  }

  /// Creates a standard calculator session via POST /sessions.
  Future<CalculatorSession> createSession({
    required String title,
    String mode = 'business',
    String currency = 'INR',
    String? applicationName,
  }) async {
    final uri = _config.calculatorSessionsUri;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'mode': mode.trim(),
      'currency': currency.trim(),
      if (applicationName != null && applicationName.trim().isNotEmpty)
        'applicationName': applicationName.trim(),
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CalculatorSession.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] createSession error: $e');
      rethrow;
    }
  }

  /// Adds a tape item to an existing calculator session via POST /sessions/:sessionId/items.
  Future<CalculatorTapeItem> addSessionItem({
    required String sessionId,
    required int sequence,
    required double value,
    required String operator,
    required double runningTotal,
    String label = '',
  }) async {
    final uri = _config.calculatorSessionItemsUri(sessionId);
    final payload = <String, dynamic>{
      'sequence': sequence,
      'value': value,
      'operator': operator,
      'runningTotal': runningTotal,
      'label': label.trim(),
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CalculatorTapeItem.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] addSessionItem error: $e');
      rethrow;
    }
  }

  /// Fetches details and items for a specific session via GET /sessions/:id.
  Future<CalculatorSession> getSessionById(String id) async {
    final uri = _config.calculatorSessionUri(id);
    try {
      final dynamic raw = await _client.get(uri);
      final data = _extractMap(raw);
      return CalculatorSession.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] getSessionById error: $e');
      rethrow;
    }
  }

  /// Deletes a specific calculator session via DELETE /sessions/:id.
  Future<bool> deleteSession(String id) async {
    final uri = _config.calculatorSessionUri(id);
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] deleteSession error: $e');
      rethrow;
    }
  }

  /// Clears all standard calculator sessions via DELETE /sessions.
  Future<bool> clearAllSessions() async {
    final uri = _config.calculatorSessionsUri;
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] clearAllSessions error: $e');
      rethrow;
    }
  }

  // ==========================================
  // Compare Mode History Endpoints
  // ==========================================

  /// Fetches comparison history via GET /compare/history.
  Future<List<CompareSession>> getCompareHistory() async {
    final uri = _config.calculatorCompareHistoryUri;
    try {
      final dynamic raw = await _client.get(uri);
      final rawList = _extractList(raw);
      final sessions = <CompareSession>[];

      for (final item in rawList) {
        if (item is Map) {
          try {
            sessions.add(
              CompareSession.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
      }
      return sessions;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] getCompareHistory error: $e');
      rethrow;
    }
  }

  /// Creates a compare session via POST /compare/sessions.
  Future<CompareSession> createCompareSession({
    required String title,
    String mode = 'compare',
    String currency = 'INR',
  }) async {
    final uri = _config.calculatorCompareSessionsUri;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'mode': mode.trim(),
      'currency': currency.trim(),
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CompareSession.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] createCompareSession error: $e');
      rethrow;
    }
  }

  /// Adds a compare item via POST /compare/sessions/:sessionId/items.
  Future<CompareItem> addCompareItem({
    required String sessionId,
    required String description,
    double? valueA,
    double? valueB,
    double qtyA = 1.0,
    double qtyB = 1.0,
    double discountA = 0.0,
    double discountB = 0.0,
    int sequence = 1,
  }) async {
    final uri = _config.calculatorCompareSessionItemsUri(sessionId);
    final payload = <String, dynamic>{
      'description': description.trim(),
      if (valueA != null) 'valueA': valueA,
      if (valueB != null) 'valueB': valueB,
      'qtyA': qtyA,
      'qtyB': qtyB,
      'discountA': discountA,
      'discountB': discountB,
      'sequence': sequence,
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CompareItem.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] addCompareItem error: $e');
      rethrow;
    }
  }

  /// Updates a compare item via PUT /compare/sessions/:sessionId/items/:itemId.
  Future<CompareItem> updateCompareItem({
    required String sessionId,
    required String itemId,
    String? description,
    double? valueA,
    double? valueB,
    double? qtyA,
    double? qtyB,
    double? discountA,
    double? discountB,
    int? sequence,
  }) async {
    final uri = _config.calculatorCompareSessionItemUri(sessionId, itemId);
    final payload = <String, dynamic>{
      if (description != null) 'description': description.trim(),
      if (valueA != null) 'valueA': valueA,
      if (valueB != null) 'valueB': valueB,
      if (qtyA != null) 'qtyA': qtyA,
      if (qtyB != null) 'qtyB': qtyB,
      if (discountA != null) 'discountA': discountA,
      if (discountB != null) 'discountB': discountB,
      if (sequence != null) 'sequence': sequence,
    };

    try {
      final dynamic raw = await _client.put(uri, body: payload);
      final data = _extractMap(raw);
      return CompareItem.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] updateCompareItem error: $e');
      rethrow;
    }
  }

  /// Deletes a compare item via DELETE /compare/sessions/:sessionId/items/:itemId.
  Future<bool> deleteCompareItem({
    required String sessionId,
    required String itemId,
  }) async {
    final uri = _config.calculatorCompareSessionItemUri(sessionId, itemId);
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] deleteCompareItem error: $e');
      rethrow;
    }
  }

  /// Deletes a compare session via DELETE /compare/sessions/:id.
  Future<bool> deleteCompareSession(String id) async {
    final uri = _config.calculatorCompareSessionUri(id);
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] deleteCompareSession error: $e');
      rethrow;
    }
  }

  /// Clears all compare history via DELETE /compare/history.
  Future<bool> clearCompareHistory() async {
    final uri = _config.calculatorCompareHistoryUri;
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalculatorAPI] clearCompareHistory error: $e');
      rethrow;
    }
  }

  // --- Helpers ---
  Map<String, dynamic> _extractMap(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['data'] is Map) return Map<String, dynamic>.from(map['data'] as Map);
      if (map['session'] is Map) return Map<String, dynamic>.from(map['session'] as Map);
      if (map['item'] is Map) return Map<String, dynamic>.from(map['item'] as Map);
      return map;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['rows'] is List) return map['rows'] as List;
      if (map['data'] is List) return map['data'] as List;
      if (map['sessions'] is List) return map['sessions'] as List;
      if (map['history'] is List) return map['history'] as List;
      if (map['items'] is List) return map['items'] as List;
      if (map['records'] is List) return map['records'] as List;
      if (map['list'] is List) return map['list'] as List;
      if (map['results'] is List) return map['results'] as List;
      if (map['payload'] is List) return map['payload'] as List;
      if (map['data'] is Map) {
        final d = Map<String, dynamic>.from(map['data'] as Map);
        if (d['rows'] is List) return d['rows'] as List;
        if (d['data'] is List) return d['data'] as List;
        if (d['sessions'] is List) return d['sessions'] as List;
        if (d['history'] is List) return d['history'] as List;
        if (d['records'] is List) return d['records'] as List;
        if (d['list'] is List) return d['list'] as List;
        if (d['results'] is List) return d['results'] as List;
        if (d['items'] is List) return d['items'] as List;
        if (d['payload'] is List) return d['payload'] as List;
      }
    }
    return [];
  }
}
