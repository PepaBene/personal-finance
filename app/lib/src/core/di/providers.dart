import 'dart:typed_data';

import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
// `show` avoids name clashes: powersync also exports `SyncStatus` and
// supabase_flutter (gotrue) also exports `AuthState`, which collide with our
// application-layer types of the same name.
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

import '../../application/account_service.dart';
import '../../application/analytics_service.dart';
import '../../application/app_lock_service.dart';
import '../../application/attachment_service.dart';
import '../../application/attachment_store.dart';
import '../../application/auth_service.dart';
import '../../application/categorization_rule_service.dart';
import '../../application/category_service.dart';
import '../../application/currency_service.dart';
import '../../application/import_export_service.dart';
import '../../application/sync_service.dart';
import '../../application/transaction_service.dart';
import '../../data/attachments/default_attachment_store.dart';
import '../../data/attachments/memory_blob_cache.dart';
import '../../data/attachments/null_remote_blob_store.dart';
import '../../data/crypto/aes_gcm_attachment_cipher.dart';
import '../../data/crypto/argon2_app_lock_service.dart';
import '../../data/services/drift_attachment_service.dart';
import '../../data/services/drift_categorization_rule_service.dart';
import '../../data/local/app_database.dart';
import '../../data/local/ledgerly_powersync.dart';
import '../../data/remote/powersync_sync_service.dart';
import '../../data/remote/supabase_powersync_connector.dart';
import '../../data/seed/database_seeder.dart';
import '../../data/services/drift_account_service.dart';
import '../../data/services/drift_analytics_service.dart';
import '../../data/services/drift_category_service.dart';
import '../../data/services/drift_currency_service.dart';
import '../../data/services/drift_import_export_service.dart';
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

// --- Local store: one PowerSync DB, with Drift layered on top -----------

/// The single PowerSync-managed SQLite database — the device's working store.
/// Opened (encrypted on native) once an unlock key is available; both the Drift
/// layer and the sync service share this exact instance so reads, local writes,
/// and synced changes all flow through one database (docs/13 §5.4).
///
/// Throws while locked; the router guard keeps DB-backed screens unreachable
/// until unlocked.
final powerSyncDatabaseProvider = FutureProvider<PowerSyncDatabase>((
  ref,
) async {
  final key = ref.watch(databaseKeyProvider);
  if (key == null) {
    throw StateError('Database is locked: no encryption key available.');
  }
  final db = await openLedgerlyPowerSyncDatabase(encryptionKey: key);
  ref.onDispose(db.close);
  return db;
});

/// Drift running on top of the PowerSync database (shared connection). Drift's
/// reactive `Stream` queries update on any change to the store — including rows
/// applied by the sync engine (FR-SYNC-02).
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final powersync = await ref.watch(powerSyncDatabaseProvider.future);
  final db = AppDatabase(SqliteAsyncDriftConnection(powersync));
  ref.onDispose(db.close);
  return db;
});

final transactionServiceProvider = FutureProvider<TransactionService>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftTransactionService(db, ref.watch(authServiceProvider));
});

final categoryServiceProvider = FutureProvider<CategoryService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftCategoryService(db, ref.watch(authServiceProvider));
});

final accountServiceProvider = FutureProvider<AccountService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftAccountService(db, ref.watch(authServiceProvider));
});

final currencyServiceProvider = FutureProvider<CurrencyService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftCurrencyService(
    db,
    ref.watch(authServiceProvider),
    ref.watch(appConfigProvider).baseCurrencyCode,
  );
});

final categorizationRuleServiceProvider =
    FutureProvider<CategorizationRuleService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftCategorizationRuleService(db, ref.watch(authServiceProvider));
});

final attachmentServiceProvider = FutureProvider<AttachmentService>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftAttachmentService(db, ref.watch(authServiceProvider));
});

// --- Attachment blob encryption + storage (docs/09 §2/§3) ---------------

/// Content-encryption cipher for attachments, derived from the unlock key via
/// HKDF (docs/09 §3). Throws while locked, like the other key-gated providers.
final attachmentCipherProvider = FutureProvider<AttachmentCipher>((ref) async {
  final key = ref.watch(databaseKeyProvider);
  if (key == null) {
    throw StateError('Locked: no key available for attachment encryption.');
  }
  return AesGcmAttachmentCipher.fromMasterKey(key);
});

/// Local encrypted-blob cache. In-memory for now (works on every platform); a
/// persistent native/OPFS cache lands later.
final blobCacheProvider = Provider<BlobCache>((ref) => MemoryBlobCache());

/// Remote blob store. Offline by default (cloud Storage upload is a follow-up).
final remoteBlobStoreProvider = Provider<RemoteBlobStore>(
  (ref) => const NullRemoteBlobStore(),
);

final attachmentStoreProvider = FutureProvider<AttachmentStore>((ref) async {
  final cipher = await ref.watch(attachmentCipherProvider.future);
  final auth = ref.watch(authServiceProvider);
  const uuid = Uuid();
  return DefaultAttachmentStore(
    cipher: cipher,
    cache: ref.watch(blobCacheProvider),
    remote: ref.watch(remoteBlobStoreProvider),
    userId: () =>
        auth.current.session?.userId ??
        (throw StateError('Not signed in; cannot store attachments.')),
    newId: uuid.v4,
    now: () => DateTime.now().toUtc(),
  );
});

final analyticsServiceProvider = FutureProvider<AnalyticsService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftAnalyticsService(
    db,
    ref.watch(authServiceProvider),
    ref.watch(appConfigProvider).baseCurrencyCode,
  );
});

final importExportServiceProvider = FutureProvider<ImportExportService>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final tx = await ref.watch(transactionServiceProvider.future);
  final currency = await ref.watch(currencyServiceProvider.future);
  return DriftImportExportService(
    db,
    ref.watch(authServiceProvider),
    tx,
    currency,
  );
});

/// Seeds reference + per-user default data once the store is open and the user
/// is known (FR-CAT-01, FR-CUR-01). Awaited by the unlock flow.
final bootstrapProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authServiceProvider).current;
  if (!auth.isSignedIn) return;
  final db = await ref.watch(appDatabaseProvider.future);
  await DatabaseSeeder(db).seed(
    userId: auth.session!.userId,
    baseCurrency: ref.watch(appConfigProvider).baseCurrencyCode,
  );
});

// --- Sync (PowerSync) ---------------------------------------------------

/// Builds the sync service over the *shared* PowerSync database when the cloud
/// is configured; returns `null` otherwise so the app stays fully usable
/// offline against the same local store (FR-SYNC-01).
final syncServiceProvider = FutureProvider<SyncService?>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (!config.hasCloud) return null;

  final db = await ref.watch(powerSyncDatabaseProvider.future);
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
