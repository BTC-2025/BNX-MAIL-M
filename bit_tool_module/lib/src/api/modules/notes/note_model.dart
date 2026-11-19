import 'package:flutter/foundation.dart';

/// Strongly-typed model representing a note record from the Notes API.
@immutable
class NoteModel {
  final String id;
  final String? userEmail;
  final String applicationName;
  final String title;
  final String content;
  final bool isPinned;
  final String color;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<dynamic> items;
  final List<dynamic> tags;

  const NoteModel({
    required this.id,
    this.userEmail,
    this.applicationName = 'Bit Tool',
    this.title = '',
    this.content = '',
    this.isPinned = false,
    this.color = '#A7F3D0',
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.tags = const [],
  });

  String get displayTitle =>
      title.trim().isEmpty ? 'Untitled Note' : title.trim();

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final id = (json['id'] ?? json['_id'] ?? '').toString();
    final userEmail = json['userEmail']?.toString();
    final appName = json['applicationName']?.toString() ??
        json['appName']?.toString() ??
        json['category']?.toString() ??
        'Bit Tool';
    final title = json['title']?.toString() ?? '';
    final content = json['content']?.toString() ?? json['body']?.toString() ?? '';
    final isPinned = json['isPinned'] == true || json['pinned'] == true;
    final color = json['color']?.toString() ?? '#A7F3D0';
    final isArchived = json['isArchived'] == true || json['archived'] == true;

    final items = json['items'] is List ? (json['items'] as List) : const [];
    final tags = json['tags'] is List ? (json['tags'] as List) : const [];

    return NoteModel(
      id: id,
      userEmail: userEmail,
      applicationName: appName,
      title: title,
      content: content,
      isPinned: isPinned,
      color: color,
      isArchived: isArchived,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      items: items,
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userEmail != null) 'userEmail': userEmail,
    'applicationName': applicationName,
    'title': title,
    'content': content,
    'isPinned': isPinned,
    'color': color,
    'isArchived': isArchived,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'items': items,
    'tags': tags,
  };
}

