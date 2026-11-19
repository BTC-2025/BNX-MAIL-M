import 'package:flutter/foundation.dart';

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

/// Category tag for calendar events.
@immutable
class CalendarCategory {
  final String id;
  final String name;
  final String color;
  final String? userEmail;
  final String applicationName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalendarCategory({
    required this.id,
    required this.name,
    this.color = '#3B82F6',
    this.userEmail,
    this.applicationName = 'Bit Tool',
    this.createdAt,
    this.updatedAt,
  });

  factory CalendarCategory.fromJson(Map<String, dynamic> json) {
    return CalendarCategory(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#3B82F6',
      userEmail: json['userEmail']?.toString(),
      applicationName: json['applicationName']?.toString() ?? 'Bit Tool',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    if (userEmail != null) 'userEmail': userEmail,
    'applicationName': applicationName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Calendar event model.
@immutable
class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? date;
  final String categoryId;
  final String? userEmail;
  final String applicationName;
  final String? location;
  final CalendarCategory? category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.date,
    required this.categoryId,
    this.userEmail,
    this.applicationName = 'Bit Tool',
    this.location,
    this.category,
    this.createdAt,
    this.updatedAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final start = _parseDateTime(json['startTime'] ?? json['start']) ??
        DateTime.now();
    final end = _parseDateTime(json['endTime'] ?? json['end']) ??
        start.add(const Duration(hours: 1));

    CalendarCategory? cat;
    if (json['category'] is Map<String, dynamic>) {
      cat = CalendarCategory.fromJson(json['category'] as Map<String, dynamic>);
    }

    return CalendarEvent(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      startTime: start,
      endTime: end,
      date: json['date']?.toString(),
      categoryId: (json['categoryId'] ?? json['category_id'] ?? '').toString(),
      userEmail: json['userEmail']?.toString(),
      applicationName: json['applicationName']?.toString() ?? 'Bit Tool',
      location: json['location']?.toString(),
      category: cat,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    if (date != null) 'date': date,
    'categoryId': categoryId,
    if (userEmail != null) 'userEmail': userEmail,
    'applicationName': applicationName,
    if (location != null) 'location': location,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Reminder model linked to a specific date.
@immutable
class CalendarReminder {
  final String id;
  final String title;
  final String date;
  final String time;
  final String description;
  final bool isCompleted;
  final String? userEmail;
  final String applicationName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalendarReminder({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    this.description = '',
    this.isCompleted = false,
    this.userEmail,
    this.applicationName = 'Bit Tool',
    this.createdAt,
    this.updatedAt,
  });

  factory CalendarReminder.fromJson(Map<String, dynamic> json) {
    return CalendarReminder(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isCompleted: json['isCompleted'] == true ||
          json['completed'] == true ||
          json['status'] == 'completed',
      userEmail: json['userEmail']?.toString(),
      applicationName: json['applicationName']?.toString() ?? 'Bit Tool',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'time': time,
    'description': description,
    'isCompleted': isCompleted,
    if (userEmail != null) 'userEmail': userEmail,
    'applicationName': applicationName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Date-linked note model for Calendar.
@immutable
class CalendarDateNote {
  final String id;
  final String title;
  final String date;
  final String content;
  final String? userEmail;
  final String applicationName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalendarDateNote({
    required this.id,
    required this.title,
    required this.date,
    required this.content,
    this.userEmail,
    this.applicationName = 'Bit Tool',
    this.createdAt,
    this.updatedAt,
  });

  factory CalendarDateNote.fromJson(Map<String, dynamic> json) {
    return CalendarDateNote(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      userEmail: json['userEmail']?.toString(),
      applicationName: json['applicationName']?.toString() ?? 'Bit Tool',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'content': content,
    if (userEmail != null) 'userEmail': userEmail,
    'applicationName': applicationName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Global search results across events, reminders, and date notes.
@immutable
class CalendarSearchResult {
  final List<CalendarEvent> events;
  final List<CalendarReminder> reminders;
  final List<CalendarDateNote> notes;

  const CalendarSearchResult({
    this.events = const [],
    this.reminders = const [],
    this.notes = const [],
  });

  factory CalendarSearchResult.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return const [];
    }

    return CalendarSearchResult(
      events: parseList(json['events'], CalendarEvent.fromJson),
      reminders: parseList(json['reminders'], CalendarReminder.fromJson),
      notes: parseList(json['notes'] ?? json['dateNotes'], CalendarDateNote.fromJson),
    );
  }
}

