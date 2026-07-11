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
  });

  String get avatarLetter => name.isNotEmpty ? name[0].toUpperCase() : '?';

  List<String> getKeywords() {
    final Set<String> kws = {
      'job', 'career', 'interview', 'hiring', 'resume', 'offer', 'recruit',
      'position', 'vacancy', 'apply', 'applying', 'salary', 'application'
    };

    void addWords(String text) {
      final words = text.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]'));
      for (final word in words) {
        if (word.length > 3) {
          kws.add(word);
        }
      }
    }

    if (designation.isNotEmpty) {
      addWords(designation);
    }
    if (experience.isNotEmpty) {
      addWords(experience);
    }
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
    );
  }
}
