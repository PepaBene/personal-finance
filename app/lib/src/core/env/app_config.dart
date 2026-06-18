/// Compile-time configuration read from `--dart-define` (no secrets in source —
/// docs/09 §8). Only the Supabase *publishable/anon* key ships in the client;
/// it is safe because RLS gates every row. The service-role key never ships.
///
/// Example:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ... \
///   --dart-define=POWERSYNC_URL=https://xyz.powersync.journeyapps.com
/// ```
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.powersyncUrl,
    required this.baseCurrencyCode,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    powersyncUrl: String.fromEnvironment('POWERSYNC_URL'),
    baseCurrencyCode: String.fromEnvironment(
      'BASE_CURRENCY',
      defaultValue: 'EUR',
    ),
  );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String powersyncUrl;
  final String baseCurrencyCode;

  /// True only when the cloud backend is configured. When false the app still
  /// runs fully offline (FR-SYNC-01) — sign-in and sync are simply disabled.
  bool get hasCloud =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      powersyncUrl.isNotEmpty;
}
