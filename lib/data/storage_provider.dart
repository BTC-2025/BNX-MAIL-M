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
      StorageDebug.log('[STORAGE NOTIFIER] fetchQuota already in progress, skipping concurrent call');
      return;
    }
    _isFetching = true;
    if (state.hasValue && state.valueOrNull != null) {
      state = AsyncLoading<StorageQuota>().copyWithPrevious(state);
    } else {
      state = const AsyncValue.loading();
    }
    StorageDebug.log('[STORAGE NOTIFIER] fetchQuota started, mounted=$mounted, hasListeners=$hasListeners');
    try {
      final quota = await StorageRepository.fetchStorageQuota();
      StorageDebug.log('[STORAGE NOTIFIER] fetchQuota success: ${quota.email}, used: ${quota.usedFormatted}, limit: ${quota.limitFormatted}, mounted=$mounted');
      if (mounted) {
        state = AsyncValue.data(quota);
        StorageDebug.log('[STORAGE NOTIFIER] state updated to AsyncValue.data, hasListeners=$hasListeners');
      }
    } catch (e, st) {
      StorageDebug.log('[STORAGE NOTIFIER] fetchQuota error: $e, mounted=$mounted');
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() async {
    StorageDebug.log('[STORAGE NOTIFIER] refresh requested');
    _isFetching = false; // Allow manual refresh to proceed
    await fetchQuota();
  }
}

final storageQuotaProvider =
    StateNotifierProvider<StorageQuotaNotifier, AsyncValue<StorageQuota>>((ref) {
  final notifier = StorageQuotaNotifier();

  // Automatically refresh quota when the active account's email changes
  ref.listen<String>(
    activeAccountProvider.select((a) => a.email),
    (previous, next) {
      if (previous != null && previous != next && next.isNotEmpty) {
        notifier.refresh();
      }
    },
  );

  return notifier;
});
