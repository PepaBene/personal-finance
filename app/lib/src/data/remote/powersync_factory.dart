import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'powersync_schema.dart';

/// Opens (and initializes) the PowerSync database that holds the synced SQLite
/// store (docs/13 §5.4).
///
/// Phase 0 seam: this is the native path. Web uses a worker-based factory; that
/// branch is added when the web sync target is enabled. Wiring Drift onto this
/// same database (so reactive Drift streams and PowerSync share one file) is
/// the remaining Phase 0 integration task.
Future<PowerSyncDatabase> openPowerSyncDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final db = PowerSyncDatabase(
    schema: powersyncSchema,
    path: p.join(dir.path, 'ledgerly-powersync.db'),
  );
  await db.initialize();
  return db;
}
