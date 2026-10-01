import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/storage_repository.dart';
import 'account_provider.dart';

class StorageQuotaNotifier extends StateNotifier<AsyncValue<StorageQuota>> {
  static StorageQuotaNotifier? instance;
  bool _isFetching = false;

  StorageQuotaNotifier() : super(const AsyncValue.loading()) {
    instance = this;
    StorageDebug.log('[STORAGE NOTIFIER] Initialized in constructor');
    fetchQuota();
  }

  @override
  void dispose() {
    StorageDebug.log('[STORAGE NOTIFIER] DISPOSE CALLED, mounted=$mounted');
    if (instance == this) instance = null;
    super.dispose();
  }

  Future<void> fetchQuota() async {
    if (_isFetching) {
      StorageDebug.log('[STORAGE] Duplicate request prevented');
      return;
    }
    _isFetching = true;
    if (state.hasValue && state.valueOrNull != null) {
      state = AsyncLoading<StorageQuota>().copyWithPrevious(state);
    } else {
      state = const AsyncValue.loading();
    }
    try {
      final quota = await StorageRepository.fetchStorageQuota();
      if (mounted) {
        state = AsyncValue.data(quota);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() async {
    if (_isFetching) {
      StorageDebug.log('[STORAGE] Duplicate request prevented');
      return;
    }
    await fetchQuota();
  }

  /// Called when the active email account changes.
  /// Immediately clears old account quota state so stale values are never shown for the new account.
  Future<void> onAccountSwitched() async {
    StorageDebug.log('[STORAGE] Account switch detected, resetting quota');
    state = const AsyncValue.loading();
    _isFetching = false;
    StorageRepository.resetInFlight();
    await fetchQuota();
  }
}

final storageQuotaProvider =
    StateNotifierProvider<StorageQuotaNotifier, AsyncValue<StorageQuota>>((ref) {
  final notifier = StorageQuotaNotifier();

  // Automatically reset and refresh quota when the active account's email changes
  ref.listen<String>(
    activeAccountProvider.select((a) => a.email),
    (previous, next) {
      if (previous != null && previous != next && next.isNotEmpty) {
        notifier.onAccountSwitched();
      }
    },
  );

  return notifier;
});
