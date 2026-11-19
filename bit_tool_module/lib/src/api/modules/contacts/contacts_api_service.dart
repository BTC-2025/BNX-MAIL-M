import 'package:flutter/foundation.dart';
import '../../client/api_client.dart';
import '../../client/api_exceptions.dart';
import '../../config/api_config.dart';
import 'contact_model.dart';

/// Dedicated service responsible for Contacts module API communications.
///
/// Base URL: `https://api.bit-tool.com/api/contacts` (configurable).
class ContactsApiService {
  final BitToolApiClient _client;
  final BitToolApiConfig _config;

  ContactsApiService({
    required BitToolApiClient client,
    BitToolApiConfig config = const BitToolApiConfig(),
  })  : _client = client,
        _config = config;

  /// Retrieves paginated contacts via GET /get.
  Future<PaginatedContactsResult> getPaginatedContacts({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final uri = _config.contactsGetUri(queryParams);

    try {
      final dynamic raw = await _client.get(uri);
      return _parsePaginatedResponse(raw, page: page, limit: limit);
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsAPI] getPaginatedContacts error: $e');
      rethrow;
    }
  }

  /// Retrieves all contacts via GET /get-all across integrated applications.
  Future<List<ContactModel>> getAllContacts({int pageSize = 100}) async {
    final List<ContactModel> allContacts = [];
    final Set<String> seenIds = {};
    int offset = 0;
    int? totalCount;

    try {
      while (true) {
        final queryParams = <String, dynamic>{
          'offset': offset,
          'limit': pageSize,
        };

        final uri = _config.contactsGetAllUri(queryParams);
        final dynamic raw = await _client.get(uri);
        final List<ContactModel> batch = _extractContactsList(raw);

        if (raw is Map<String, dynamic>) {
          var countRaw = raw['count'] ?? raw['total'] ?? raw['totalRecords'] ?? raw['totalCount'];
          if (raw['data'] is Map<String, dynamic>) {
            final dataMap = raw['data'] as Map<String, dynamic>;
            countRaw ??= dataMap['count'] ?? dataMap['total'] ?? dataMap['totalRecords'] ?? dataMap['totalCount'];
          }
          if (countRaw is int) {
            totalCount = countRaw;
          } else if (countRaw != null) {
            totalCount = int.tryParse(countRaw.toString());
          }
        }

        for (final contact in batch) {
          if (contact.id.isEmpty || seenIds.add(contact.id)) {
            allContacts.add(contact);
          }
        }

        final bool hasMore = batch.length >= pageSize &&
            (totalCount == null || (offset + batch.length) < totalCount);

        if (!hasMore || batch.isEmpty) {
          break;
        }

        offset += batch.length;
      }

      return allContacts;
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsAPI] getAllContacts error: $e');
      rethrow;
    }
  }

  /// Retrieves a single contact by ID via GET /get/:id.
  Future<ContactModel> getContactById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw const BitToolApiException('Contact ID cannot be empty.');
    }

    final uri = _config.contactGetByIdUri(cleanId);

    try {
      final dynamic raw = await _client.get(uri);
      if (raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw['contact'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ContactModel.fromJson(data);
        }
      }
      throw const BitToolInvalidResponseException(
        'Server returned an invalid contact record format.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsAPI] getContactById error: $e');
      rethrow;
    }
  }

  /// Creates a contact via POST /add.
  Future<ContactModel> createContact({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? company,
    String? notes,
    String? role,
  }) async {
    final uri = _config.contactAddUri;
    final fullName = ('$firstName $lastName').trim();
    final cleanEmail = (email ?? '').trim();

    final payload = <String, dynamic>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      if (cleanEmail.isNotEmpty) 'email': cleanEmail,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
      'name': fullName,
      'phonenumber': phone ?? '',
    };

    try {
      final dynamic raw = await _client.post(uri, body: payload);
      if (raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw['contact'];
        if (data is Map<String, dynamic>) {
          return ContactModel.fromJson(data);
        }
        if (raw.containsKey('firstName') || raw.containsKey('email') || raw.containsKey('name')) {
          return ContactModel.fromJson(raw);
        }
      }
      return ContactModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: firstName,
        lastName: lastName,
        email: email ?? '',
        phone: phone ?? '',
        company: company ?? '',
        notes: notes ?? '',
        role: role ?? '',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsAPI] createContact error: $e');
      rethrow;
    }
  }

  /// Updates an existing contact via PUT /update/:id.
  Future<ContactModel> updateContact(
    String id, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? company,
    String? notes,
    String? role,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw const BitToolApiException('Contact ID cannot be empty.');
    }

    final uri = _config.contactUpdateUri(cleanId);
    final payload = <String, dynamic>{
      if (firstName != null) 'firstName': firstName.trim(),
      if (lastName != null) 'lastName': lastName.trim(),
      if (email != null) 'email': email.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (company != null) 'company': company.trim(),
      if (notes != null) 'notes': notes.trim(),
      if (role != null) 'role': role.trim(),
    };

    try {
      final dynamic raw = await _client.put(uri, body: payload);
      if (raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw['contact'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ContactModel.fromJson(data);
        }
      }
      return ContactModel(
        id: cleanId,
        firstName: firstName ?? '',
        lastName: lastName ?? '',
        email: email ?? '',
        phone: phone ?? '',
        company: company ?? '',
        notes: notes ?? '',
        role: role ?? '',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsAPI] updateContact error: $e');
      rethrow;
    }
  }

  /// Deletes a contact via DELETE /delete/:id.
  Future<bool> deleteContact(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw const BitToolApiException('Contact ID cannot be empty.');
    }

    final uri = _config.contactDeleteUri(cleanId);

    try {
      await _client.delete(uri);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ContactsAPI] deleteContact error: $e');
      rethrow;
    }
  }

  // --- Helper Parsers ---
  List<ContactModel> _extractContactsList(dynamic raw) {
    if (raw == null) return [];
    List<dynamic>? list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      if (raw['rows'] is List) list = raw['rows'] as List;
      if (raw['data'] is List) list = raw['data'] as List;
      if (raw['contacts'] is List) list = raw['contacts'] as List;
      if (raw['data'] is Map && raw['data']['rows'] is List) {
        list = raw['data']['rows'] as List;
      }
    }
    if (list == null) return [];

    return list
        .whereType<Map>()
        .map((item) => ContactModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  PaginatedContactsResult _parsePaginatedResponse(
    dynamic raw, {
    required int page,
    required int limit,
  }) {
    final contacts = _extractContactsList(raw);
    int totalCount = contacts.length;

    if (raw is Map) {
      final count = raw['count'] ?? raw['total'] ?? raw['totalCount'];
      if (count is int) totalCount = count;
      if (raw['data'] is Map) {
        final subCount = raw['data']['count'] ?? raw['data']['total'];
        if (subCount is int) totalCount = subCount;
      }
    }

    final totalPages = (totalCount / limit).ceil().clamp(1, 999999);

    return PaginatedContactsResult(
      contacts: contacts,
      page: page,
      limit: limit,
      totalCount: totalCount,
      totalPages: totalPages,
    );
  }
}

