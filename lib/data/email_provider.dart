import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/email_model.dart';
import '../models/attachment_model.dart';
import 'repositories/mail_repository.dart';
import 'repositories/label_repository.dart';
import '../models/label_model.dart';
import '../core/network/token_service.dart';
import '../core/notifications/notification_service.dart';
import '../core/notifications/notification_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class EmailState {
  final List<EmailModel> emails;
  final bool isLoading;
  final String? error;
  final Set<String> loadedFolders;

  const EmailState({
    this.emails = const [],
    this.isLoading = false,
    this.error,
    this.loadedFolders = const {},
  });

  EmailState copyWith({
    List<EmailModel>? emails,
    bool? isLoading,
    String? error,
    Set<String>? loadedFolders,
  }) => EmailState(
    emails: emails ?? this.emails,
    isLoading: isLoading ?? this.isLoading,
    error: error, // null clears the error
    loadedFolders: loadedFolders ?? this.loadedFolders,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class EmailNotifier extends StateNotifier<EmailState> {
  final Map<String, EmailState> _accountCaches = {};
  String _currentAccountId = 'default';

  EmailNotifier() : super(const EmailState()) {
    _startPolling();
  }

  Timer? _pollingTimer;
  bool _isDispatchingScheduled = false;
  final Set<String> _dispatchingIds = {};

  void clear() {
    _pollingTimer?.cancel();
    state = const EmailState();
    _accountCaches.clear();
  }

  Future<void> switchAccountContext(String accountId) async {
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
    }
    _currentAccountId = accountId;
    if (_accountCaches.containsKey(accountId)) {
      state = _accountCaches[accountId]!;
      initialLoad(background: true);
    } else {
      state = const EmailState();
      initialLoad();
    }
  }

  // ── Initial load (called right after successful login) ──────────────────

  /// Fetches all folders in parallel so sidebar badge counts work.
  /// Fetches Inbox immediately so user sees Primary Inbox in <150ms, then hydrates remaining folders in background.
  Future<void> initialLoad({bool background = false}) async {
    if (!background) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      print('[FAST LOAD] Fetching Primary Inbox first...');
      final inboxList = await MailRepository.fetchFolder(
        'Inbox',
        limit: 50,
      ).catchError((_) => <EmailModel>[]);

      final merged = <String, EmailModel>{};
      for (final e in state.emails) {
        merged[e.canonicalKey] = e;
      }
      for (final e in inboxList) {
        final key = e.canonicalKey;
        if (merged.containsKey(key)) {
          final existing = merged[key]!;
          final updatedFolders = existing.memberOfFolders.union(
            e.memberOfFolders.isEmpty ? {'Inbox'} : e.memberOfFolders,
          );
          merged[key] = e.copyWith(memberOfFolders: updatedFolders);
        } else {
          merged[key] = e.copyWith(
            memberOfFolders: e.memberOfFolders.isEmpty
                ? {'Inbox'}
                : e.memberOfFolders,
          );
        }
      }

      final savedLabelsMap = await TokenService.getAssignedEmailLabels();
      if (savedLabelsMap.isNotEmpty) {
        for (final entry in merged.entries) {
          final e = entry.value;
          final stored =
              savedLabelsMap[e.id] ??
              (e.messageId != null ? savedLabelsMap[e.messageId] : null);
          if (stored != null && stored.isNotEmpty) {
            final combined = Set<String>.from(e.labels)..addAll(stored);
            merged[entry.key] = e.copyWith(labels: combined.toList());
          }
        }
      }

      // Render Primary Inbox IMMEDIATELY!
      state = state.copyWith(
        emails: merged.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
        isLoading: false,
        loadedFolders: {'Inbox'},
      );

      print(
        '[FAST LOAD] Primary Inbox rendered (${inboxList.length} emails). Hydrating secondary folders in background...',
      );

      // Hydrate remaining folders in parallel in background without blocking UI
      final remainingFolders = [
        'Sent',
        'Draft',
        'Starred',
        'Archive',
        'Spam',
        'Trash',
        'Snoozed',
        'Scheduled',
      ];

      Future.wait(
        remainingFolders.map((folderName) async {
          try {
            final list = await MailRepository.fetchFolder(
              folderName,
              limit: 30,
            );
            if (list.isNotEmpty) {
              _mergeFolderResults(folderName, list);
            }
          } catch (_) {}
        }),
      ).then((_) {
        print('[FAST LOAD] All secondary folders hydrated successfully.');
      });

      _startPolling();
    } catch (e) {
      print('[INITIAL LOAD ERROR] $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void _mergeFolderResults(String folderName, List<EmailModel> folderList) {
    final merged = <String, EmailModel>{};
    for (final e in state.emails) {
      merged[e.canonicalKey] = e;
    }

    for (final e in folderList) {
      final key = e.canonicalKey;
      if (merged.containsKey(key)) {
        final existing = merged[key]!;
        final bool isArchivedInState =
            existing.isArchive || existing.memberOfFolders.contains('Archive');
        final updatedFolders = existing.memberOfFolders.union(
          e.memberOfFolders.isEmpty ? {folderName} : e.memberOfFolders,
        );
        if (isArchivedInState) {
          updatedFolders.remove('Inbox');
        }

        final bool isNowStarred =
            existing.isStarred || e.isStarred || folderName == 'Starred';
        if (isNowStarred) {
          updatedFolders.add('Starred');
        }

        merged[key] = existing.copyWith(
          isStarred: isNowStarred,
          isSnoozed:
              existing.isSnoozed || e.isSnoozed || folderName == 'Snoozed',
          isScheduled:
              existing.isScheduled ||
              e.isScheduled ||
              folderName == 'Scheduled',
          labels: (existing.labels.toSet()..addAll(e.labels)).toList(),
          isSent: existing.isSent || (folderName == 'Sent' || e.isSent),
          isDraft: existing.isDraft || (folderName == 'Draft' || e.isDraft),
          isTrash: existing.isTrash || (folderName == 'Trash' || e.isTrash),
          isArchive:
              isArchivedInState || (folderName == 'Archive' || e.isArchive),
          isSpam: existing.isSpam || (folderName == 'Spam' || e.isSpam),
          memberOfFolders: updatedFolders,
        );
      } else {
        merged[key] = e.copyWith(
          memberOfFolders: e.memberOfFolders.isEmpty
              ? {folderName}
              : e.memberOfFolders,
        );
      }
    }

    _deduplicateDrafts(merged);
    _deduplicateSent(merged);

    final updatedLoaded = Set<String>.from(state.loadedFolders)
      ..add(folderName);
    state = state.copyWith(
      emails: merged.values.toList()..sort((a, b) => b.date.compareTo(a.date)),
      loadedFolders: updatedLoaded,
    );
  }

  // ── Periodic automatic Inbox & Scheduled Email synchronization ───────────

  bool _isSyncing = false;

  void _startPolling() {
    _pollingTimer?.cancel();
    // Synchronize inbox & auto-dispatch due scheduled mails every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      syncInbox();
      checkAndDispatchScheduledMails();
    });
  }

  /// Automatic background Inbox synchronization.
  /// Runs without modifying UI loading state or interrupting user interaction.
  Future<void> syncInbox() async {
    if (_isSyncing) {
      print(
        '[AUTO-SYNC] Previous sync cycle still running. Skipping to prevent race conditions.',
      );
      return;
    }

    _isSyncing = true;
    try {
      final token = NotificationService.instance.fcmToken;
      if (token != null && token.isNotEmpty) {
        print('[FCM TOKEN] Device Token: $token');
      }
      final fetched = await MailRepository.fetchFolder('Inbox', limit: 50);
      if (fetched.isEmpty) {
        _isSyncing = false;
        return;
      }

      bool hasChanges = false;
      final merged = <String, EmailModel>{};
      for (final e in state.emails) {
        merged[e.canonicalKey] = e;
      }

      final now = DateTime.now();

      for (final e in fetched) {
        final key = e.canonicalKey;
        if (merged.containsKey(key)) {
          final existing = merged[key]!;
          final DateTime effectiveDate =
              (e.isDateFallback && !existing.isDateFallback)
              ? existing.date
              : e.date;

          final bool dateChanged = effectiveDate != existing.date;
          final bool readChanged = e.isRead != existing.isRead;
          final bool starredChanged =
              (existing.isStarred || e.isStarred) != existing.isStarred;

          if (dateChanged || readChanged || starredChanged) {
            hasChanges = true;
            if (dateChanged) {
              print(
                '[SYNC DIAGNOSTIC] Email timestamp updated for ID ${e.id}: '
                'OldDate=${existing.date.toIso8601String()}, '
                'NewDate=${e.date.toIso8601String()}, '
                'Fallback=${e.isDateFallback}, CurrentLocalTime=${now.toIso8601String()}',
              );
            }
            merged[key] = existing.copyWith(
              isStarred: existing.isStarred || e.isStarred,
              isRead: e.isRead,
              date: effectiveDate,
              isDateFallback: e.isDateFallback && existing.isDateFallback,
            );
          }
        } else {
          // New incoming email!
          hasChanges = true;
          print(
            '[SYNC DIAGNOSTIC] New Email Synced! ID: ${e.id}, Subject: "${e.subject}", '
            'Sender: "${e.senderEmail}", ServerDate: ${e.date.toIso8601String()}, '
            'IsDateFallback: ${e.isDateFallback}, LocalDeviceTime: ${now.toIso8601String()}',
          );
          merged[key] = e;

          // Trigger System Notification pop-up for newly synced emails
          if (!e.isSent) {
            NotificationService.instance.showNotification(
              NotificationEvent(
                type: 'new_email',
                emailId: e.id,
                senderName: e.senderName.isNotEmpty
                    ? e.senderName
                    : e.senderEmail,
                senderEmail: e.senderEmail,
                subject: e.subject.isNotEmpty ? e.subject : 'New Email',
                preview: e.body.isNotEmpty
                    ? e.body
                    : 'You have received a new email.',
                timestamp: e.date,
              ),
            );
          }
        }
      }

      if (hasChanges) {
        final sortedList = merged.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        state = state.copyWith(emails: sortedList);
        print(
          '[AUTO-SYNC] State updated smoothly with new/updated emails. Total count: ${sortedList.length}',
        );
      } else {
        print(
          '[AUTO-SYNC] No new emails or field changes detected. Skipping state rebuild.',
        );
      }
    } catch (e) {
      print('[AUTO-SYNC ERROR] Silent background sync failure: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ── Load a specific folder (lazy) ───────────────────────────────────────

  Future<void> loadFolder(String folder, {bool background = false}) async {
    if (folder == 'Storage') return;
    if (state.isLoading && !background) return;

    if (!background) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final fetched = await MailRepository.fetchFolder(folder, limit: 50);
      final merged = <String, EmailModel>{};
      for (final e in state.emails) {
        merged[e.canonicalKey] = e;
      }
      for (final e in fetched) {
        final key = e.canonicalKey;
        if (merged.containsKey(key)) {
          final existing = merged[key]!;
          final DateTime effectiveDate =
              (e.isDateFallback && !existing.isDateFallback)
              ? existing.date
              : e.date;
            final updatedFolders = existing.memberOfFolders.union(
              e.memberOfFolders.isEmpty ? {folder} : e.memberOfFolders,
            );
            if (existing.isStarred || e.isStarred || folder == 'Starred') {
              updatedFolders.add('Starred');
            }
            merged[key] = existing.copyWith(
              isStarred: existing.isStarred || e.isStarred || folder == 'Starred',
              isSnoozed: existing.isSnoozed || e.isSnoozed,
              isScheduled: existing.isScheduled || e.isScheduled,
              labels: (existing.labels.toSet()..addAll(e.labels)).toList(),
              isSent: folder == 'Sent' ? true : existing.isSent,
              isDraft: folder == 'Draft' ? true : existing.isDraft,
              isTrash: folder == 'Trash' ? true : existing.isTrash,
              isArchive: folder == 'Archive' ? true : existing.isArchive,
              isSpam: folder == 'Spam' ? true : existing.isSpam,
              date: effectiveDate,
              isDateFallback: e.isDateFallback && existing.isDateFallback,
              isRead: e.isRead,
              memberOfFolders: updatedFolders,
            );
        } else {
          merged[key] = e.copyWith(
            memberOfFolders: e.memberOfFolders.isEmpty
                ? {folder}
                : e.memberOfFolders,
          );
        }
      }
      _deduplicateDrafts(merged);
      final updated = Set<String>.from(state.loadedFolders)..add(folder);
      state = state.copyWith(
        emails: merged.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
        isLoading: false,
        loadedFolders: updated,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Force-reloads a folder, bypassing the cache guard.
  Future<void> forceRefreshFolder(String folder) async {
    if (folder == 'Storage') return;
    try {
      final fetched = await MailRepository.fetchFolder(folder, limit: 50);
      final merged = <String, EmailModel>{};

      // Keep all existing emails in state to preserve multi-folder tags
      for (final e in state.emails) {
        if (folder == 'Draft' &&
            e.id.startsWith('local_') &&
            (e.isDraft || e.memberOfFolders.contains('Draft'))) {
          continue;
        }
        merged[e.canonicalKey] = e;
      }

      // Add/merge freshly fetched emails
      for (final e in fetched) {
        final key = e.canonicalKey;
        if (merged.containsKey(key)) {
          final existing = merged[key]!;
          final DateTime effectiveDate =
              (e.isDateFallback && !existing.isDateFallback)
              ? existing.date
              : e.date;

            final updatedFolders = existing.memberOfFolders.union(
              e.memberOfFolders.isEmpty ? {folder} : e.memberOfFolders,
            );
            if (existing.isStarred || e.isStarred || folder == 'Starred') {
              updatedFolders.add('Starred');
            }
            merged[key] = existing.copyWith(
              isStarred: existing.isStarred || e.isStarred || folder == 'Starred',
              isSnoozed: existing.isSnoozed || e.isSnoozed,
              isScheduled: existing.isScheduled || e.isScheduled,
              labels: (existing.labels.toSet()..addAll(e.labels)).toList(),
              isSent: existing.isSent || e.isSent || folder == 'Sent',
              isDraft: existing.isDraft || e.isDraft || folder == 'Draft',
              isTrash: existing.isTrash || e.isTrash || folder == 'Trash',
              isArchive: existing.isArchive || e.isArchive || folder == 'Archive',
              isSpam: existing.isSpam || e.isSpam || folder == 'Spam',
              date: effectiveDate,
              isDateFallback: e.isDateFallback && existing.isDateFallback,
              isRead: e.isRead,
              memberOfFolders: updatedFolders,
            );
        } else {
          merged[key] = e.copyWith(
            memberOfFolders: e.memberOfFolders.isEmpty
                ? {folder}
                : e.memberOfFolders,
          );
        }
      }

      _deduplicateDrafts(merged);
      _deduplicateSent(merged);
      final updated = Set<String>.from(state.loadedFolders)..add(folder);
      state = state.copyWith(
        emails: merged.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
        loadedFolders: updated,
      );
    } catch (_) {
      // Silent on background refresh
    }
  }

  void _deduplicateDrafts(Map<String, EmailModel> merged) {
    final Set<String> idsToRemove = {};
    final Map<String, EmailModel> seenFingerprints = {};

    for (final email in merged.values) {
      final isDraftCandidate =
          email.isDraft || email.memberOfFolders.contains('Draft');
      if (!isDraftCandidate) continue;

      if (email.isScheduled || email.memberOfFolders.contains('Scheduled')) {
        idsToRemove.add(email.id);
        continue;
      }

      final recipientKey = email.recipient.trim().toLowerCase();
      final subjectKey = email.subject.trim().toLowerCase();
      final bodySnippet = email.body.trim().length > 40
          ? email.body.trim().substring(0, 40).toLowerCase()
          : email.body.trim().toLowerCase();

      final fingerprint = '${recipientKey}_${subjectKey}_$bodySnippet';

      if (seenFingerprints.containsKey(fingerprint)) {
        final existing = seenFingerprints[fingerprint]!;
        if (email.id.startsWith('local_') &&
            !existing.id.startsWith('local_')) {
          idsToRemove.add(email.id);
        } else if (!email.id.startsWith('local_') &&
            existing.id.startsWith('local_')) {
          idsToRemove.add(existing.id);
          seenFingerprints[fingerprint] = email;
        } else {
          if (email.date.isAfter(existing.date)) {
            idsToRemove.add(existing.id);
            seenFingerprints[fingerprint] = email;
          } else {
            idsToRemove.add(email.id);
          }
        }
      } else {
        seenFingerprints[fingerprint] = email;
      }
    }

    for (final id in idsToRemove) {
      merged.remove(id);
    }
  }

  // ── Pull-to-refresh (reload current + important folders) ────────────────

  Future<void> refresh(String currentFolder) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final foldersToRefresh = <String>{
        currentFolder,
        'Inbox',
        'Sent',
        'Draft',
        'Starred',
      };

      final results = await Future.wait(
        foldersToRefresh.map((f) => MailRepository.fetchFolder(f, limit: 50)),
      );

      final merged = <String, EmailModel>{};
      // 1. Pre-populate merged map with existing emails to prevent temporary list clearing or timestamp loss
      for (final e in state.emails) {
        merged[e.canonicalKey] = e;
      }

      // 2. Merge freshly fetched emails from server
      for (int i = 0; i < results.length; i++) {
        final folderName = foldersToRefresh.elementAt(i);
        for (final e in results[i]) {
          final key = e.canonicalKey;
          if (merged.containsKey(key)) {
            final existing = merged[key]!;
            final DateTime effectiveDate =
                (e.isDateFallback && !existing.isDateFallback)
                ? existing.date
                : e.date;

            final bool effectiveIsTrash = existing.isTrash || e.isTrash;
            final bool effectiveIsDraft =
                !effectiveIsTrash && (existing.isDraft || e.isDraft);

            final updatedFolders = (existing.memberOfFolders.union(
              e.memberOfFolders.isEmpty ? {folderName} : e.memberOfFolders,
            ));
            if (effectiveIsTrash) {
              updatedFolders.remove('Draft');
              updatedFolders.remove('Inbox');
              updatedFolders.add('Trash');
            }

            merged[key] = existing.copyWith(
              isStarred: existing.isStarred || e.isStarred,
              isSnoozed: existing.isSnoozed || e.isSnoozed,
              labels: (existing.labels.toSet()..addAll(e.labels)).toList(),
              isSent: existing.isSent || e.isSent,
              isDraft: effectiveIsDraft,
              isTrash: effectiveIsTrash,
              isArchive: existing.isArchive || e.isArchive,
              isSpam: existing.isSpam || e.isSpam,
              date: effectiveDate,
              isDateFallback: e.isDateFallback && existing.isDateFallback,
              isRead: e.isRead,
              memberOfFolders: updatedFolders,
            );
          } else {
            merged[key] = e.copyWith(
              memberOfFolders: e.memberOfFolders.isEmpty
                  ? {folderName}
                  : e.memberOfFolders,
            );
          }
        }
      }

      _deduplicateDrafts(merged);
      _deduplicateSent(merged);

      // Update loadedFolders to include all refreshed
      final updatedFolders = Set<String>.from(state.loadedFolders)
        ..addAll(foldersToRefresh);

      state = state.copyWith(
        emails: merged.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
        isLoading: false,
        loadedFolders: updatedFolders,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  // ── Clear all data (on logout) ───────────────────────────────────────────

  void clearAll() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    state = const EmailState();
  }

  Future<void> toggleEmailLabel(
    String emailId,
    String labelName, {
    List<LabelModel>? allLabels,
    String folder = 'Inbox',
  }) async {
    bool isApplying = false;
    state = state.copyWith(
      emails: state.emails.map((e) {
        if (e.id == emailId) {
          final labels = List<String>.from(e.labels);
          if (labels.any(
            (l) => l.trim().toLowerCase() == labelName.trim().toLowerCase(),
          )) {
            labels.removeWhere(
              (l) => l.trim().toLowerCase() == labelName.trim().toLowerCase(),
            );
            isApplying = false;
          } else {
            labels.add(labelName);
            isApplying = true;
          }
          return e.copyWith(labels: labels);
        }
        return e;
      }).toList(),
    );

    String labelId = labelName;
    List<LabelModel> availableLabels = allLabels ?? [];
    if (availableLabels.isEmpty) {
      availableLabels = await LabelRepository.fetchLabels();
    }
    final foundLabel = availableLabels.firstWhere(
      (l) =>
          l.name.trim().toLowerCase() == labelName.trim().toLowerCase() ||
          l.id == labelName,
      orElse: () => LabelModel(
        id: labelName,
        name: labelName,
        color: const Color(0xFF2563EB),
      ),
    );
    labelId = foundLabel.id;

    if (isApplying) {
      await TokenService.saveAssignedEmailLabel(emailId, labelName);
      await LabelRepository.applyLabel(emailId, labelId, folder: folder);
    } else {
      await TokenService.removeAssignedEmailLabel(emailId, labelName);
      await LabelRepository.removeLabel(emailId, labelId, folder: folder);
    }
  }

  Future<void> bulkApplyLabel(
    List<String> emailIds,
    String labelName, {
    List<LabelModel>? allLabels,
    String folder = 'Inbox',
  }) async {
    for (final id in emailIds) {
      await toggleEmailLabel(
        id,
        labelName,
        allLabels: allLabels,
        folder: folder,
      );
    }
  }

  Future<void> onLabelDeleted(String labelId, String labelName) async {
    final targetName = labelName.trim().toLowerCase();
    final targetId = labelId.trim().toLowerCase();

    state = state.copyWith(
      emails: state.emails.map((e) {
        if (e.labels.any(
          (l) =>
              l.trim().toLowerCase() == targetName ||
              l.trim().toLowerCase() == targetId,
        )) {
          final updatedLabels = e.labels
              .where(
                (l) =>
                    l.trim().toLowerCase() != targetName &&
                    l.trim().toLowerCase() != targetId,
              )
              .toList();
          return e.copyWith(labels: updatedLabels);
        }
        return e;
      }).toList(),
    );

    await TokenService.removeLabelFromAllEmails(labelName);
    if (labelId.isNotEmpty && labelId != labelName) {
      await TokenService.removeLabelFromAllEmails(labelId);
    }
  }

  Future<void> fetchCategory(String category) async {
    final categoryEmails = await LabelRepository.fetchCategory(
      category.toLowerCase(),
    );
    if (categoryEmails.isNotEmpty) {
      final mergedMap = <String, EmailModel>{};
      for (final e in state.emails) {
        mergedMap[e.canonicalKey] = e;
      }
      for (final e in categoryEmails) {
        mergedMap[e.canonicalKey] = e;
      }
      state = state.copyWith(
        emails: mergedMap.values.toList(),
        loadedFolders: {...state.loadedFolders, category},
      );
    }
  }

  void toggleStar(String emailId, String folder) {
    _updateLocal(emailId, (e) {
      final newStarred = !e.isStarred;
      final newFolders = Set<String>.from(e.memberOfFolders);
      if (newStarred) {
        newFolders.add('Starred');
      } else {
        newFolders.remove('Starred');
      }
      return e.copyWith(
        isStarred: newStarred,
        memberOfFolders: newFolders,
      );
    });
    MailRepository.toggleStar(emailId, folder).catchError((_) {
      // Rollback on failure
      _updateLocal(emailId, (e) {
        final revertedStarred = !e.isStarred;
        final revertedFolders = Set<String>.from(e.memberOfFolders);
        if (revertedStarred) {
          revertedFolders.add('Starred');
        } else {
          revertedFolders.remove('Starred');
        }
        return e.copyWith(
          isStarred: revertedStarred,
          memberOfFolders: revertedFolders,
        );
      });
    });
  }

  void toggleRead(
    String emailId,
    String folder, {
    bool? forceValue,
    String? tempToken,
  }) {
    EmailModel? target;
    try {
      target = state.emails.firstWhere((e) => e.id == emailId);
    } catch (_) {}

    final bool newVal = forceValue ?? !(target?.isRead ?? false);

    final targetFingerprint =
        (target != null &&
            (target.isDraft || target.memberOfFolders.contains('Draft')))
        ? '${target.recipient.trim().toLowerCase()}_${target.subject.trim().toLowerCase()}'
        : null;

    EmailModel? original;
    state = state.copyWith(
      emails: state.emails.map((e) {
        if (e.id == emailId) {
          original = e;
          return e.copyWith(isRead: newVal);
        }
        if (targetFingerprint != null &&
            (e.isDraft || e.memberOfFolders.contains('Draft'))) {
          final fp =
              '${e.recipient.trim().toLowerCase()}_${e.subject.trim().toLowerCase()}';
          if (fp == targetFingerprint) {
            return e.copyWith(isRead: newVal);
          }
        }
        return e;
      }).toList(),
    );
    (newVal
            ? MailRepository.markRead(emailId, folder, tempToken: tempToken)
            : MailRepository.markUnread(emailId, folder, tempToken: tempToken))
        .catchError((_) {
          if (original != null) {
            _updateLocal(emailId, (_) => original!);
          }
        });
  }

  void _deduplicateSent(Map<String, EmailModel> merged) {
    final Set<String> idsToRemove = {};

    for (final email in merged.values) {
      if ((email.isSent || email.memberOfFolders.contains('Sent')) &&
          email.id.startsWith('local_')) {
        final recipientKey = email.recipient.trim().toLowerCase();
        final subjectKey = email.subject.trim().toLowerCase();
        final bodySnippet = email.body.trim().length > 30
            ? email.body.trim().substring(0, 30).toLowerCase()
            : email.body.trim().toLowerCase();

        final fingerprint = '${recipientKey}_${subjectKey}_$bodySnippet';

        for (final existing in merged.values) {
          if (existing.id != email.id &&
              !existing.id.startsWith('local_') &&
              (existing.isSent || existing.memberOfFolders.contains('Sent'))) {
            final exRecipient = existing.recipient.trim().toLowerCase();
            final exSubject = existing.subject.trim().toLowerCase();
            final exBodySnippet = existing.body.trim().length > 30
                ? existing.body.trim().substring(0, 30).toLowerCase()
                : existing.body.trim().toLowerCase();
            final exFp = '${exRecipient}_${exSubject}_$exBodySnippet';

            if (exFp == fingerprint) {
              idsToRemove.add(email.id);
              break;
            }
          }
        }
      }
    }

    for (final id in idsToRemove) {
      merged.remove(id);
    }
  }

  void deleteEmail(String emailId, String folder) {
    EmailModel? target;
    try {
      target = state.emails.firstWhere((e) => e.id == emailId);
    } catch (_) {}

    final bool isAlreadyTrash =
        (folder == 'Trash') ||
        (target != null &&
            (target.isTrash || target.memberOfFolders.contains('Trash')));

    if (isAlreadyTrash) {
      permanentlyDeleteEmail(emailId);
      return;
    }

    String effectiveFolder = folder;
    if (target != null &&
        (target.isDraft || target.memberOfFolders.contains('Draft'))) {
      effectiveFolder = 'Draft';
    }

    _updateLocal(emailId, (e) {
      final updatedFolders = Set<String>.from(e.memberOfFolders)
        ..add('Trash')
        ..remove('Inbox')
        ..remove('Draft')
        ..remove(folder);
      return e.copyWith(
        isTrash: true,
        isDraft: false,
        memberOfFolders: updatedFolders,
      );
    });

    final cleanId = MailRepository.cleanUid(emailId);
    MailRepository.trashEmail(cleanId, effectiveFolder).catchError((err) {
      print(
        '[DELETE EMAIL ERROR] trashEmail failed for $cleanId ($effectiveFolder): $err',
      );
    });
  }

  void permanentlyDeleteEmail(String emailId, {String folder = 'Trash'}) {
    state = state.copyWith(
      emails: state.emails.where((e) => e.id != emailId).toList(),
    );
    final cleanId = MailRepository.cleanUid(emailId);
    MailRepository.permanentlyDeleteEmail(cleanId, folder: folder).catchError((
      err,
    ) {
      print(
        '[PERMANENT DELETE ERROR] permanentlyDeleteEmail failed for $cleanId ($folder): $err',
      );
    });
  }

  Future<void> fetchFullEmailDetails(String emailId, String folder) async {
    final cleanId = MailRepository.cleanUid(emailId);
    try {
      final fullEmail = await MailRepository.fetchEmail(
        cleanId,
        folder: folder,
      );
      if (fullEmail != null) {
        _updateLocal(emailId, (existing) {
          final mergedAttachments = (existing.attachments.isNotEmpty)
              ? existing.attachments
              : fullEmail.attachments;
          return existing.copyWith(
            attachments: mergedAttachments,
            body: fullEmail.body.isNotEmpty ? fullEmail.body : existing.body,
            hasAttachment:
                existing.hasAttachment ||
                fullEmail.hasAttachment ||
                mergedAttachments.isNotEmpty,
          );
        });
      }
    } catch (e) {
      print(
        '[FETCH EMAIL DETAILS WARNING] fetchFullEmailDetails failed for $cleanId: $e',
      );
    }
  }

  void restoreEmail(String emailId) {
    _updateLocal(emailId, (e) {
      final updatedFolders = Set<String>.from(e.memberOfFolders)
        ..remove('Trash')
        ..add('Inbox');
      return e.copyWith(isTrash: false, memberOfFolders: updatedFolders);
    });
    final cleanId = MailRepository.cleanUid(emailId);
    MailRepository.restoreFromTrash(cleanId).catchError((err) {
      print('[RESTORE EMAIL ERROR] restoreFromTrash failed for $cleanId: $err');
    });
  }

  void archiveEmail(String emailId, String folder) {
    _updateLocal(emailId, (e) {
      final updatedFolders = Set<String>.from(e.memberOfFolders)
        ..add('Archive')
        ..remove('Inbox')
        ..remove(folder);
      return e.copyWith(isArchive: true, memberOfFolders: updatedFolders);
    });
    MailRepository.archiveEmail(emailId, folder).catchError((err) {
      print('[ARCHIVE WARNING] Backend archive failed for $emailId: $err');
    });
  }

  void unarchiveEmail(String emailId) {
    _updateLocal(emailId, (e) {
      final updatedFolders = Set<String>.from(e.memberOfFolders)
        ..remove('Archive')
        ..add('Inbox');
      return e.copyWith(isArchive: false, memberOfFolders: updatedFolders);
    });
    MailRepository.unarchiveEmail(emailId).catchError((err) {
      print('[UNARCHIVE WARNING] Backend unarchive failed for $emailId: $err');
    });
  }

  void markSpam(String emailId, String folder) {
    _updateLocal(emailId, (e) {
      final updatedFolders = Set<String>.from(e.memberOfFolders)
        ..add('Spam')
        ..remove('Inbox');
      return e.copyWith(isSpam: true, memberOfFolders: updatedFolders);
    });
    MailRepository.markSpam(emailId, folder).catchError((_) {
      _updateLocal(emailId, (e) => e.copyWith(isSpam: false));
    });
  }

  void snoozeEmail(String emailId, DateTime until, String folder) {
    _updateLocal(
      emailId,
      (e) => e.copyWith(isSnoozed: true, snoozeUntil: until),
    );
    MailRepository.snoozeEmail(emailId, until, folder).catchError((_) {
      _updateLocal(
        emailId,
        (e) => e.copyWith(isSnoozed: false, snoozeUntil: null),
      );
    });
  }

  void toggleSnooze(String emailId, {bool? forceValue}) {
    _updateLocal(
      emailId,
      (e) => e.copyWith(isSnoozed: forceValue ?? !e.isSnoozed),
    );
  }

  void markAllAsRead() {
    state = state.copyWith(
      emails: state.emails.map((e) => e.copyWith(isRead: true)).toList(),
    );
  }

  void sortByDate() {
    final sorted = List<EmailModel>.from(state.emails)
      ..sort((a, b) => b.date.compareTo(a.date));
    state = state.copyWith(emails: sorted);
  }

  void sortBySender() {
    final sorted = List<EmailModel>.from(state.emails)
      ..sort((a, b) => a.senderName.compareTo(b.senderName));
    state = state.copyWith(emails: sorted);
  }

  /// Sends an email via API and then fetches the Sent folder from the
  /// server to get the real server-assigned ID — this ensures the sent
  /// mail persists across logouts.
  Future<void> composeEmail({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
    List<String> labels = const [],
    bool isDraft = false,
    bool isHtml = false,
    DateTime? scheduledAt,
    List<AttachmentModel> attachments = const [],
  }) async {
    final isScheduled = scheduledAt != null;
    // 1. Generate local optimistic copy and add to state immediately
    final userName = await TokenService.getUserName() ?? 'Me';
    final userEmail = await TokenService.getUserEmail() ?? '';
    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final newEmail = EmailModel(
      id: tempId,
      senderName: userName,
      senderEmail: userEmail,
      recipient: to,
      subject: subject.isEmpty ? '(No Subject)' : subject,
      body: body,
      date: scheduledAt ?? DateTime.now(),
      isRead: true,
      isDraft: isDraft,
      isSent: !isDraft && !isScheduled,
      isScheduled: isScheduled,
      labels: labels,
      attachments: attachments,
      hasAttachment: attachments.isNotEmpty,
      memberOfFolders: {
        if (isDraft) 'Draft',
        if (!isDraft && !isScheduled) 'Sent',
        if (isScheduled) 'Scheduled',
      },
    );

    print('[INFO] Adding optimistic local email tile: $tempId');
    state = state.copyWith(emails: [newEmail, ...state.emails]);

    // 2. Perform server API send/draft/schedule save
    try {
      if (isScheduled) {
        await MailRepository.scheduleEmail(
          to: to,
          subject: subject.isEmpty ? '(No Subject)' : subject,
          content: body,
          scheduledAt: scheduledAt,
          cc: cc,
          bcc: bcc,
          attachments: attachments,
        );
      } else if (isDraft) {
        await MailRepository.saveDraft(
          to: to,
          subject: subject,
          content: body,
          cc: cc,
          bcc: bcc,
        );
      } else {
        await MailRepository.sendEmail(
          to: to,
          subject: subject.isEmpty ? '(No Subject)' : subject,
          content: body,
          isHtml: isHtml,
          cc: cc,
          bcc: bcc,
          attachments: attachments,
        );
      }
    } catch (e) {
      print('[ERROR] Server API call failed for $tempId: $e');
    }

    // 3. Immediately refresh folders so that the real server state updates
    if (isScheduled) {
      await forceRefreshFolder('Scheduled');
      await forceRefreshFolder('Snoozed');
    } else if (!isDraft) {
      await forceRefreshFolder('Sent');
      await forceRefreshFolder('Inbox');
      await forceRefreshFolder('Draft');
    } else {
      await forceRefreshFolder('Draft');
    }
  }

  // ── Scheduled Email Actions ───────────────────────────────────────────────

  /// Reschedules an existing scheduled email to a new date & time.
  Future<void> rescheduleScheduledEmail(
    String emailId,
    DateTime newScheduledAt,
  ) async {
    final existing = state.emails.firstWhere(
      (e) => e.id == emailId,
      orElse: () => EmailModel(
        id: emailId,
        senderName: '',
        senderEmail: '',
        recipient: '',
        subject: '',
        body: '',
        date: DateTime.now(),
      ),
    );

    // Optimistic update
    _updateLocal(emailId, (e) => e.copyWith(date: newScheduledAt));

    try {
      await MailRepository.scheduleEmail(
        to: existing.recipient,
        subject: existing.subject,
        content: existing.body,
        scheduledAt: newScheduledAt,
        attachments: existing.attachments,
      );
    } catch (err) {
      print('[ERROR] rescheduleScheduledEmail API call failed: $err');
    }

    await forceRefreshFolder('Scheduled');
  }

  /// Sends a scheduled email immediately, moving it from Scheduled to Sent.
  Future<void> sendScheduledEmailNow(EmailModel email) async {
    final cleanId = MailRepository.cleanUid(email.id);

    // Optimistic update: move to Sent folder
    _updateLocal(
      email.id,
      (e) => e.copyWith(
        isScheduled: false,
        isSent: true,
        memberOfFolders: {'Sent'},
      ),
    );

    try {
      await MailRepository.sendEmail(
        to: email.recipient,
        subject: email.subject,
        content: email.body,
        attachments: email.attachments,
      );
      try {
        await MailRepository.permanentDelete(cleanId);
      } catch (_) {}
    } catch (err) {
      print('[ERROR] sendScheduledEmailNow API call failed: $err');
    }

    await forceRefreshFolder('Scheduled');
    await forceRefreshFolder('Sent');
  }

  /// Cancels a scheduled email, removing it from Scheduled folder.
  Future<void> cancelScheduledEmail(String emailId) async {
    final cleanId = MailRepository.cleanUid(emailId);

    // Optimistic update: remove from list
    state = state.copyWith(
      emails: state.emails.where((e) => e.id != emailId).toList(),
    );

    try {
      await MailRepository.trashEmail(cleanId, 'Scheduled');
    } catch (err) {
      print('[ERROR] cancelScheduledEmail API call failed: $err');
    }

    await forceRefreshFolder('Scheduled');
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  void _updateLocal(String id, EmailModel Function(EmailModel) updater) {
    state = state.copyWith(
      emails: state.emails.map((e) => e.id == id ? updater(e) : e).toList(),
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('No internet')) {
      return 'No internet connection. Pull to refresh.';
    }
    if (msg.contains('timed out')) {
      return 'Connection timed out. Pull to refresh.';
    }
    if (msg.contains('401')) return 'Session expired. Please log in again.';
    return 'Something went wrong. Pull to refresh.';
  }

  /// Automatic background execution dispatcher for due scheduled emails (scheduledAt <= now).
  /// Dispatches due emails automatically via SMTP / backend API as soon as their scheduled date & time arrives.
  Future<void> checkAndDispatchScheduledMails() async {
    if (_isDispatchingScheduled) return;
    _isDispatchingScheduled = true;

    try {
      final now = DateTime.now();

      // 1. Gather all scheduled emails from local Riverpod state
      final dueMails = <EmailModel>[];
      for (final e in state.emails) {
        final isSched =
            e.isScheduled || e.memberOfFolders.contains('Scheduled');
        if (isSched && !_dispatchingIds.contains(e.id)) {
          if (e.date.isBefore(now) || e.date.isAtSameMomentAs(now)) {
            dueMails.add(e);
          }
        }
      }

      // 2. Fetch latest server Scheduled folder items to catch items created in background
      try {
        final serverScheduled = await MailRepository.fetchFolder(
          'Scheduled',
          limit: 50,
        );
        for (final e in serverScheduled) {
          if (!_dispatchingIds.contains(e.id)) {
            if (e.date.isBefore(now) || e.date.isAtSameMomentAs(now)) {
              if (!dueMails.any((m) => m.id == e.id)) {
                dueMails.add(e);
              }
            }
          }
        }
      } catch (_) {}

      // 3. Dispatch each due email automatically
      if (dueMails.isNotEmpty) {
        print(
          '[SCHEDULED DISPATCH] Found ${dueMails.length} due scheduled email(s) for delivery.',
        );

        for (final mail in dueMails) {
          _dispatchingIds.add(mail.id);
          try {
            print(
              '[SCHEDULED DISPATCH] Dispatching mail "${mail.subject}" to ${mail.recipient}...',
            );
            await sendScheduledEmailNow(mail);
            print(
              '[SCHEDULED DISPATCH SUCCESS] Mail "${mail.subject}" sent to ${mail.recipient} successfully.',
            );
          } catch (err) {
            print(
              '[SCHEDULED DISPATCH ERROR] Failed to send scheduled mail ${mail.id}: $err',
            );
          } finally {
            _dispatchingIds.remove(mail.id);
          }
        }
      }
    } catch (e) {
      print(
        '[SCHEDULED DISPATCH ERROR] Error in checkAndDispatchScheduledMails: $e',
      );
    } finally {
      _isDispatchingScheduled = false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final emailProvider = StateNotifierProvider<EmailNotifier, EmailState>((ref) {
  return EmailNotifier();
});

// ── Convenience providers consumed by the UI ──────────────────────────────────

/// Flat list of all loaded emails — drop-in replacement for the old `List<EmailModel>` provider.
final emailListProvider = Provider<List<EmailModel>>((ref) {
  final emails = ref.watch(emailProvider).emails;
  print(
    '[DIAGNOSTIC] emailListProvider exposing ${emails.length} emails to the UI.',
  );
  return emails;
});

final emailLoadingProvider = Provider<bool>(
  (ref) => ref.watch(emailProvider).isLoading,
);
final emailErrorProvider = Provider<String?>(
  (ref) => ref.watch(emailProvider).error,
);
