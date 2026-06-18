import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'tables/transactions_table.dart';

part 'app_database.g.dart';

/// The local Drift database — the single working source of truth on each device
/// (docs/13 golden rule 1). It runs **on top of the PowerSync-managed SQLite
/// store** (via `SqliteAsyncDriftConnection`), so the synced tables and indexes
/// are created and owned by PowerSync, not Drift.
///
/// Consequently the Drift [migration] is a no-op for synced tables: Drift only
/// *mirrors* them as queryable, reactive tables. (Local-only, unsynced tables —
/// none in Phase 0 — would be created in `onCreate`.) The class stays
/// storage-agnostic so tests can drive it with an in-memory executor, calling
/// `createMigrator().createAll()` to materialize the schema themselves.
@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Phase 0 schema. Bump on every schema change; PowerSync's schema (and the
  /// Postgres migration) move in lockstep — docs/04 §8.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Synced tables are owned by PowerSync; Drift must not (re)create them.
        onCreate: (m) async {},
        onUpgrade: (m, from, to) async {},
      );

  /// Active (non-tombstoned) transactions for [userId], newest first.
  Stream<List<Transaction>> watchActive(String userId) {
    return (select(transactions)
          ..where((t) => t.userId.equals(userId) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<void> upsertTransaction(TransactionsCompanion row) =>
      into(transactions).insertOnConflictUpdate(row);

  Future<void> tombstone(String id, DateTime now) {
    return (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deleted: const Value(true),
        status: const Value(TxStatus.deleted),
        updatedAt: Value(now),
      ),
    );
  }
}
