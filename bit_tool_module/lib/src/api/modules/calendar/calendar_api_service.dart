import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../config/api_config.dart';
import 'calendar_models.dart';

/// Dedicated service responsible for Calendar module API communications.
///
/// Base URL: `https://api.bit-tool.com/api/calendar` (configurable).
class CalendarApiService {
  final BitToolApiClient _client;
  final BitToolApiConfig _config;

  CalendarApiService({
    required BitToolApiClient client,
    BitToolApiConfig config = const BitToolApiConfig(),
  })  : _client = client,
        _config = config;

  // --- Categories API ---

  /// Fetches event categories via GET /categories.
  Future<List<CalendarCategory>> getCategories() async {
    final uri = _config.calendarCategoriesUri;
    try {
      final dynamic raw = await _client.get(uri);
      return _extractList(raw)
          .whereType<Map<String, dynamic>>()
          .map(CalendarCategory.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] getCategories error: $e');
      rethrow;
    }
  }

  /// Creates a new event category via POST /categories.
  Future<CalendarCategory> createCategory({
    required String name,
    required String color,
  }) async {
    final uri = _config.calendarCategoryCreateUri;
    final payload = {'name': name.trim(), 'color': color.trim()};

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CalendarCategory.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] createCategory error: $e');
      rethrow;
    }
  }

  // --- Events API ---

  /// Fetches events for a specific month and year via GET /events/month?year={YYYY}&month={MM}.
  Future<List<CalendarEvent>> getMonthEvents({
    required int year,
    required int month,
  }) async {
    final uri = _config.calendarEventsMonthUri(year, month);
    try {
      final dynamic raw = await _client.get(uri);
      final rawList = _extractList(raw);
      final events = <CalendarEvent>[];
      for (final item in rawList) {
        if (item is Map) {
          try {
            events.add(CalendarEvent.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
      return events;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] getMonthEvents error: $e');
      rethrow;
    }
  }

  /// Creates a calendar event via POST /events.
  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String categoryId,
    String? description,
    String? location,
  }) async {
    final uri = _config.calendarEventCreateUri;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'categoryId': categoryId.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CalendarEvent.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] createEvent error: $e');
      rethrow;
    }
  }

  /// Updates a calendar event via PUT /events/:id.
  Future<CalendarEvent> updateEvent(
    String id, {
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? categoryId,
    String? description,
    String? location,
  }) async {
    final uri = _config.calendarEventUpdateUri(id);
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime.toIso8601String(),
      if (categoryId != null) 'categoryId': categoryId.trim(),
      if (description != null) 'description': description.trim(),
      if (location != null) 'location': location.trim(),
    };

    try {
      final dynamic raw = await _client.put(uri, body: payload);
      final data = _extractMap(raw);
      return CalendarEvent.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] updateEvent error: $e');
      rethrow;
    }
  }

  /// Deletes a calendar event via DELETE /events/:id.
  Future<bool> deleteEvent(String id) async {
    final uri = _config.calendarEventDeleteUri(id);
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] deleteEvent error: $e');
      rethrow;
    }
  }

  // --- Reminders API ---

  /// Fetches reminders for a specific date (YYYY-MM-DD) via GET /reminders?date={YYYY-MM-DD}.
  Future<List<CalendarReminder>> getReminders(String date) async {
    final uri = _config.calendarRemindersUri(date);
    try {
      final dynamic raw = await _client.get(uri);
      return _extractList(raw)
          .whereType<Map<String, dynamic>>()
          .map(CalendarReminder.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] getReminders error: $e');
      rethrow;
    }
  }

  /// Creates a reminder via POST /reminders.
  Future<CalendarReminder> createReminder({
    required String title,
    required String date,
    required String time,
    String? description,
  }) async {
    final uri = _config.calendarReminderCreateUri;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'date': date.trim(),
      'time': time.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CalendarReminder.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] createReminder error: $e');
      rethrow;
    }
  }

  /// Updates a reminder via PUT /reminders/:id.
  Future<CalendarReminder> updateReminder(
    String id, {
    String? title,
    String? date,
    String? time,
    String? description,
  }) async {
    final uri = _config.calendarReminderUpdateUri(id);
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (date != null) 'date': date.trim(),
      if (time != null) 'time': time.trim(),
      if (description != null) 'description': description.trim(),
    };

    try {
      final dynamic raw = await _client.put(uri, body: payload);
      final data = _extractMap(raw);
      return CalendarReminder.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] updateReminder error: $e');
      rethrow;
    }
  }

  /// Marks a reminder as completed via PUT /reminders/:id/complete.
  Future<CalendarReminder> completeReminder(String id) async {
    final uri = _config.calendarReminderCompleteUri(id);
    try {
      final dynamic raw = await _client.put(uri);
      final data = _extractMap(raw);
      return CalendarReminder.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] completeReminder error: $e');
      rethrow;
    }
  }

  /// Deletes a reminder via DELETE /reminders/:id.
  Future<bool> deleteReminder(String id) async {
    final uri = _config.calendarReminderDeleteUri(id);
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] deleteReminder error: $e');
      rethrow;
    }
  }

  // --- Date-Linked Notes API ---

  /// Fetches date-linked notes via GET /notes?date={YYYY-MM-DD}.
  Future<List<CalendarDateNote>> getDateNotes(String date) async {
    final uri = _config.calendarNotesUri(date);
    try {
      final dynamic raw = await _client.get(uri);
      return _extractList(raw)
          .whereType<Map<String, dynamic>>()
          .map(CalendarDateNote.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] getDateNotes error: $e');
      rethrow;
    }
  }

  /// Creates a date-linked note via POST /notes.
  Future<CalendarDateNote> createDateNote({
    required String title,
    required String date,
    required String content,
  }) async {
    final uri = _config.calendarNoteCreateUri;
    final payload = {
      'title': title.trim(),
      'date': date.trim(),
      'content': content.trim(),
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      final data = _extractMap(raw);
      return CalendarDateNote.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] createDateNote error: $e');
      rethrow;
    }
  }

  /// Updates a date-linked note via PUT /notes/:id.
  Future<CalendarDateNote> updateDateNote(
    String id, {
    String? title,
    String? content,
  }) async {
    final uri = _config.calendarNoteUpdateUri(id);
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (content != null) 'content': content.trim(),
    };

    try {
      final dynamic raw = await _client.put(uri, body: payload);
      final data = _extractMap(raw);
      return CalendarDateNote.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] updateDateNote error: $e');
      rethrow;
    }
  }

  /// Deletes a date-linked note via DELETE /notes/:id.
  Future<bool> deleteDateNote(String id) async {
    final uri = _config.calendarNoteDeleteUri(id);
    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] deleteDateNote error: $e');
      rethrow;
    }
  }

  // --- Search API ---

  /// Performs a global calendar search via GET /search?query={search_term}.
  Future<CalendarSearchResult> searchCalendar(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const CalendarSearchResult();

    final uri = _config.calendarSearchUri(trimmed);
    try {
      final dynamic raw = await _client.get(uri);
      final data = _extractMap(raw);
      return CalendarSearchResult.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[CalendarAPI] searchCalendar error: $e');
      rethrow;
    }
  }

  // --- Helper Envelope Extractors ---
  List<dynamic> _extractList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw;
    if (raw is Map) {
      if (raw['data'] is List) return raw['data'] as List;
      if (raw['events'] is List) return raw['events'] as List;
      if (raw['categories'] is List) return raw['categories'] as List;
      if (raw['reminders'] is List) return raw['reminders'] as List;
      if (raw['notes'] is List) return raw['notes'] as List;
      if (raw['data'] is Map) {
        final sub = raw['data'] as Map;
        if (sub['events'] is List) return sub['events'] as List;
        if (sub['categories'] is List) return sub['categories'] as List;
        if (sub['reminders'] is List) return sub['reminders'] as List;
        if (sub['notes'] is List) return sub['notes'] as List;
      }
    }
    return const [];
  }

  Map<String, dynamic> _extractMap(dynamic raw) {
    if (raw == null) return const {};
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }
    return const {};
  }
}
