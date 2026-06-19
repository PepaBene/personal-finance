import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/preferences.dart';

void main() {
  test('defaults are sensible', () {
    const p = AppPreferences.defaults;
    expect(p.localeTag, isNull);
    expect(p.themeMode, AppThemeMode.system);
    expect(p.highContrast, isFalse);
    expect(p.reduceMotion, isFalse);
    expect(p.biometricEnabled, isFalse);
    expect(p.autoLockMinutes, 5);
  });

  test('round-trips through JSON', () {
    const p = AppPreferences(
      localeTag: 'cs',
      themeMode: AppThemeMode.dark,
      highContrast: true,
      reduceMotion: true,
      biometricEnabled: true,
      autoLockMinutes: 2,
    );
    final decoded = AppPreferences.decode(p.encode());
    expect(decoded, p);
  });

  test('decode tolerates null/garbage and unknown theme', () {
    expect(AppPreferences.decode(null), AppPreferences.defaults);
    expect(AppPreferences.decode(''), AppPreferences.defaults);
    expect(AppPreferences.decode('not json'), AppPreferences.defaults);
    final t = AppPreferences.decode('{"themeMode":"plaid"}');
    expect(t.themeMode, AppThemeMode.system);
  });

  test('copyWith can clear the locale back to system', () {
    const p = AppPreferences(localeTag: 'en');
    expect(p.copyWith(localeTag: () => null).localeTag, isNull);
    // Omitting localeTag preserves the current value.
    expect(p.copyWith(themeMode: AppThemeMode.light).localeTag, 'en');
  });
}
