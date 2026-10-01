import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_exception.dart';
import '../models/blocked_contact_model.dart';
import 'account_provider.dart';
import 'repositories/subscription_repository.dart';

/// State for the isolated Subscription feature.
class SubscriptionState {
  final List<BlockedContact> blockedContacts;
  final bool isLoading;
  final String? error;
  final Set<String> pendingEmails;

  const SubscriptionState({
    this.blockedContacts = const [],
    this.isLoading = false,
    this.error,
    this.pendingEmails = const {},
  });

  /// Set of blocked contact emails in lower-case for fast O(1) status lookup.
  Set<String> get blockedEmailsSet =>
      blockedContacts.map((c) => c.email.toLowerCase().trim()).toSet();

  SubscriptionState copyWith({
    List<BlockedContact>? blockedContacts,
    bool? isLoading,
    String? error,
    Set<String>? pendingEmails,
  }) {
    return SubscriptionState(
      blockedContacts: blockedContacts ?? this.blockedContacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingEmails: pendingEmails ?? this.pendingEmails,
    );
  }
}

/// Notifier handling Subscription business logic and API state.
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final Ref _ref;
  String? _currentAccountId;

  SubscriptionNotifier(this._ref, {String? accountId})
      : _currentAccountId = accountId,
        super(const SubscriptionState());

  /// Loads the list of blocked/unsubscribed contacts from GET /api/blocked-contacts.
  Future<void> loadBlockedContacts({bool force = false}) async {
    final activeAcc = _ref.read(activeAccountProvider);
    final activeId = activeAcc.id;

    // Prevent duplicate concurrent requests unless forced
    if (!force && state.isLoading) return;

    // If account changed, clear state immediately
    if (_currentAccountId != null && _currentAccountId != activeId) {
      _currentAccountId = activeId;
      state = const SubscriptionState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final contacts = await SubscriptionRepository.getBlockedContacts();
      _currentAccountId = activeId;
      state = state.copyWith(
        blockedContacts: contacts,
        isLoading: false,
        error: null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Unsubscribes from a sender: POST /api/blocked-contacts.
  /// Updates local state only after a successful 2xx backend response.
  Future<({bool success, String? message})> unsubscribe(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return (success: false, message: 'Invalid email address');
    }

    final emailLower = cleanEmail.toLowerCase();
    state = state.copyWith(
      pendingEmails: {...state.pendingEmails, emailLower},
    );

    try {
      await SubscriptionRepository.unsubscribe(cleanEmail);

      // Only on successful API response: add to blocked contacts
      final updatedList = List<BlockedContact>.from(state.blockedContacts);
      if (!updatedList.any((c) => c.email.toLowerCase().trim() == emailLower)) {
        updatedList.add(
          BlockedContact(email: cleanEmail, blockedAt: DateTime.now()),
        );
      }

      final updatedPending = Set<String>.from(state.pendingEmails)
        ..remove(emailLower);

      state = state.copyWith(
        blockedContacts: updatedList,
        pendingEmails: updatedPending,
      );

      return (success: true, message: null);
    } on ApiException catch (e) {
      final updatedPending = Set<String>.from(state.pendingEmails)
        ..remove(emailLower);
      state = state.copyWith(pendingEmails: updatedPending);
      return (success: false, message: e.message);
    } catch (e) {
      final updatedPending = Set<String>.from(state.pendingEmails)
        ..remove(emailLower);
      state = state.copyWith(pendingEmails: updatedPending);
      return (success: false, message: e.toString());
    }
  }

  /// Re-subscribes to a sender: DELETE /api/blocked-contacts/{email}.
  /// Updates local state only after a successful 2xx backend response.
  Future<({bool success, String? message})> subscribe(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return (success: false, message: 'Invalid email address');
    }

    final emailLower = cleanEmail.toLowerCase();
    state = state.copyWith(
      pendingEmails: {...state.pendingEmails, emailLower},
    );

    try {
      await SubscriptionRepository.subscribe(cleanEmail);

      // Only on successful API response: remove from blocked contacts
      final updatedList = state.blockedContacts
          .where((c) => c.email.toLowerCase().trim() != emailLower)
          .toList();

      final updatedPending = Set<String>.from(state.pendingEmails)
        ..remove(emailLower);

      state = state.copyWith(
        blockedContacts: updatedList,
        pendingEmails: updatedPending,
      );

      return (success: true, message: null);
    } on ApiException catch (e) {
      final updatedPending = Set<String>.from(state.pendingEmails)
        ..remove(emailLower);
      state = state.copyWith(pendingEmails: updatedPending);
      return (success: false, message: e.message);
    } catch (e) {
      final updatedPending = Set<String>.from(state.pendingEmails)
        ..remove(emailLower);
      state = state.copyWith(pendingEmails: updatedPending);
      return (success: false, message: e.toString());
    }
  }

  /// Clears state when switching accounts or signing out.
  void clear() {
    _currentAccountId = null;
    state = const SubscriptionState();
  }
}

/// Dedicated provider for Subscription & Blocked Contacts.
/// Watches `activeAccountProvider` to automatically reload state on account switches.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final activeAccount = ref.watch(activeAccountProvider);
  final notifier = SubscriptionNotifier(ref, accountId: activeAccount.id);
  // Proactively trigger initial load for the active account
  notifier.loadBlockedContacts();
  return notifier;
});
