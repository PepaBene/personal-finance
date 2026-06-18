import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/app_lock_service.dart';
import '../../application/auth_service.dart';
import '../../application/sync_service.dart';
import '../../application/transaction_service.dart';
import '../../data/crypto/argon2_app_lock_service.dart';
import '../../data/local/app_database.dart';
import '../../data/local/encrypted_executor.dart';
import '../../data/remote/powersync_factory.dart';
import '../../data/remote/powersync_sync_service.dart';
import '../../data/remote/supabase_powersync_connector.dart';
import '../../data/services/drift_transaction_service.dart';
import '../../data/services/supabase_auth_service.dart';
import '../env/app_config.dart';

/// Composition root (docs/03 §3, docs/13 §8.2). Every port is bound to its
/// concrete implementation here and *only* here, so each is swappable in one
/// line and overridable with fakes in tests.

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

// --- Auth ---------------------------------------------------------------

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authServiceProvider = Provider<AuthService>((ref) {
  final service = SupabaseAuthService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authServiceProvider).watch(),
);

// --- App lock / encryption key -----------------------------------------

final appLockServiceProvider = Provider<AppLockService>(
  (ref) => Argon2AppLockService(ref.watch(secureStorageProvider)),
);

final lockStateProvider = StreamProvider<LockState>(
  (ref) => ref.watch(appLockServiceProvider).watch(),
);

/// The in-memory database key produced by a successful unlock. `null` while the
/// app is locked. Set by the lock flow (features/lock), cleared on sign-out.
final databaseKeyProvider = StateProvider<Uint8List?>((ref) => null);

// --- Local database -----------------------------------------------------

/// Opens the encrypted local DB once a key is available. Throws while locked —
/// the router guard ensures DB-backed screens are only reached when unlocked.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final key = ref.watch(databaseKeyProvider);
  if (key == null) {
    throw StateError('Database is locked: no encryption key available.');
  }
  final db = AppDatabase(openEncryptedExecutor(dbName: 'ledgerly', key: key));
  ref.onDispose(db.close);
  return db;
});

final transactionServiceProvider = Provider<TransactionService>(
  (ref) => DriftTransactionService(
    ref.watch(appDatabaseProvider),
    ref.watch(authServiceProvider),
  ),
);

// --- Sync (PowerSync) ---------------------------------------------------

/// Builds the PowerSync-backed sync service when the cloud is configured;
/// returns `null` otherwise so the app stays fully usable offline
/// (FR-SYNC-01). This is the Phase 0 sync seam (see PowerSyncSyncService).
final syncServiceProvider = FutureProvider<SyncService?>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (!config.hasCloud) return null;

  final db = await openPowerSyncDatabase();
  ref.onDispose(db.close);

  final connector = SupabasePowerSyncConnector(
    supabase: ref.watch(supabaseClientProvider),
    powersyncUrl: config.powersyncUrl,
  );
  return PowerSyncSyncService(db, connector);
});

/// Live sync status for the UI indicator (FR-SYNC-08).
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final service = await ref.watch(syncServiceProvider.future);
  if (service == null) {
    yield const SyncStatus.offline();
    return;
  }
  yield* service.watchStatus();
});
