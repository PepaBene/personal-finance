import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web executor: Drift WASM over OPFS (docs/13 §5.1). SQLCipher-in-WASM is
/// heavier, so on web the DB file lives in OPFS and sensitive payloads are
/// additionally AES-GCM encrypted with a non-extractable WebCrypto key
/// (documented asymmetry — docs/09 §2). The [key] is retained for that
/// app-level field encryption layer (wired in Phase 1+).
QueryExecutor openPlatformExecutor({
  required String dbName,
  required Uint8List key,
}) {
  return LazyDatabase(() async {
    final db = await WasmDatabase.open(
      databaseName: dbName,
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return db.resolvedExecutor;
  });
}
