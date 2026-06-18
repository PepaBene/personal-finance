import 'dart:typed_data';

import 'package:powersync/powersync.dart';

import '../remote/powersync_schema.dart';

/// Web open path. PowerSync on web stores the database in OPFS via its web
/// worker; SQLCipher-in-WASM is not used, so the [encryptionKey] is retained
/// for the app-level AES-GCM field encryption layer (Phase 1+) rather than
/// whole-file encryption. This asymmetry is documented in docs/09 §2.
Future<PowerSyncDatabase> openLedgerlyPowerSyncDatabaseImpl({
  required Uint8List encryptionKey,
}) async {
  // On web, `path` is used as the OPFS database name.
  final db = PowerSyncDatabase(schema: powersyncSchema, path: 'ledgerly.db');
  await db.initialize();
  return db;
}
