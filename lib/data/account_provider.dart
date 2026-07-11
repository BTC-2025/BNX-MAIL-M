import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_model.dart';

class AccountsNotifier extends StateNotifier<List<AccountModel>> {
  AccountsNotifier()
      : super([
          AccountModel(
            id: 'acc_1',
            name: 'Ravi Kumar C',
            email: 'ravikumar123@bnxmail.com',
            avatarColor: const Color(0xFF1D4ED8),
            unreadCount: 12,
            isActive: true,
            designation: 'Flutter Developer',
            experience: 'Experienced with Riverpod, Bloc, dynamic UI, and local databases',
            dob: DateTime(1996, 7, 15),
          ),
          AccountModel(
            id: 'acc_2',
            name: 'Ravi Work',
            email: 'ravi.work@techcorp.com',
            avatarColor: const Color(0xFF059669),
            unreadCount: 5,
            isActive: false,
            designation: 'Lead Architect',
            experience: 'Specialized in building micro-services and scalable backend systems',
            dob: DateTime(1993, 3, 20),
          ),
          AccountModel(
            id: 'acc_3',
            name: 'Ravi Personal',
            email: 'ravi.personal@gmail.com',
            avatarColor: const Color(0xFF7C3AED),
            unreadCount: 3,
            isActive: false,
            designation: 'UI/UX Designer',
            experience: 'Experienced in Figma prototypes, design systems, and web aesthetics',
            dob: DateTime(1998, 11, 5),
          ),
        ]);

  String get activeAccountId =>
      state.firstWhere((a) => a.isActive, orElse: () => state.first).id;

  AccountModel get activeAccount =>
      state.firstWhere((a) => a.isActive, orElse: () => state.first);

  void switchAccount(String id) {
    state = state.map((acc) => acc.copyWith(isActive: acc.id == id)).toList();
  }

  void markAccountRead(String id) {
    state = state
        .map((acc) => acc.id == id ? acc.copyWith(unreadCount: 0) : acc)
        .toList();
  }

  void updateProfile(
    String id, {
    required String name,
    required String designation,
    required String experience,
    DateTime? dob,
  }) {
    state = state.map((acc) {
      if (acc.id == id) {
        return acc.copyWith(
          name: name,
          designation: designation,
          experience: experience,
          dob: dob,
        );
      }
      return acc;
    }).toList();
  }
}

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, List<AccountModel>>((ref) {
  return AccountsNotifier();
});

/// Convenience provider: returns just the active account
final activeAccountProvider = Provider<AccountModel>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.firstWhere((a) => a.isActive, orElse: () => accounts.first);
});
