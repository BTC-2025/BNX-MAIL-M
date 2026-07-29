import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/token_service.dart';
import '../models/email_model.dart';
import 'repositories/mail_repository.dart';

class AllInboxesState {
  final List<EmailModel> emails;
  final bool isLoading;
  final String? error;
  final Set<String> failedAccounts;

  const AllInboxesState({
    this.emails = const [],
    this.isLoading = false,
    this.error,
    this.failedAccounts = const {},
  });

  AllInboxesState copyWith({
    List<EmailModel>? emails,
    bool? isLoading,
    String? error,
    Set<String>? failedAccounts,
  }) =>
      AllInboxesState(
        emails: emails ?? this.emails,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        failedAccounts: failedAccounts ?? this.failedAccounts,
      );
}

class AllInboxesNotifier extends StateNotifier<AllInboxesState> {
  Timer? _autoRefreshTimer;
  bool _isFetching = false;

  AllInboxesNotifier() : super(const AllInboxesState()) {
    // Start background auto-refresh timer every 15 seconds for instant background sync
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && state.emails.isNotEmpty) {
        loadAllInboxes(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Merges Inbox emails from all logged-in accounts into a single sorted virtual inbox list.
  /// When [silent] is true or [state.emails] is non-empty, updates seamlessly in the background without UI spinners.
  Future<void> loadAllInboxes({bool forceRefresh = false, bool silent = false}) async {
    if (_isFetching) return;

    _isFetching = true;
    
    // Only show full loading spinner if we have no cached emails in memory
    if (state.emails.isEmpty && !silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final savedRegistry = await TokenService.getSavedAccountsFromRegistry();
      final activeEmail = await TokenService.getUserEmail();
      final activeToken = await TokenService.getAccessToken();

      final accountsMap = <String, String>{};

      // 1. Include current active account session
      if (activeEmail != null && activeEmail.isNotEmpty && activeToken != null && activeToken.isNotEmpty) {
        accountsMap[activeEmail.trim().toLowerCase()] = activeToken;
      }

      // 2. Include all saved registry accounts
      for (final acc in savedRegistry) {
        final email = acc['email']?.toString().trim().toLowerCase() ?? '';
        final token = acc['accessToken']?.toString() ?? '';
        if (email.isNotEmpty && token.isNotEmpty) {
          accountsMap[email] = token;
        }
      }

      if (accountsMap.isEmpty) {
        state = state.copyWith(isLoading: false, emails: []);
        _isFetching = false;
        return;
      }

      print('[ALL INBOXES AUTO-SYNC] Fetching Inbox in parallel for ${accountsMap.length} accounts: ${accountsMap.keys.toList()}');

      final failedAccounts = <String>{};
      final entries = accountsMap.entries.toList();

      // Parallel execution across all logged-in accounts
      final results = await Future.wait(entries.map((entry) async {
        try {
          final list = await MailRepository.fetchFolderWithToken(
            entry.value,
            'Inbox',
            limit: 50,
            ownerEmail: entry.key,
          );
          return MapEntry(entry.key, list);
        } catch (e) {
          print('[ALL INBOXES WARNING] Failed to fetch Inbox for account "${entry.key}": $e');
          failedAccounts.add(entry.key);
          return MapEntry(entry.key, <EmailModel>[]);
        }
      }));

      final mergedMap = <String, EmailModel>{};

      for (final result in results) {
        final ownerEmail = result.key;
        final folderList = result.value;
        for (final email in folderList) {
          final ownedEmail = email.ownerEmail == null || email.ownerEmail!.isEmpty
              ? email.copyWith(ownerEmail: ownerEmail)
              : email;
          final key = '${ownedEmail.ownerEmail}_${ownedEmail.canonicalKey}';
          mergedMap[key] = ownedEmail;
        }
      }

      final mergedList = mergedMap.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      print('[ALL INBOXES SYNC COMPLETE] Total merged emails: ${mergedList.length} across ${accountsMap.length} accounts.');

      state = state.copyWith(
        emails: mergedList,
        isLoading: false,
        failedAccounts: failedAccounts,
      );
    } catch (e) {
      print('[ALL INBOXES ERROR] Failed to load all inboxes: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _isFetching = false;
    }
  }

  void updateEmail(EmailModel updated) {
    final keyToFind = '${updated.ownerEmail}_${updated.canonicalKey}';
    final updatedList = state.emails.map((e) {
      final key = '${e.ownerEmail}_${e.canonicalKey}';
      return (key == keyToFind || e.id == updated.id) ? updated : e;
    }).toList();
    state = state.copyWith(emails: updatedList);
  }

  void removeEmail(String id) {
    state = state.copyWith(
      emails: state.emails.where((e) => e.id != id).toList(),
    );
  }

  void clear() {
    state = const AllInboxesState();
  }
}

final allInboxesProvider =
    StateNotifierProvider<AllInboxesNotifier, AllInboxesState>((ref) {
  return AllInboxesNotifier();
});
