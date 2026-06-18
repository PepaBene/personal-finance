import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/di/providers.dart';
import 'src/core/env/app_config.dart';

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

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
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
