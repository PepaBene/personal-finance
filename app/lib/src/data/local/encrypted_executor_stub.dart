import 'dart:typed_data';

import 'package:drift/drift.dart';

/// Fallback used only when neither dart:io nor dart:js_interop is available
/// (e.g. some analyzer contexts). Real platforms resolve to the native or web
/// implementation via conditional import.
QueryExecutor openPlatformExecutor({
  required String dbName,
  required Uint8List key,
}) {
  throw UnsupportedError(
    'No encrypted executor for this platform: $dbName',
  );
}
