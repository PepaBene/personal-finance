import 'package:powersync/powersync.dart' as ps;

import '../../application/sync_service.dart';
import 'supabase_powersync_connector.dart';

/// [SyncService] over PowerSync (docs/13 §5.4). Keeping the engine behind this
/// port means it is swappable per ADR-010.
///
/// Integration note (Phase 0 seam): the [ps.PowerSyncDatabase] owns the synced
/// SQLite file; wiring Drift to read/write that same database (via the
/// powersync Drift adapter) is the remaining task so the UI's reactive Drift
/// streams and PowerSync share one store. The encrypted native executor
/// (SQLCipher) is the alternative at-rest path documented in docs/03 §10.
class PowerSyncSyncService implements SyncService {
  PowerSyncSyncService(this._db, this._connector);

  final ps.PowerSyncDatabase _db;
  final SupabasePowerSyncConnector _connector;

  @override
  Future<void> connect() => _db.connect(connector: _connector);

  @override
  Future<void> disconnect() => _db.disconnect();

  @override
  Future<void> trigger() async {
    // PowerSync syncs continuously while connected; a manual trigger simply
    // ensures the connection is live (FR-SYNC-09).
    if (!_db.connected) {
      await _db.connect(connector: _connector);
    }
  }

  @override
  Future<void> refreshCredentials() async {
    // Re-fetch the (rotated) Supabase token into PowerSync without waiting for a
    // request to fail with the stale one (FR-SYNC-07).
    await _connector.prefetchCredentials();
  }

  @override
  Stream<SyncStatus> watchStatus() => _db.statusStream.map(_map);

  SyncStatus _map(ps.SyncStatus s) {
    final SyncConnectivity connectivity;
    if (!s.connected) {
      connectivity = SyncConnectivity.offline;
    } else if (s.downloading || s.uploading) {
      connectivity = SyncConnectivity.syncing;
    } else if (s.anyError != null) {
      connectivity = SyncConnectivity.error;
    } else {
      connectivity = SyncConnectivity.connected;
    }
    return SyncStatus(
      connectivity: connectivity,
      lastSyncedAt: s.lastSyncedAt,
      message: s.anyError?.toString(),
    );
  }
}
