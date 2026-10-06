import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_exception.dart';
import '../models/signature_model.dart';
import '../models/two_factor_model.dart';
import '../models/user_settings_model.dart';
import 'account_provider.dart';
import 'repositories/settings_repository.dart';

/// Immutable state containing all settings, signatures, and customization values.
///
/// [accountEmail] identifies which account this state belongs to.
/// All backend-derived fields are nullable — a null value means "not yet loaded"
/// and must never be shown as if it were real user data.
class SettingsState {
  /// The account email this state belongs to. Null = not yet loaded.
  final String? accountEmail;

  final UserSettings? settings;
  final List<SignatureModel> signatures;

  // Nullable: null means not yet loaded from backend.
  final String? currentLanguage;
  final bool? spellingCheckEnabled;
  final bool? grammarCheckEnabled;
  final bool? autoCorrectEnabled;
  final bool? smartComposeEnabled;
  final String? fontFamily;
  final String? textStyleFontSize;
  final String? textColor;
  final String? wallpaper;

  final bool isLoading;
  final bool isSaving;
  final String? error;
  final TwoFactorSetupData? setup2faData;

  const SettingsState({
    this.accountEmail,
    this.settings,
    this.signatures = const [],
    this.currentLanguage,
    this.spellingCheckEnabled,
    this.grammarCheckEnabled,
    this.autoCorrectEnabled,
    this.smartComposeEnabled,
    this.fontFamily,
    this.textStyleFontSize,
    this.textColor,
    this.wallpaper,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.setup2faData,
  });

  /// Returns true when data has been successfully loaded from the backend.
  bool get isLoaded => settings != null && !isLoading;

  SettingsState copyWith({
    String? accountEmail,
    UserSettings? settings,
    List<SignatureModel>? signatures,
    String? currentLanguage,
    bool? spellingCheckEnabled,
    bool? grammarCheckEnabled,
    bool? autoCorrectEnabled,
    bool? smartComposeEnabled,
    String? fontFamily,
    String? textStyleFontSize,
    String? textColor,
    String? wallpaper,
    bool? isLoading,
    bool? isSaving,
    String? error,
    TwoFactorSetupData? setup2faData,
    bool clearError = false,
    bool clearSettings = false,
    bool clearSetup2fa = false,
  }) {
    return SettingsState(
      accountEmail: accountEmail ?? this.accountEmail,
      settings: clearSettings ? null : (settings ?? this.settings),
      signatures: signatures ?? this.signatures,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      spellingCheckEnabled: spellingCheckEnabled ?? this.spellingCheckEnabled,
      grammarCheckEnabled: grammarCheckEnabled ?? this.grammarCheckEnabled,
      autoCorrectEnabled: autoCorrectEnabled ?? this.autoCorrectEnabled,
      smartComposeEnabled: smartComposeEnabled ?? this.smartComposeEnabled,
      fontFamily: fontFamily ?? this.fontFamily,
      textStyleFontSize: textStyleFontSize ?? this.textStyleFontSize,
      textColor: textColor ?? this.textColor,
      wallpaper: wallpaper ?? this.wallpaper,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      setup2faData: clearSetup2fa ? null : (setup2faData ?? this.setup2faData),
    );
  }
}

/// Notifier handling all Settings Riverpod state and API dispatching.
class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;

  /// Race-condition guard: tracks which account is currently being loaded.
  String? _loadingAccountId;

  SettingsNotifier(this._ref) : super(const SettingsState());

  String get _activeAccountEmail =>
      _ref.read(activeAccountProvider).email.trim().toLowerCase();

  /// Loads full settings for the active account.
  /// Safe to call multiple times; guards against duplicate and stale responses.
  Future<void> loadAllSettings({bool force = false}) async {
    final accountEmail = _activeAccountEmail;

    // Guard: skip duplicate load for same account unless forced
    if (!force && state.isLoading && _loadingAccountId == accountEmail) {
      print('[SETTINGS] Already loading for $accountEmail — skipping duplicate');
      return;
    }

    // Guard: skip if already loaded for same account with no error
    if (!force &&
        state.accountEmail == accountEmail &&
        state.isLoaded &&
        state.error == null) {
      print('[SETTINGS] Already loaded for $accountEmail — skipping');
      return;
    }

    // Detect and log account change
    if (state.accountEmail != null && state.accountEmail != accountEmail) {
      print('[SETTINGS] Account changed: ${state.accountEmail} → $accountEmail');
      print('[SETTINGS] Clearing previous account settings');
    }

    _loadingAccountId = accountEmail;
    print('[SETTINGS] Loading settings for: $accountEmail');

    // Reset to a clean loading state for this account (clears all old data)
    state = SettingsState(
      accountEmail: accountEmail,
      isLoading: true,
    );

    try {
      // 1. GET /api/users/settings
      UserSettings? fullSettings;
      try {
        fullSettings = await SettingsRepository.getSettings();
        print('[SETTINGS] Response received');
        print('[SETTINGS] Parsed settings for: $accountEmail');
      } catch (e) {
        print('[SETTINGS] getSettings error: $e');
      }

      // Race-condition guard after every await
      if (_loadingAccountId != accountEmail) {
        print('[SETTINGS] Discarding stale response for: $accountEmail (now: $_loadingAccountId)');
        return;
      }

      // 2. GET /api/settings/language
      String? lang = fullSettings?.language;
      try {
        final fetched = await SettingsRepository.getLanguage();
        lang = fetched;
      } catch (_) {}

      if (_loadingAccountId != accountEmail) return;

      // 3. GET /api/settings/composing
      bool? spell = fullSettings?.spellingCheckEnabled;
      bool? grammar = fullSettings?.grammarCheckEnabled;
      bool? autoCorr = fullSettings?.autoCorrectEnabled;
      bool? smartComp = fullSettings?.smartComposeEnabled;
      try {
        final composing = await SettingsRepository.getComposing();
        if (composing.containsKey('spellingCheckEnabled')) spell = composing['spellingCheckEnabled'];
        if (composing.containsKey('grammarCheckEnabled')) grammar = composing['grammarCheckEnabled'];
        if (composing.containsKey('autoCorrectEnabled')) autoCorr = composing['autoCorrectEnabled'];
        if (composing.containsKey('smartComposeEnabled')) smartComp = composing['smartComposeEnabled'];
      } catch (_) {}

      if (_loadingAccountId != accountEmail) return;

      // 4. GET /api/settings/text-style
      String? font = fullSettings?.fontFamily;
      String? size = fullSettings?.textStyleFontSize;
      String? color = fullSettings?.textColor;
      try {
        final textStyle = await SettingsRepository.getTextStyle();
        if (textStyle.containsKey('fontFamily')) font = textStyle['fontFamily'];
        if (textStyle.containsKey('fontSize')) size = textStyle['fontSize'];
        if (textStyle.containsKey('textColor')) color = textStyle['textColor'];
      } catch (_) {}

      if (_loadingAccountId != accountEmail) return;

      // 5. GET /api/settings/wallpaper
      String? wall = fullSettings?.wallpaper;
      try {
        final wp = await SettingsRepository.getWallpaper();
        if (wp != null) wall = wp;
      } catch (_) {}

      if (_loadingAccountId != accountEmail) return;

      // 6. GET /api/signatures
      List<SignatureModel> sigs = [];
      try {
        sigs = await SettingsRepository.getSignatures();
      } catch (_) {}

      if (_loadingAccountId != accountEmail) return;

      // Final state update
      print('[SETTINGS] Settings loaded for: $accountEmail');
      print('[SETTINGS] Provider state updated');

      state = SettingsState(
        accountEmail: accountEmail,
        settings: fullSettings,
        signatures: sigs,
        currentLanguage: lang,
        spellingCheckEnabled: spell,
        grammarCheckEnabled: grammar,
        autoCorrectEnabled: autoCorr,
        smartComposeEnabled: smartComp,
        fontFamily: font,
        textStyleFontSize: size,
        textColor: color,
        wallpaper: wall,
        isLoading: false,
        error: null,
      );
    } on ApiException catch (e) {
      if (_loadingAccountId == accountEmail) {
        state = SettingsState(
          accountEmail: accountEmail,
          isLoading: false,
          error: e.message,
        );
      }
    } catch (e) {
      if (_loadingAccountId == accountEmail) {
        state = SettingsState(
          accountEmail: accountEmail,
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Partial update to general settings: PATCH /api/users/settings.
  Future<({bool success, String? message})> updateGeneralSettings(
    Map<String, dynamic> partialUpdates,
  ) async {
    print('[SETTINGS] PATCH payload fields = ${partialUpdates.keys.toList()}');
    try {
      final updated = await SettingsRepository.updateSettings(partialUpdates);
      print('[SETTINGS] Update success');
      state = state.copyWith(settings: updated, clearError: true);
      print('[SETTINGS] Provider state synchronized');
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Update language: PUT /api/settings/language
  Future<({bool success, String? message})> updateLanguage(
    String languageCode,
  ) async {
    try {
      await SettingsRepository.updateLanguage(languageCode);
      state = state.copyWith(
        currentLanguage: languageCode,
        settings: state.settings?.copyWith(language: languageCode),
        clearError: true,
      );
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Update composing & AI suggestions: PUT /api/settings/composing
  Future<({bool success, String? message})> updateComposing({
    required bool spellingCheckEnabled,
    required bool grammarCheckEnabled,
    required bool autoCorrectEnabled,
    required bool smartComposeEnabled,
  }) async {
    try {
      await SettingsRepository.updateComposing(
        spellingCheckEnabled: spellingCheckEnabled,
        grammarCheckEnabled: grammarCheckEnabled,
        autoCorrectEnabled: autoCorrectEnabled,
        smartComposeEnabled: smartComposeEnabled,
      );
      state = state.copyWith(
        spellingCheckEnabled: spellingCheckEnabled,
        grammarCheckEnabled: grammarCheckEnabled,
        autoCorrectEnabled: autoCorrectEnabled,
        smartComposeEnabled: smartComposeEnabled,
        settings: state.settings?.copyWith(
          spellingCheckEnabled: spellingCheckEnabled,
          grammarCheckEnabled: grammarCheckEnabled,
          autoCorrectEnabled: autoCorrectEnabled,
          smartComposeEnabled: smartComposeEnabled,
        ),
        clearError: true,
      );
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Update typography & text style: PUT /api/settings/text-style
  Future<({bool success, String? message})> updateTextStyle({
    required String fontFamily,
    required String fontSize,
    String textColor = '#000000',
  }) async {
    try {
      await SettingsRepository.updateTextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
      );
      state = state.copyWith(
        fontFamily: fontFamily,
        textStyleFontSize: fontSize,
        textColor: textColor,
        settings: state.settings?.copyWith(
          fontFamily: fontFamily,
          textStyleFontSize: fontSize,
          textColor: textColor,
        ),
        clearError: true,
      );
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Update wallpaper: PUT /api/settings/wallpaper
  Future<({bool success, String? message})> updateWallpaper(
    String wallpaper,
  ) async {
    try {
      await SettingsRepository.updateWallpaper(wallpaper);
      state = state.copyWith(
        wallpaper: wallpaper,
        settings: state.settings?.copyWith(wallpaper: wallpaper),
        clearError: true,
      );
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Reset wallpaper: POST/PUT /api/settings/wallpaper/reset
  Future<({bool success, String? message})> resetWallpaper() async {
    try {
      await SettingsRepository.resetWallpaper();
      state = state.copyWith(
        wallpaper: '',
        settings: state.settings?.copyWith(wallpaper: ''),
        clearError: true,
      );
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Create signature: POST /api/signatures
  Future<({bool success, SignatureModel? signature, String? message})>
      createSignature({
    required String name,
    required String content,
    bool isDefault = false,
  }) async {
    try {
      final newSig = await SettingsRepository.createSignature(
        name: name,
        content: content,
        isDefault: isDefault,
      );
      final sigs = await SettingsRepository.getSignatures();
      state = state.copyWith(signatures: sigs, clearError: true);
      return (success: true, signature: newSig, message: null);
    } on ApiException catch (e) {
      return (success: false, signature: null, message: e.message);
    } catch (e) {
      return (success: false, signature: null, message: e.toString());
    }
  }

  /// Update signature: PUT /api/signatures/{id}
  Future<({bool success, String? message})> updateSignature({
    required String id,
    required String name,
    required String content,
    bool isDefault = false,
  }) async {
    try {
      await SettingsRepository.updateSignature(
        id: id,
        name: name,
        content: content,
        isDefault: isDefault,
      );
      final sigs = await SettingsRepository.getSignatures();
      state = state.copyWith(signatures: sigs, clearError: true);
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Delete signature: DELETE /api/signatures/{id}
  Future<({bool success, String? message})> deleteSignature(String id) async {
    try {
      await SettingsRepository.deleteSignature(id);
      final updated = state.signatures.where((s) => s.id != id).toList();
      state = state.copyWith(signatures: updated, clearError: true);
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Set default signature: PATCH /api/signatures/{id}/default
  Future<({bool success, String? message})> setDefaultSignature(
    String id,
  ) async {
    try {
      await SettingsRepository.setDefaultSignature(id);
      final updated = state.signatures.map((s) {
        return s.copyWith(isDefault: s.id == id);
      }).toList();
      state = state.copyWith(signatures: updated, clearError: true);
      return (success: true, message: null);
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Setup 2FA: POST /api/users/2fa/setup
  Future<({bool success, TwoFactorSetupData? data, String? message})>
      setup2FA() async {
    try {
      final setupData = await SettingsRepository.setup2FA();
      state = state.copyWith(setup2faData: setupData, clearError: true);
      return (success: true, data: setupData, message: null);
    } on ApiException catch (e) {
      return (success: false, data: null, message: e.message);
    } catch (e) {
      return (success: false, data: null, message: e.toString());
    }
  }

  /// Verify 2FA code: POST /api/users/2fa/verify
  Future<({bool success, String? message})> verify2FA(String code) async {
    try {
      final verified = await SettingsRepository.verify2FA(code);
      if (verified) {
        final updated = state.settings?.copyWith(twoFactorEnabled: true);
        if (updated != null) {
          state = state.copyWith(settings: updated, clearError: true);
        }
        return (success: true, message: null);
      } else {
        return (success: false, message: 'Invalid 2FA verification code');
      }
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Disable 2FA: POST /api/users/2fa/disable
  Future<({bool success, String? message})> disable2FA() async {
    try {
      final disabled = await SettingsRepository.disable2FA();
      if (disabled) {
        final updated = state.settings?.copyWith(twoFactorEnabled: false);
        if (updated != null) {
          state = state.copyWith(settings: updated, clearError: true);
        }
        return (success: true, message: null);
      } else {
        return (success: false, message: 'Failed to disable 2FA');
      }
    } on ApiException catch (e) {
      return (success: false, message: e.message);
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }

  /// Clears state when switching accounts or signing out.
  void clear() {
    _loadingAccountId = null;
    state = const SettingsState();
  }
}

/// Dedicated provider for Settings state management.
///
/// The provider factory does NOT trigger a network load synchronously
/// (which would cause "Tried to modify provider while widget tree was building").
/// Loading is triggered from the screen via addPostFrameCallback or ref.listen.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
