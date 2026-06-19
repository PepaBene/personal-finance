import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/di/providers.dart';
import 'src/core/env/app_config.dart';
import 'src/core/preferences/preferences_controller.dart';
import 'src/data/preferences/secure_preferences_service.dart';

/// Entry point. Initializes the Supabase client (configuration, not network —
/// the app then runs fully offline, FR-SYNC-01) and starts the Riverpod tree.
///
/// Provide the backend config at build/run time (no secrets in source —
/// docs/09 §8):
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=... \
///   --dart-define=SUPABASE_ANON_KEY=... \
///   --dart-define=POWERSYNC_URL=...
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();

  if (!config.hasCloud) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  // Load device-local preferences before the first frame so the chosen locale,
  // theme, and contrast apply immediately (no flash of the wrong theme).
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final preferences = await const SecurePreferencesService(storage).load();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        initialPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const LedgerlyApp(),
    ),
  );
}

/// Shown when the backend dart-defines are absent — clearer than a stack trace.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Backend not configured.\n\n'
              'Run with --dart-define=SUPABASE_URL=..., '
              'SUPABASE_ANON_KEY=..., and POWERSYNC_URL=...\n'
              'See README.md and supabase/README.md.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
