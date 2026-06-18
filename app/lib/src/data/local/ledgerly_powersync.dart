import 'dart:typed_data';

import 'package:powersync/powersync.dart';

// Platform-specific open: native applies SQLCipher (PRAGMA key); web uses the
// PowerSync web worker over OPFS (SQLCipher-in-WASM asymmetry — docs/09 §2).
import 'ledgerly_powersync_stub.dart'
    if (dart.library.io) 'ledgerly_powersync_native.dart'
    if (dart.library.js_interop) 'ledgerly_powersync_web.dart';

/// Opens (and initializes) the single PowerSync-managed SQLite database that is
/// the device's working store. Drift then runs *on top of this same database*
/// via `SqliteAsyncDriftConnection`, so PowerSync-applied changes flow into
/// Drift's reactive `Stream` queries and local Drift writes are queued for
/// upload (docs/13 §5.4 — the Phase 0 Drift⇄PowerSync seam).
///
/// [encryptionKey] is the Argon2id-derived key from the app-lock flow.
Future<PowerSyncDatabase> openLedgerlyPowerSyncDatabase({
  required Uint8List encryptionKey,
}) => openLedgerlyPowerSyncDatabaseImpl(encryptionKey: encryptionKey);
