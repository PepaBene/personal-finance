import 'dart:typed_data';

import 'package:drift/drift.dart';

// Conditional import keeps native plugins out of the web bundle and vice-versa
// (docs/13 §3.1 web caveat).
import 'encrypted_executor_stub.dart'
    if (dart.library.io) 'encrypted_executor_native.dart'
    if (dart.library.js_interop) 'encrypted_executor_web.dart';

/// Opens the local database with at-rest encryption, given the [key] derived
/// from the user's passphrase (Argon2id — see AppLockService / docs/13 §6).
///
/// - Native: SQLCipher via `PRAGMA key`, with `foreign_keys` and WAL.
/// - Web: Drift WASM over OPFS; app-level encryption guards sensitive payloads
///   (SQLCipher-in-WASM asymmetry documented in docs/09 §2).
QueryExecutor openEncryptedExecutor({
  required String dbName,
  required Uint8List key,
}) =>
    openPlatformExecutor(dbName: dbName, key: key);
