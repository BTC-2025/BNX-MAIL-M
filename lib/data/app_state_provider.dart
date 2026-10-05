import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/token_service.dart';
import '../models/label_model.dart';
import 'repositories/label_repository.dart';
import 'email_provider.dart';

enum ComposeStatus { closed, minimized, normal, maximized }

// Sentinel object to distinguish "not provided" from intentional null
const _absent = Object();

class AppUiState {
  final String activeFolder;
  final String? activeLabel;
  final String? selectedEmailId;
  final Set<String> selectedEmailIds;
  final bool isSelectionMode;
  final String searchQuery;
  final bool isDarkMode;
  final bool isSidebarCollapsed;
  final ComposeStatus composeStatus;
  final String activeRightUtility;
  final String? activeLeftUtility;
  // Persisted set of active tool names in the utility rail
  final Set<String> activeToolNames;

  final String composeTo;
  final String composeSubject;
  final String composeBody;
  final String composeDraftId;
  final Map<String, bool> sidebarLabelVisibility;

  static const defaultSidebarVisibility = <String, bool>{
    'Inbox': true,
    'Starred': true,
    'Snoozed': true,
    'Sent': true,
    'Draft': true,
    'Trash': true,
    'Bulk Mail': true,
    'Notifications': true,
    'Archive': true,
    'Scheduled': true,
    'Spam': true,
    'All Mail': true,
  };

  const AppUiState({
    required this.activeFolder,
    this.activeLabel,
    this.selectedEmailId,
    this.selectedEmailIds = const {},
    this.isSelectionMode = false,
    required this.searchQuery,
    required this.isDarkMode,
    required this.isSidebarCollapsed,
    required this.composeStatus,
    required this.activeRightUtility,
    this.activeLeftUtility,
    this.activeToolNames = const {'Calculator', 'Calendar', 'Contacts'},
    this.composeTo = '',
    this.composeSubject = '',
    this.composeBody = '',
    this.composeDraftId = '',
    this.sidebarLabelVisibility = defaultSidebarVisibility,
  });

  AppUiState copyWith({
    String? activeFolder,
    Object? activeLabel = _absent,
    Object? selectedEmailId = _absent,
    Set<String>? selectedEmailIds,
    bool? isSelectionMode,
    String? searchQuery,
    bool? isDarkMode,
    bool? isSidebarCollapsed,
    ComposeStatus? composeStatus,
    String? activeRightUtility,
    Object? activeLeftUtility = _absent,
    Set<String>? activeToolNames,
    String? composeTo,
    String? composeSubject,
    String? composeBody,
    String? composeDraftId,
    Map<String, bool>? sidebarLabelVisibility,
  }) {
    return AppUiState(
      activeFolder: activeFolder ?? this.activeFolder,
      activeLabel: identical(activeLabel, _absent)
          ? this.activeLabel
          : activeLabel as String?,
      selectedEmailId: identical(selectedEmailId, _absent)
          ? this.selectedEmailId
          : selectedEmailId as String?,
      selectedEmailIds: selectedEmailIds ?? this.selectedEmailIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      searchQuery: searchQuery ?? this.searchQuery,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isSidebarCollapsed: isSidebarCollapsed ?? this.isSidebarCollapsed,
      composeStatus: composeStatus ?? this.composeStatus,
      activeRightUtility: activeRightUtility ?? this.activeRightUtility,
      activeLeftUtility: identical(activeLeftUtility, _absent)
          ? this.activeLeftUtility
          : activeLeftUtility as String?,
      activeToolNames: activeToolNames ?? this.activeToolNames,
      composeTo: composeTo ?? this.composeTo,
      composeSubject: composeSubject ?? this.composeSubject,
      composeBody: composeBody ?? this.composeBody,
      composeDraftId: composeDraftId ?? this.composeDraftId,
      sidebarLabelVisibility: sidebarLabelVisibility ?? this.sidebarLabelVisibility,
    );
  }
}

class AppUiNotifier extends StateNotifier<AppUiState> {
  AppUiNotifier()
    : super(
        const AppUiState(
          activeFolder: 'Inbox',
          activeLabel: null,
          selectedEmailId: null,
          selectedEmailIds: {},
          searchQuery: '',
          isDarkMode: false,
          isSidebarCollapsed: false,
          composeStatus: ComposeStatus.closed,
          activeRightUtility: 'none',
          activeLeftUtility: null,
          composeTo: '',
          composeSubject: '',
          composeBody: '',
          composeDraftId: '',
        ),
      ) {
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    try {
      final email = await TokenService.getUserEmail();
      if (email != null && email.isNotEmpty) {
        await loadUserSettings(email);
      }
    } catch (_) {}
  }

  Future<void> loadUserSettings(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;
    try {
      final userSettings = await TokenService.getUserSettings(cleanEmail);
      final Map<String, bool> accountLabels = {};
      if (userSettings != null && userSettings['sidebarLabels'] is Map) {
        final raw = userSettings['sidebarLabels'] as Map;
        for (final entry in raw.entries) {
          accountLabels[entry.key.toString()] = (entry.value == true);
        }
      }
      resetSidebarLabels(accountLabels);
    } catch (_) {}
  }

  void resetSidebarLabels(Map<String, bool> accountSpecificLabels) {
    final updated = Map<String, bool>.from(AppUiState.defaultSidebarVisibility);
    updated.addAll(accountSpecificLabels);
    if (accountSpecificLabels.containsKey('Bulk Mail')) updated['Spam'] = accountSpecificLabels['Bulk Mail']!;
    if (accountSpecificLabels.containsKey('Spam')) updated['Bulk Mail'] = accountSpecificLabels['Spam']!;
    if (accountSpecificLabels.containsKey('Notifications')) updated['Subscriptions'] = accountSpecificLabels['Notifications']!;
    if (accountSpecificLabels.containsKey('Subscriptions')) updated['Notifications'] = accountSpecificLabels['Subscriptions']!;
    state = state.copyWith(sidebarLabelVisibility: updated);
  }

  void setSidebarLabel(String label, bool isVisible) {
    final updated = Map<String, bool>.from(state.sidebarLabelVisibility);
    updated[label] = isVisible;
    if (label == 'Bulk Mail') updated['Spam'] = isVisible;
    if (label == 'Spam') updated['Bulk Mail'] = isVisible;
    if (label == 'Notifications') updated['Subscriptions'] = isVisible;
    if (label == 'Subscriptions') updated['Notifications'] = isVisible;

    String newFolder = state.activeFolder;
    if (!isVisible &&
        (state.activeFolder == label ||
            (label == 'Bulk Mail' && state.activeFolder == 'Spam') ||
            (label == 'Notifications' && state.activeFolder == 'Subscriptions'))) {
      newFolder = 'Inbox';
    }
    state = state.copyWith(
      sidebarLabelVisibility: updated,
      activeFolder: newFolder,
    );
  }

  void setSidebarLabels(Map<String, bool> labels) {
    final updated = Map<String, bool>.from(state.sidebarLabelVisibility)..addAll(labels);
    if (labels.containsKey('Bulk Mail')) updated['Spam'] = labels['Bulk Mail']!;
    if (labels.containsKey('Spam')) updated['Bulk Mail'] = labels['Spam']!;
    if (labels.containsKey('Notifications')) updated['Subscriptions'] = labels['Notifications']!;
    if (labels.containsKey('Subscriptions')) updated['Notifications'] = labels['Subscriptions']!;
    state = state.copyWith(sidebarLabelVisibility: updated);
  }

  void selectFolder(String folder) {
    state = state.copyWith(
      activeFolder: folder,
      activeLabel: null,
      selectedEmailId: null,
      selectedEmailIds: {},
      isSelectionMode: false,
    );
  }

  void selectLabel(String label) {
    state = state.copyWith(
      activeLabel: label,
      activeFolder: 'Labels',
      selectedEmailId: null,
      selectedEmailIds: {},
      isSelectionMode: false,
    );
  }

  void selectEmail(String? emailId) {
    state = state.copyWith(selectedEmailId: emailId);
  }

  void toggleEmailSelection(String emailId) {
    final newSelection = Set<String>.from(state.selectedEmailIds);
    if (newSelection.contains(emailId)) {
      newSelection.remove(emailId);
    } else {
      newSelection.add(emailId);
    }
    state = state.copyWith(
      selectedEmailIds: newSelection,
      isSelectionMode: newSelection.isNotEmpty,
    );
  }

  void clearSelection() {
    state = state.copyWith(selectedEmailIds: {}, isSelectionMode: false);
  }

  void selectAllEmails(List<String> emailIds) {
    final allSelected = emailIds.every(
      (id) => state.selectedEmailIds.contains(id),
    );
    if (allSelected && emailIds.isNotEmpty) {
      state = state.copyWith(selectedEmailIds: {}, isSelectionMode: false);
    } else {
      state = state.copyWith(
        selectedEmailIds: Set<String>.from(emailIds),
        isSelectionMode: true,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleDarkMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarCollapsed: !state.isSidebarCollapsed);
  }

  void setSidebarCollapsed(bool collapsed) {
    state = state.copyWith(isSidebarCollapsed: collapsed);
  }

  void setComposeStatus(ComposeStatus status) {
    state = state.copyWith(composeStatus: status);
  }

  void updateComposeDraft({String? to, String? subject, String? body, String? draftId}) {
    state = state.copyWith(
      composeTo: to ?? state.composeTo,
      composeSubject: subject ?? state.composeSubject,
      composeBody: body ?? state.composeBody,
      composeDraftId: draftId ?? state.composeDraftId,
    );
  }

  void clearComposeDraft() {
    state = state.copyWith(
      composeTo: '',
      composeSubject: '',
      composeBody: '',
      composeDraftId: '',
    );
  }

  void setActiveRightUtility(String utility) {
    if (state.activeRightUtility == utility) {
      state = state.copyWith(activeRightUtility: 'none');
    } else {
      state = state.copyWith(activeRightUtility: utility);
    }
  }

  void setActiveLeftUtility(String? utility) {
    if (state.activeLeftUtility == utility) {
      state = state.copyWith(activeLeftUtility: null);
    } else {
      state = state.copyWith(activeLeftUtility: utility);
    }
  }

  void addActiveTool(String toolName) {
    final updated = Set<String>.from(state.activeToolNames)..add(toolName);
    state = state.copyWith(activeToolNames: updated);
  }

  void removeActiveTool(String toolName) {
    if (state.activeToolNames.length <= 1) return; // Keep at least one
    final updated = Set<String>.from(state.activeToolNames)..remove(toolName);
    state = state.copyWith(activeToolNames: updated);
  }

  void setActiveToolNames(Set<String> names) {
    if (names.isEmpty) return;
    state = state.copyWith(activeToolNames: names);
  }
}

final appUiProvider = StateNotifierProvider<AppUiNotifier, AppUiState>((ref) {
  return AppUiNotifier();
});

final fabExtensionProvider = StateProvider<bool>((ref) => true);

class CustomLabelsNotifier extends StateNotifier<List<LabelModel>> {
  final Ref ref;

  final Map<String, List<LabelModel>> _accountCaches = {};
  String _currentAccountId = '';

  CustomLabelsNotifier(this.ref) : super(const []) {
    _initInitialAccount();
  }

  Future<void> _initInitialAccount() async {
    final email = await TokenService.getUserEmail();
    if (email != null && email.isNotEmpty) {
      _currentAccountId = email.trim().toLowerCase();
      final local = await _loadLocalLabels(_currentAccountId);
      if (local.isNotEmpty) {
        state = local;
      }
    }
    await fetchLabels();
  }

  Future<List<LabelModel>> _loadLocalLabels(String accountId) async {
    final rawList = await TokenService.getUserCustomLabels(accountId);
    return rawList.map((m) => LabelModel.fromJson(m)).toList();
  }

  Future<void> _persistLocalLabels(String accountId, List<LabelModel> labels) async {
    final rawList = labels.map((l) => l.toJson()).toList();
    await TokenService.saveUserCustomLabels(accountId, rawList);
  }

  Future<void> fetchLabels() async {
    final activeEmail = _currentAccountId.isNotEmpty
        ? _currentAccountId
        : ((await TokenService.getUserEmail())?.trim().toLowerCase() ?? '');
    final remote = await LabelRepository.fetchLabels();
    if (remote.isNotEmpty || state.isEmpty) {
      state = remote;
      if (activeEmail.isNotEmpty) {
        _accountCaches[activeEmail] = remote;
        await _persistLocalLabels(activeEmail, remote);
      }
    }
  }

  Future<void> switchAccountContext(String accountId) async {
    final cleanId = accountId.trim().toLowerCase();
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
      await _persistLocalLabels(_currentAccountId, state);
    }
    _currentAccountId = cleanId;
    if (_accountCaches.containsKey(cleanId)) {
      state = _accountCaches[cleanId]!;
    } else {
      final local = await _loadLocalLabels(cleanId);
      state = local;
    }
    await fetchLabels();
  }

  void clear() {
    state = const [];
    _accountCaches.clear();
  }

  Future<void> addLabel(String name, Color color) async {
    final tempId = name.toLowerCase().replaceAll(' ', '_');
    if (state.any((l) => l.name.toLowerCase() == name.toLowerCase())) return;

    final String hexColor = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final created = await LabelRepository.createLabel(name, hexColor);
    if (created != null && created.id.isNotEmpty) {
      state = [...state.where((l) => l.name.toLowerCase() != name.toLowerCase()), created];
    } else {
      state = [...state, LabelModel(id: tempId, name: name, color: color)];
    }
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
      await _persistLocalLabels(_currentAccountId, state);
    }
  }

  Future<void> editLabel(String id, String newName, Color newColor) async {
    final String hexColor = '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    state = state.map((l) {
      if (l.id == id || l.name.toLowerCase() == id.toLowerCase()) {
        return LabelModel(id: l.id, name: newName, color: newColor);
      }
      return l;
    }).toList();

    final updated = await LabelRepository.updateLabel(id, newName, hexColor);
    if (updated != null) {
      state = state.map((l) => l.id == id ? updated : l).toList();
    }
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
      await _persistLocalLabels(_currentAccountId, state);
    }
  }

  Future<void> deleteLabel(String idOrName) async {
    String targetId = idOrName;
    final match = state.firstWhere(
      (l) => l.id == idOrName || l.name.toLowerCase() == idOrName.toLowerCase(),
      orElse: () => LabelModel(id: idOrName, name: idOrName, color: const Color(0xFF195BAC)),
    );
    targetId = match.id;
    final targetName = match.name;

    if (int.tryParse(targetId) == null) {
      final remote = await LabelRepository.fetchLabels();
      final remoteFound = remote.firstWhere(
        (l) => l.name.toLowerCase() == idOrName.toLowerCase() || l.id == idOrName,
        orElse: () => LabelModel(id: targetId, name: idOrName, color: const Color(0xFF195BAC)),
      );
      targetId = remoteFound.id;
    }

    state = state.where((l) => l.id != idOrName && l.name.toLowerCase() != idOrName.toLowerCase()).toList();
    if (_currentAccountId.isNotEmpty) {
      _accountCaches[_currentAccountId] = state;
      await _persistLocalLabels(_currentAccountId, state);
    }

    // 1. Instantly remove deleted label from all emails in state and disk storage
    ref.read(emailProvider.notifier).onLabelDeleted(targetId, targetName);

    // 2. Clear activeLabel if viewing this deleted label
    final activeLabel = ref.read(appUiProvider).activeLabel;
    if (activeLabel != null &&
        (activeLabel.toLowerCase() == targetName.toLowerCase() ||
            activeLabel.toLowerCase() == targetId.toLowerCase())) {
      ref.read(appUiProvider.notifier).selectFolder('Inbox');
    }

    // 3. Delete from backend API
    await LabelRepository.deleteLabel(targetId);
  }
}

final customLabelsProvider =
    StateNotifierProvider<CustomLabelsNotifier, List<LabelModel>>((ref) {
      return CustomLabelsNotifier(ref);
    });

final desktopRightRailVisibleProvider = StateProvider<bool>((ref) => true);
