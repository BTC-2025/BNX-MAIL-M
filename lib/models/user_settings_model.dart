class UserSettings {
  final int? storageLimit;
  final String? phoneNumber;
  final String? location;
  final String? jobTitle;

  final bool inboxNotifications;
  final bool sentNotifications;
  final bool starredNotifications;
  final bool snoozedNotifications;

  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool quietHoursEnabled;

  final String? themeMode;
  final String? accentColor;
  final String? fontSize;
  final String? density;

  final String? profilePictureUrl;

  final int? undoSendDelay;

  final bool spellingCheckEnabled;
  final bool grammarCheckEnabled;
  final bool autoCorrectEnabled;
  final bool smartComposeEnabled;

  final String? readingPaneMode;

  final bool twoFactorEnabled;
  final bool biometricsEnabled;

  final String? language;

  final String? fontFamily;
  final String? textStyleFontSize;
  final String? textColor;

  final bool casboxAccepted;
  final String? wallpaper;

  const UserSettings({
    this.storageLimit,
    this.phoneNumber,
    this.location,
    this.jobTitle,
    this.inboxNotifications = true,
    this.sentNotifications = false,
    this.starredNotifications = true,
    this.snoozedNotifications = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.quietHoursEnabled = false,
    this.themeMode,
    this.accentColor,
    this.fontSize,
    this.density,
    this.profilePictureUrl,
    this.undoSendDelay,
    this.spellingCheckEnabled = true,
    this.grammarCheckEnabled = true,
    this.autoCorrectEnabled = true,
    this.smartComposeEnabled = true,
    this.readingPaneMode,
    this.twoFactorEnabled = false,
    this.biometricsEnabled = false,
    this.language,
    this.fontFamily,
    this.textStyleFontSize,
    this.textColor,
    this.casboxAccepted = true,
    this.wallpaper,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    int? parseDelay(dynamic val) {
      if (val is int) return val;
      if (val != null) {
        final match = RegExp(r'\d+').firstMatch(val.toString());
        if (match != null) return int.tryParse(match.group(0)!);
      }
      return null;
    }

    int? parseStorage(dynamic val) {
      if (val is int) return val;
      if (val != null) return int.tryParse(val.toString());
      return null;
    }

    return UserSettings(
      storageLimit: parseStorage(json['storageLimit']),
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone']?.toString(),
      location: json['location']?.toString(),
      jobTitle: json['jobTitle']?.toString(),
      inboxNotifications: json['inboxNotifications'] == true ||
          json['inboxMailAlerts'] == true,
      sentNotifications: json['sentNotifications'] == true ||
          json['sentConfirmationAlerts'] == true,
      starredNotifications: json['starredNotifications'] == true ||
          json['starredEmailsAlerts'] == true,
      snoozedNotifications: json['snoozedNotifications'] == true ||
          json['snoozedReminders'] == true,
      soundEnabled: json['soundEnabled'] == true ||
          json['playAlertSound'] == true,
      vibrationEnabled: json['vibrationEnabled'] == true ||
          json['enableHapticVibration'] == true,
      quietHoursEnabled: json['quietHoursEnabled'] == true ||
          json['muteNotificationsSchedule'] == true,
      themeMode: json['themeMode']?.toString() ?? json['visualTheme']?.toString(),
      accentColor: json['accentColor']?.toString(),
      fontSize: json['fontSize']?.toString(),
      density: json['density']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      undoSendDelay: parseDelay(json['undoSendDelay']),
      spellingCheckEnabled: json['spellingCheckEnabled'] != false,
      grammarCheckEnabled: json['grammarCheckEnabled'] != false,
      autoCorrectEnabled: json['autoCorrectEnabled'] != false,
      smartComposeEnabled: json['smartComposeEnabled'] != false,
      readingPaneMode: json['readingPaneMode']?.toString(),
      twoFactorEnabled: json['twoFactorEnabled'] == true ||
          json['twoFactorAuth'] == true,
      biometricsEnabled: json['biometricsEnabled'] == true ||
          json['enableBiometrics'] == true,
      language: json['language']?.toString(),
      fontFamily: json['fontFamily']?.toString(),
      textStyleFontSize: json['textStyleFontSize']?.toString() ??
          json['fontSize']?.toString(),
      textColor: json['textColor']?.toString(),
      casboxAccepted: json['casboxAccepted'] != false,
      wallpaper: json['wallpaper']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (storageLimit != null) 'storageLimit': storageLimit,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (location != null) 'location': location,
        if (jobTitle != null) 'jobTitle': jobTitle,
        'inboxNotifications': inboxNotifications,
        'sentNotifications': sentNotifications,
        'starredNotifications': starredNotifications,
        'snoozedNotifications': snoozedNotifications,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'quietHoursEnabled': quietHoursEnabled,
        if (themeMode != null) 'themeMode': themeMode,
        if (accentColor != null) 'accentColor': accentColor,
        if (fontSize != null) 'fontSize': fontSize,
        if (density != null) 'density': density,
        if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
        if (undoSendDelay != null) 'undoSendDelay': undoSendDelay,
        'spellingCheckEnabled': spellingCheckEnabled,
        'grammarCheckEnabled': grammarCheckEnabled,
        'autoCorrectEnabled': autoCorrectEnabled,
        'smartComposeEnabled': smartComposeEnabled,
        if (readingPaneMode != null) 'readingPaneMode': readingPaneMode,
        'twoFactorEnabled': twoFactorEnabled,
        'biometricsEnabled': biometricsEnabled,
        if (language != null) 'language': language,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (textStyleFontSize != null) 'textStyleFontSize': textStyleFontSize,
        if (textColor != null) 'textColor': textColor,
        'casboxAccepted': casboxAccepted,
        if (wallpaper != null) 'wallpaper': wallpaper,
      };

  UserSettings copyWith({
    int? storageLimit,
    String? phoneNumber,
    String? location,
    String? jobTitle,
    bool? inboxNotifications,
    bool? sentNotifications,
    bool? starredNotifications,
    bool? snoozedNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? quietHoursEnabled,
    String? themeMode,
    String? accentColor,
    String? fontSize,
    String? density,
    String? profilePictureUrl,
    int? undoSendDelay,
    bool? spellingCheckEnabled,
    bool? grammarCheckEnabled,
    bool? autoCorrectEnabled,
    bool? smartComposeEnabled,
    String? readingPaneMode,
    bool? twoFactorEnabled,
    bool? biometricsEnabled,
    String? language,
    String? fontFamily,
    String? textStyleFontSize,
    String? textColor,
    bool? casboxAccepted,
    String? wallpaper,
  }) {
    return UserSettings(
      storageLimit: storageLimit ?? this.storageLimit,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      jobTitle: jobTitle ?? this.jobTitle,
      inboxNotifications: inboxNotifications ?? this.inboxNotifications,
      sentNotifications: sentNotifications ?? this.sentNotifications,
      starredNotifications: starredNotifications ?? this.starredNotifications,
      snoozedNotifications: snoozedNotifications ?? this.snoozedNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      fontSize: fontSize ?? this.fontSize,
      density: density ?? this.density,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      undoSendDelay: undoSendDelay ?? this.undoSendDelay,
      spellingCheckEnabled: spellingCheckEnabled ?? this.spellingCheckEnabled,
      grammarCheckEnabled: grammarCheckEnabled ?? this.grammarCheckEnabled,
      autoCorrectEnabled: autoCorrectEnabled ?? this.autoCorrectEnabled,
      smartComposeEnabled: smartComposeEnabled ?? this.smartComposeEnabled,
      readingPaneMode: readingPaneMode ?? this.readingPaneMode,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      language: language ?? this.language,
      fontFamily: fontFamily ?? this.fontFamily,
      textStyleFontSize: textStyleFontSize ?? this.textStyleFontSize,
      textColor: textColor ?? this.textColor,
      casboxAccepted: casboxAccepted ?? this.casboxAccepted,
      wallpaper: wallpaper ?? this.wallpaper,
    );
  }
}
