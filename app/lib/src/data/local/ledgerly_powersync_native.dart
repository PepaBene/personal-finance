import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import '../remote/powersync_schema.dart';

/// Native open path with at-rest encryption (FR-SEC-01) via PowerSync's built-in
/// [EncryptionOptions] (SQLite3MultipleCiphers in SQLCipher-compatible mode).
///
/// This replaces the previous custom SQLCipher open factory: PowerSync 2.x owns
/// the encrypted SQLite, so we no longer add `sqlcipher_flutter_libs` ourselves
/// (which collided with the `sqlite3_flutter_libs` PowerSync pulls in). The
/// `hooks:` block in pubspec.yaml swaps the bundled sqlite3 for sqlite3mc.
Future<PowerSyncDatabase> openLedgerlyPowerSyncDatabaseImpl({
  required Uint8List encryptionKey,
}) async {
  final dir = await getApplicationSupportDirectory();
  final db = PowerSyncDatabase(
    schema: powersyncSchema,
    path: p.join(dir.path, 'ledgerly.db'),
    // The Argon2id-derived key, as a hex passphrase. sqlcipherCompatibility
    // defaults to true on native.
    encryption: EncryptionOptions(key: _hex(encryptionKey)),
  );
  await db.initialize();
  return db;
}

String _hex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
