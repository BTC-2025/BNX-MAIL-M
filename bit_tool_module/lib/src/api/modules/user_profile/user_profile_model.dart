import 'package:flutter/foundation.dart';

/// Organization metadata linked to the authenticated user.
@immutable
class OrganizationInfo {
  final int id;
  final String name;

  const OrganizationInfo({required this.id, required this.name});

  factory OrganizationInfo.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is num)
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    return OrganizationInfo(id: id, name: json['name']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Read-only user profile model fetched from GET /api/users/me.
/// NOTE: Login credentials/APIs are strictly omitted.
@immutable
class UserProfileModel {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? profilePictureUrl;
  final String? role;
  final String? accountType;
  final num? storageUsed;
  final num? storageLimit;
  final bool isPrimary;
  final String? phoneNumber;
  final String? recoveryEmail;
  final OrganizationInfo? organization;

  const UserProfileModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    this.profilePictureUrl,
    this.role,
    this.accountType,
    this.storageUsed,
    this.storageLimit,
    this.isPrimary = false,
    this.phoneNumber,
    this.recoveryEmail,
    this.organization,
  });

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!.trim();
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first.isNotEmpty) return first;
    return email;
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is num)
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    OrganizationInfo? org;
    if (json['organization'] is Map<String, dynamic>) {
      org = OrganizationInfo.fromJson(
        json['organization'] as Map<String, dynamic>,
      );
    }

    return UserProfileModel(
      id: id,
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      fullName: json['fullName']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString() ??
          json['avatarUrl']?.toString(),
      role: json['role']?.toString(),
      accountType: json['accountType']?.toString(),
      storageUsed: json['storageUsed'] as num?,
      storageLimit: json['storageLimit'] as num?,
      isPrimary: json['isPrimary'] == true,
      phoneNumber: json['phoneNumber']?.toString(),
      recoveryEmail: json['recoveryEmail']?.toString(),
      organization: org,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (fullName != null) 'fullName': fullName,
    if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
    if (role != null) 'role': role,
    if (accountType != null) 'accountType': accountType,
    if (storageUsed != null) 'storageUsed': storageUsed,
    if (storageLimit != null) 'storageLimit': storageLimit,
    'isPrimary': isPrimary,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (recoveryEmail != null) 'recoveryEmail': recoveryEmail,
    if (organization != null) 'organization': organization!.toJson(),
  };
}

