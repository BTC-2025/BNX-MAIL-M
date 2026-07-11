import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/label_model.dart';
import '../core/theme/colors.dart';

enum ComposeStatus { closed, minimized, normal, maximized }

// Sentinel object to distinguish "not provided" from intentional null
const _absent = Object();

class AppUiState {
  final String activeFolder; // 'Inbox', 'Starred', 'Snoozed', 'Sent', 'Draft', 'Trash', 'Archive', 'Scheduled', 'Spam', 'All Mail', 'Templates', 'Subscriptions', 'Colab'
  final String? activeLabel; // If filtering by label, e.g., 'Work'
  final String? selectedEmailId;
  final Set<String> selectedEmailIds;
  final String searchQuery;
  final bool isDarkMode;
  final bool isSidebarCollapsed;
  final ComposeStatus composeStatus;
  final String activeRightUtility; // 'Calendar', 'Keep', 'Tasks', or 'none'

  // Compose dialog fields for state persistence when resizing / switching views
  final String composeTo;
  final String composeSubject;
  final String composeBody;

  const AppUiState({
    required this.activeFolder,
    this.activeLabel,
    this.selectedEmailId,
    this.selectedEmailIds = const {},
    required this.searchQuery,
    required this.isDarkMode,
    required this.isSidebarCollapsed,
    required this.composeStatus,
    required this.activeRightUtility,
    this.composeTo = '',
    this.composeSubject = '',
    this.composeBody = '',
  });

  // Use Object() sentinel so nullable fields can be explicitly set to null
  AppUiState copyWith({
    String? activeFolder,
    Object? activeLabel = _absent,
    Object? selectedEmailId = _absent,
    Set<String>? selectedEmailIds,
    String? searchQuery,
    bool? isDarkMode,
    bool? isSidebarCollapsed,
    ComposeStatus? composeStatus,
    String? activeRightUtility,
    String? composeTo,
    String? composeSubject,
    String? composeBody,
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
      searchQuery: searchQuery ?? this.searchQuery,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isSidebarCollapsed: isSidebarCollapsed ?? this.isSidebarCollapsed,
      composeStatus: composeStatus ?? this.composeStatus,
      activeRightUtility: activeRightUtility ?? this.activeRightUtility,
      composeTo: composeTo ?? this.composeTo,
      composeSubject: composeSubject ?? this.composeSubject,
      composeBody: composeBody ?? this.composeBody,
    );
  }
}

class AppUiNotifier extends StateNotifier<AppUiState> {
  AppUiNotifier()
      : super(const AppUiState(
          activeFolder: 'Inbox',
          activeLabel: null,
          selectedEmailId: null,
          selectedEmailIds: {},
          searchQuery: '',
          isDarkMode: false,
          isSidebarCollapsed: false,
          composeStatus: ComposeStatus.closed,
          activeRightUtility: 'Calendar', // Calendar open initially by default
        ));

  void selectFolder(String folder) {
    state = state.copyWith(
      activeFolder: folder,
      activeLabel: null, // Now correctly clears the label
      selectedEmailId: null, // Also clear selected email
      selectedEmailIds: {},
    );
  }

  void selectLabel(String label) {
    state = state.copyWith(
      activeLabel: label,
      activeFolder: 'Labels', // Set active folder to Labels
      selectedEmailId: null, // Clear selected email when switching label
      selectedEmailIds: {},
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
    state = state.copyWith(selectedEmailIds: newSelection);
  }

  void clearSelection() {
    state = state.copyWith(selectedEmailIds: {});
  }

  void selectAllEmails(List<String> emailIds) {
    final allSelected = emailIds.every((id) => state.selectedEmailIds.contains(id));
    if (allSelected && emailIds.isNotEmpty) {
      // Deselect all if all are already selected
      state = state.copyWith(selectedEmailIds: {});
    } else {
      state = state.copyWith(selectedEmailIds: Set<String>.from(emailIds));
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

  void updateComposeDraft({String? to, String? subject, String? body}) {
    state = state.copyWith(
      composeTo: to ?? state.composeTo,
      composeSubject: subject ?? state.composeSubject,
      composeBody: body ?? state.composeBody,
    );
  }

  void clearComposeDraft() {
    state = state.copyWith(
      composeTo: '',
      composeSubject: '',
      composeBody: '',
    );
  }

  void setActiveRightUtility(String utility) {
    if (state.activeRightUtility == utility) {
      state = state.copyWith(activeRightUtility: 'none');
    } else {
      state = state.copyWith(activeRightUtility: utility);
    }
  }
}

final appUiProvider = StateNotifierProvider<AppUiNotifier, AppUiState>((ref) {
  return AppUiNotifier();
});

final fabExtensionProvider = StateProvider<bool>((ref) => true);

class CustomLabelsNotifier extends StateNotifier<List<LabelModel>> {
  CustomLabelsNotifier() : super([
    const LabelModel(id: 'work', name: 'Work', color: BNXColors.labelWork),
    const LabelModel(id: 'personal', name: 'Personal', color: BNXColors.labelPersonal),
  ]);

  void addLabel(String name, Color color) {
    final id = name.toLowerCase().replaceAll(' ', '_');
    // Prevent duplicates
    if (state.any((l) => l.name.toLowerCase() == name.toLowerCase())) return;
    state = [
      ...state,
      LabelModel(id: id, name: name, color: color),
    ];
  }
}

final customLabelsProvider = StateNotifierProvider<CustomLabelsNotifier, List<LabelModel>>((ref) {
  return CustomLabelsNotifier();
});
