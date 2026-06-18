import 'dart:typed_data';

import 'package:powersync/powersync.dart';

/// Fallback for analyzer contexts where neither dart:io nor dart:js_interop is
/// available. Real platforms resolve to the native or web implementation.
Future<PowerSyncDatabase> openLedgerlyPowerSyncDatabaseImpl({
  required Uint8List encryptionKey,
}) {
  throw UnsupportedError('No PowerSync open implementation for this platform.');
}
