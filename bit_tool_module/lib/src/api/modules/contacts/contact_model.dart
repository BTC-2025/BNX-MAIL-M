import 'package:flutter/foundation.dart';

/// Strongly-typed model for contacts in the Bit Tool Contacts API.
@immutable
class ContactModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String company;
  final String notes;
  final String role;
  final String department;
  final String location;
  final String photoUrl;
  final String applicationName;
  final bool isFavorite;
  final bool isBlocked;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ContactModel({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.company = '',
    this.notes = '',
    this.role = '',
    this.department = '',
    this.location = '',
    this.photoUrl = '',
    this.applicationName = '',
    this.isFavorite = false,
    this.isBlocked = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Computed full name combining firstName and lastName.
  String get fullName {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '$first $last';
    } else if (first.isNotEmpty) {
      return first;
    } else if (last.isNotEmpty) {
      return last;
    }
    if (email.trim().isNotEmpty) return email.trim();
    if (phone.trim().isNotEmpty) return phone.trim();
    return 'Unnamed Contact';
  }

  /// Initial letter for avatars.
  String get initial {
    final clean = fullName.trim();
    if (clean.isNotEmpty && clean != 'Unnamed Contact') {
      return clean[0].toUpperCase();
    }
    return '?';
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    String cleanString(dynamic value) {
      if (value == null) return '';
      final str = value.toString().trim();
      if (str.toLowerCase() == 'null') return '';
      return str;
    }

    var first = cleanString(json['firstName']);
    var last = cleanString(json['lastName']);

    if (first.isEmpty && last.isEmpty && json.containsKey('name')) {
      final rawName = cleanString(json['name']);
      final parts = rawName.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        first = parts.first;
        if (parts.length > 1) {
          last = parts.sublist(1).join(' ');
        }
      }
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return ContactModel(
      id: cleanString(json['id'].toString().isNotEmpty ? json['id'] : json['_id']),
      firstName: first,
      lastName: last,
      email: cleanString(json['email']),
      phone: cleanString(
        json['phone'].toString().isNotEmpty
            ? json['phone']
            : (json['phoneNumber'] ?? json['phonenumber']),
      ),
      company: cleanString(json['company'] ?? json['organization']),
      notes: cleanString(json['notes']),
      role: cleanString(json['role'] ?? json['designation']),
      department: cleanString(json['department']),
      location: cleanString(json['location'] ?? json['address']),
      photoUrl: cleanString(
        json['photoUrl'] ?? json['avatarUrl'] ?? json['profilePictureUrl'],
      ),
      applicationName: cleanString(
        json['applicationName'] ?? json['appName'] ?? 'Bit Tool',
      ),
      isFavorite: json['isFavorite'] == true || json['favorite'] == true,
      isBlocked: json['isBlocked'] == true || json['blocked'] == true,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'company': company,
    'notes': notes,
    'role': role,
    'department': department,
    'location': location,
    'photoUrl': photoUrl,
    'applicationName': applicationName,
    'isFavorite': isFavorite,
    'isBlocked': isBlocked,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Paginated result wrapper for GET /get endpoint.
class PaginatedContactsResult {
  final List<ContactModel> contacts;
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;

  const PaginatedContactsResult({
    required this.contacts,
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

