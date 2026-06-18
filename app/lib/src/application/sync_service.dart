/// Sync port (docs/03 §5, FR-SYNC). Keeps the engine (PowerSync) swappable —
/// the rest of the app depends only on this interface (docs/13 §5.4).

enum SyncConnectivity { connected, syncing, offline, error }

class SyncStatus {
  const SyncStatus({
    required this.connectivity,
    this.lastSyncedAt,
    this.pendingUploads = 0,
    this.message,
  });

  const SyncStatus.offline() : this(connectivity: SyncConnectivity.offline);

  final SyncConnectivity connectivity;
  final DateTime? lastSyncedAt;
  final int pendingUploads;
  final String? message;
}

abstract interface class SyncService {
  /// Connect the local DB to the cloud for the authenticated session and begin
  /// streaming the user's rows down / queued writes up.
  Future<void> connect();

  /// Disconnect on sign-out; local data remains usable offline.
  Future<void> disconnect();

  /// Live status for the UI indicator (FR-SYNC-08).
  Stream<SyncStatus> watchStatus();

  /// Opportunistic manual sync / force-refresh (FR-SYNC-09).
  Future<void> trigger();

  /// Proactively refresh the backend credentials after the auth token rotates,
  /// so sync keeps using a valid token without waiting for a failed request
  /// (FR-SYNC-07).
  Future<void> refreshCredentials();
}
