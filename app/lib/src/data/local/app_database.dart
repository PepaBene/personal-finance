import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'tables/transactions_table.dart';

part 'app_database.g.dart';

/// The encrypted local Drift database — the single working source of truth on
/// each device (docs/13 golden rule 1). Opened over an encrypted executor
/// (SQLCipher on native, OPFS+WebCrypto on web) supplied at the composition
/// root; this class is storage-agnostic so it stays testable with an in-memory
/// executor.
@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Phase 0 schema. Bump on every schema change; add a stepwise migration.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Accelerate sync scans and common queries (docs/04 §7).
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions (date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions (account_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tx_user_updated '
            'ON transactions (user_id, updated_at)',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
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
