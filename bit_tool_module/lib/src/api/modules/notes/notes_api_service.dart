import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../client/api_exceptions.dart';
import '../../config/api_config.dart';
import 'note_model.dart';

/// Dedicated service responsible for Notes module backend communications.
///
/// Base URL: `https://api.bit-tool.com/api/notes` (configurable).
class NotesApiService {
  final BitToolApiClient _client;
  final BitToolApiConfig _config;

  NotesApiService({
    required BitToolApiClient client,
    BitToolApiConfig config = const BitToolApiConfig(),
  })  : _client = client,
        _config = config;

  /// Retrieves notes from the backend, supporting cross-app retrieval via [allApps].
  Future<List<NoteModel>> getNotes({bool allApps = true}) async {
    final uri = _config.notesGetUri(allApps: allApps);

    try {
      final dynamic raw = await _client.get(uri);
      return _extractNotesList(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesAPI] getNotes error: $e');
      rethrow;
    }
  }

  /// Retrieves a single note by its ID via GET /:id.
  Future<NoteModel> getNoteById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw const BitToolApiException('Note ID cannot be empty.');
    }

    final uri = _config.noteGetByIdUri(cleanId);

    try {
      final dynamic raw = await _client.get(uri);
      return _extractSingleNote(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesAPI] getNoteById error: $e');
      rethrow;
    }
  }

  /// Creates a new note on the backend via POST /create.
  Future<NoteModel> createNote({
    required String title,
    required String content,
    String? color,
    bool isPinned = false,
    String? applicationName,
  }) async {
    final uri = _config.noteCreateUri;

    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'color': color ?? '#A7F3D0',
      'isPinned': isPinned,
      if (applicationName != null && applicationName.trim().isNotEmpty)
        'applicationName': applicationName.trim(),
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      return _extractSingleNote(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesAPI] createNote error: $e');
      rethrow;
    }
  }

  /// Updates an existing note via PUT /update/:id.
  Future<NoteModel> updateNote(
    String id, {
    String? title,
    String? content,
    String? color,
    bool? isPinned,
    bool? isArchived,
    String? applicationName,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw const BitToolApiException('Note ID cannot be empty.');
    }

    final uri = _config.noteUpdateUri(cleanId);

    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (color != null) 'color': color,
      if (isPinned != null) 'isPinned': isPinned,
      if (isArchived != null) 'isArchived': isArchived,
      if (applicationName != null && applicationName.trim().isNotEmpty)
        'applicationName': applicationName.trim(),
    };

    try {
      final dynamic raw = await _client.put(uri, body: payload);
      return _extractSingleNote(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesAPI] updateNote error: $e');
      rethrow;
    }
  }

  /// Deletes a note by its backend ID via DELETE /delete/:id.
  Future<bool> deleteNote(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw const BitToolApiException('Note ID cannot be empty.');
    }

    final uri = _config.noteDeleteUri(cleanId);

    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesAPI] deleteNote error: $e');
      rethrow;
    }
  }

  // --- Helper Parsers ---
  List<NoteModel> _extractNotesList(dynamic raw) {
    if (raw == null) return [];
    List<dynamic>? list;

    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      if (raw['data'] is List) list = raw['data'] as List;
      if (raw['notes'] is List) list = raw['notes'] as List;
      if (raw['items'] is List) list = raw['items'] as List;
      if (raw['rows'] is List) list = raw['rows'] as List;
    }

    if (list == null) return [];

    return list
        .whereType<Map>()
        .map((item) => NoteModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  NoteModel _extractSingleNote(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final data = map['data'] ?? map['note'];
      if (data is Map) {
        return NoteModel.fromJson(Map<String, dynamic>.from(data));
      }
      if (map.containsKey('title') || map.containsKey('content')) {
        return NoteModel.fromJson(map);
      }
    }
    throw const BitToolInvalidResponseException(
      'Server returned invalid note payload.',
    );
  }
}

