import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

/// Native (iOS/Android/Windows/macOS/Linux) encrypted executor using SQLCipher
/// (docs/13 §5.1). The key is the Argon2id-derived DB key.
QueryExecutor openPlatformExecutor({
  required String dbName,
  required Uint8List key,
}) {
  return LazyDatabase(() async {
    // Ensure Drift uses the SQLCipher build of sqlite3, not the system one.
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideForAll(openCipherOnAndroid);

    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, '$dbName.db'));

    return NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        // SQLCipher expects a raw-key blob literal: x'<hex>'.
        final hexKey = _hex(key);
        raw.execute("PRAGMA key = \"x'$hexKey'\";");
        raw.execute('PRAGMA foreign_keys = ON;');
        raw.execute('PRAGMA journal_mode = WAL;');
        // Fail fast if the key is wrong (forces SQLCipher to verify the header).
        raw.execute('SELECT count(*) FROM sqlite_master;');
      },
    );
  });
}

String _hex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
