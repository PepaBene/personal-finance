import 'dart:convert';

/// Theme selection (maps to Flutter's `ThemeMode` in the UI layer).
enum AppThemeMode { system, light, dark }

/// Device-local user preferences (docs/04 §4.4: device prefs stay local, not
/// synced). Pure data — no Flutter types — so it is unit-testable and the
/// application layer stays framework-free. The UI maps [themeMode]/[localeTag]
/// to Flutter `ThemeMode`/`Locale`.
class AppPreferences {
  const AppPreferences({
    this.localeTag,
    this.themeMode = AppThemeMode.system,
    this.highContrast = false,
    this.reduceMotion = false,
    this.biometricEnabled = false,
    this.autoLockMinutes = 5,
  });

  /// BCP-47 language tag (e.g. 'en', 'cs'); null = follow the system locale.
  final String? localeTag;
  final AppThemeMode themeMode;

  /// Force the high-contrast color scheme regardless of system setting (NFR-07).
  final bool highContrast;

  /// Honour reduced motion even if the OS doesn't report it (NFR-07).
  final bool reduceMotion;

  /// Whether biometric unlock is enrolled on this device (FR-SEC-03).
  final bool biometricEnabled;

  /// Idle minutes before auto-lock; 0 disables auto-lock (FR-SEC-05).
  final int autoLockMinutes;

  static const defaults = AppPreferences();

  AppPreferences copyWith({
    String? Function()? localeTag,
    AppThemeMode? themeMode,
    bool? highContrast,
    bool? reduceMotion,
    bool? biometricEnabled,
    int? autoLockMinutes,
  }) {
    return AppPreferences(
      localeTag: localeTag != null ? localeTag() : this.localeTag,
      themeMode: themeMode ?? this.themeMode,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'localeTag': localeTag,
        'themeMode': themeMode.name,
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
        'biometricEnabled': biometricEnabled,
        'autoLockMinutes': autoLockMinutes,
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    AppThemeMode mode(String? n) => AppThemeMode.values.firstWhere(
          (m) => m.name == n,
          orElse: () => AppThemeMode.system,
        );
    return AppPreferences(
      localeTag: json['localeTag'] as String?,
      themeMode: mode(json['themeMode'] as String?),
      highContrast: json['highContrast'] as bool? ?? false,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      autoLockMinutes: json['autoLockMinutes'] as int? ?? 5,
    );
  }

  String encode() => jsonEncode(toJson());

  static AppPreferences decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      return AppPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.localeTag == localeTag &&
      other.themeMode == themeMode &&
      other.highContrast == highContrast &&
      other.reduceMotion == reduceMotion &&
      other.biometricEnabled == biometricEnabled &&
      other.autoLockMinutes == autoLockMinutes;

  @override
  int get hashCode => Object.hash(localeTag, themeMode, highContrast,
      reduceMotion, biometricEnabled, autoLockMinutes);
}

/// Loads/saves [AppPreferences]. Implemented in `data/` (device-local store).
abstract interface class PreferencesService {
  Future<AppPreferences> load();
  Future<void> save(AppPreferences preferences);
}
