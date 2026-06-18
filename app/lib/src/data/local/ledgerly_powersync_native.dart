import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite_async/sqlite_async.dart';

import '../remote/powersync_schema.dart';

/// Native open path with SQLCipher at-rest encryption (FR-SEC-01).
///
/// Drift no longer opens its own SQLite file; PowerSync owns the database, so
/// encryption is applied here through a [PowerSyncOpenFactory] that runs
/// `PRAGMA key` before any other access. The SQLCipher native libraries come
/// from `sqlcipher_flutter_libs` (which replaces `sqlite3_flutter_libs` so a
/// single, cipher-enabled sqlite3 is loaded).
Future<PowerSyncDatabase> openLedgerlyPowerSyncDatabaseImpl({
  required Uint8List encryptionKey,
}) async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'ledgerly.db');

  final db = PowerSyncDatabase.withFactory(
    _EncryptedOpenFactory(path: path, key: encryptionKey),
    schema: powersyncSchema,
  );
  await db.initialize();
  return db;
}

/// Applies the SQLCipher key as the first pragma on every connection in the
/// pool. PowerSync executes [pragmaStatements] immediately after opening the
/// raw database and before reading any page, which is exactly when the key must
/// be set for an encrypted database to be readable.
class _EncryptedOpenFactory extends PowerSyncOpenFactory {
  _EncryptedOpenFactory({required super.path, required this.key});

  final Uint8List key;

  @override
  List<String> pragmaStatements(SqliteOpenOptions options) {
    return [
      "PRAGMA key = \"x'${_hex(key)}'\"",
      ...super.pragmaStatements(options),
    ];
  }

  @override
  CommonDatabase open(SqliteOpenOptions options) {
    final db = super.open(options);
    // Fail fast if the key is wrong: forces SQLCipher to verify the header now
    // rather than on the first real query.
    db.select('SELECT count(*) FROM sqlite_master');
    return db;
  }
}

String _hex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
