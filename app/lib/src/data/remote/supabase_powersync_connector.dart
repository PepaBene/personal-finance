import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges PowerSync's upload queue to Supabase Postgres and supplies the sync
/// credentials from the active Supabase session (docs/13 §5.4).
///
/// - [fetchCredentials] hands PowerSync the user's JWT so the sync service
///   streams only that user's rows (enforced again by RLS).
/// - [uploadData] drains the local CRUD queue and applies it to Postgres,
///   subject to RLS. Tombstones (`deleted = true`) propagate as updates, never
///   hard deletes, so removals converge across devices (docs/04 §6).
class SupabasePowerSyncConnector extends PowerSyncBackendConnector {
  SupabasePowerSyncConnector({
    required this.supabase,
    required this.powersyncUrl,
  });

  final SupabaseClient supabase;
  final String powersyncUrl;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = supabase.auth.currentSession;
    if (session == null) return null;
    return PowerSyncCredentials(
      endpoint: powersyncUrl,
      token: session.accessToken,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (final op in transaction.crud) {
        final table = supabase.from(op.table);
        switch (op.op) {
          case UpdateType.put:
            final data = {'id': op.id, ...?op.opData};
            await table.upsert(data);
          case UpdateType.patch:
            await table.update(op.opData!).eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on PostgrestException catch (e) {
      // Non-retryable data errors (e.g. RLS violation) must not block the queue
      // forever; fatal ones are acknowledged, transient ones rethrow to retry.
      if (e.code != null && _isFatal(e.code!)) {
        await transaction.complete();
      } else {
        rethrow;
      }
    }
  }

  bool _isFatal(String code) {
    // 23xxx = integrity violations, 42xxx = syntax/permission — not retryable.
    return code.startsWith('22') ||
        code.startsWith('23') ||
        code.startsWith('42');
  }
}
