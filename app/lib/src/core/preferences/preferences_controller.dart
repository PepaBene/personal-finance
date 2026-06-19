import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/preferences.dart';
import '../../data/preferences/secure_preferences_service.dart';
import '../di/providers.dart';

final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => SecurePreferencesService(ref.watch(secureStorageProvider)),
);

/// The preferences loaded synchronously at startup (overridden in `main`), so
/// the first frame already reflects the user's locale/theme without a flash.
final initialPreferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences.defaults,
);

/// Live, persisted user preferences. Reads start from [initialPreferencesProvider]
/// and every mutation writes through to the [PreferencesService].
final preferencesProvider =
    NotifierProvider<PreferencesController, AppPreferences>(
  PreferencesController.new,
);

class PreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => ref.read(initialPreferencesProvider);

  Future<void> _update(AppPreferences next) async {
    state = next;
    await ref.read(preferencesServiceProvider).save(next);
  }

  Future<void> setLocaleTag(String? tag) =>
      _update(state.copyWith(localeTag: () => tag));

  Future<void> setThemeMode(AppThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setHighContrast(bool value) =>
      _update(state.copyWith(highContrast: value));

  Future<void> setReduceMotion(bool value) =>
      _update(state.copyWith(reduceMotion: value));

  Future<void> setBiometricEnabled(bool value) =>
      _update(state.copyWith(biometricEnabled: value));

  Future<void> setAutoLockMinutes(int minutes) =>
      _update(state.copyWith(autoLockMinutes: minutes));
}

/// Flutter `ThemeMode` derived from the stored [AppThemeMode].
ThemeMode flutterThemeMode(AppThemeMode mode) => switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
