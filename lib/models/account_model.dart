import 'package:flutter/material.dart';

class AccountModel {
  final String id;
  final String name;
  final String email;
  final Color avatarColor;
  final int unreadCount;
  final bool isActive;
  final String designation;
  final String experience;
  final DateTime? dob;
  final String? avatarUrl;
  final String? recoveryEmail;
  final String? phone;
  final String accountType;
  final String language;
  final String accessibility;

  const AccountModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarColor,
    this.unreadCount = 0,
    this.isActive = false,
    this.designation = '',
    this.experience = '',
    this.dob,
    this.avatarUrl,
    this.recoveryEmail,
    this.phone,
    this.accountType = 'BUSINESS',
    this.language = 'English (US)',
    this.accessibility = 'Default',
  });

  String get avatarLetter => name.isNotEmpty ? name[0].toUpperCase() : '?';

  /// Creates an [AccountModel] from the API response for a mailbox/account entry.
  factory AccountModel.fromJson(
    Map<String, dynamic> json, {
    bool isActive = false,
  }) {
    // Derive a deterministic avatar color from the email string
    final email =
        json['email']?.toString() ??
        json['emailAddress']?.toString() ??
        json['address']?.toString() ??
        '';
    final colorIndex =
        email.codeUnits.fold(0, (sum, c) => sum + c) % _avatarColors.length;
    final color = _avatarColors[colorIndex];

    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final fullName =
        json['name']?.toString() ??
        json['fullName']?.toString() ??
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    DateTime? dob;
    final rawDob = json['dob'] ?? json['dateOfBirth'] ?? json['birthDate'];
    if (rawDob != null) {
      dob = DateTime.tryParse(rawDob.toString());
    }

    return AccountModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? email,
      name: fullName.isNotEmpty ? fullName : email.split('@').first,
      email: email,
      avatarColor: color,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isActive:
          json['isPrimary'] as bool? ?? json['primary'] as bool? ?? isActive,
      designation:
          json['designation']?.toString() ?? json['role']?.toString() ?? '',
      experience: json['experience']?.toString() ?? '',
      dob: dob,
      avatarUrl: (json['avatarUrl']?.toString() ?? json['avatar']?.toString()) ??
          (email.isNotEmpty ? '/api/users/profile-picture/$email' : null),
      recoveryEmail: json['recoveryEmail']?.toString() ?? json['recovery_email']?.toString(),
      phone: json['phone']?.toString() ?? json['phoneNumber']?.toString(),
      accountType: json['accountType']?.toString() ?? 'BUSINESS',
      language: json['language']?.toString() ?? 'English (US)',
      accessibility: json['accessibility']?.toString() ?? 'Default',
    );
  }

  static const List<Color> _avatarColors = [
    Color(0xFF195BAC),
    Color(0xFF22C55E),
    Color(0xFFE11D48),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF10B981),
  ];

  List<String> getKeywords() {
    final Set<String> kws = {
      'job',
      'career',
      'interview',
      'hiring',
      'resume',
      'offer',
      'recruit',
      'position',
      'vacancy',
      'apply',
      'applying',
      'salary',
      'application',
    };

    void addWords(String text) {
      final words = text.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]'));
      for (final word in words) {
        if (word.length > 3) {
          kws.add(word);
        }
      }
    }

    if (designation.isNotEmpty) addWords(designation);
    if (experience.isNotEmpty) addWords(experience);
    return kws.toList();
  }

  AccountModel copyWith({
    String? id,
    String? name,
    String? email,
    Color? avatarColor,
    int? unreadCount,
    bool? isActive,
    String? designation,
    String? experience,
    DateTime? dob,
    String? avatarUrl,
    String? recoveryEmail,
    String? phone,
    String? accountType,
    String? language,
    String? accessibility,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarColor: avatarColor ?? this.avatarColor,
      unreadCount: unreadCount ?? this.unreadCount,
      isActive: isActive ?? this.isActive,
      designation: designation ?? this.designation,
      experience: experience ?? this.experience,
      dob: dob ?? this.dob,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      phone: phone ?? this.phone,
      accountType: accountType ?? this.accountType,
      language: language ?? this.language,
      accessibility: accessibility ?? this.accessibility,
    );
  }
}
