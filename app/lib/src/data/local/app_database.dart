import 'package:decimal/decimal.dart'; // referenced by generated companions
import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart'; // converters referenced by generated companions
import 'tables/accounts_table.dart';
import 'tables/categories_table.dart';
import 'tables/currencies_table.dart';
import 'tables/exchange_rates_table.dart';
import 'tables/line_items_table.dart';
import 'tables/merchants_table.dart';
import 'tables/settings_table.dart';
import 'tables/tags_table.dart';
import 'tables/transactions_table.dart';

part 'app_database.g.dart';

/// The local Drift database — the single working source of truth on each device
/// (docs/13 golden rule 1). It runs **on top of the PowerSync-managed SQLite
/// store** (via `SqliteAsyncDriftConnection`), so the synced tables and indexes
/// are created and owned by PowerSync, not Drift.
///
/// Consequently the Drift [migration] is a no-op for PowerSync-owned tables:
/// Drift only *mirrors* them as queryable, reactive tables. Tests drive the
/// class with an in-memory executor and call `createMigrator().createAll()`.
@DriftDatabase(
  tables: [
    Transactions,
    LineItems,
    Categories,
    Accounts,
    Merchants,
    Tags,
    LineItemTags,
    Currencies,
    ExchangeRates,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Phase 1 schema. PowerSync's schema and the Postgres migration move in
  /// lockstep (docs/04 §8).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Synced tables are owned by PowerSync; Drift must not (re)create them.
        onCreate: (m) async {},
        onUpgrade: (m, from, to) async {},
      );

  // --- Transactions + line items ----------------------------------------

  /// Active (non-tombstoned) transactions for [userId], newest first.
  Stream<List<Transaction>> watchActive(String userId) {
    return (select(transactions)
          ..where((t) => t.userId.equals(userId) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Stream<List<LineItem>> watchLineItems(String transactionId) {
    return (select(lineItems)
          ..where(
            (l) =>
                l.transactionId.equals(transactionId) & l.deleted.equals(false),
          )
          ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
        .watch();
  }

  Future<List<LineItem>> getLineItems(String transactionId) {
    return (select(lineItems)
          ..where(
            (l) =>
                l.transactionId.equals(transactionId) & l.deleted.equals(false),
          ))
        .get();
  }

  /// Atomically upsert a transaction header together with its line items.
  /// [removedLineItemIds] are tombstoned so deletions converge (FR-SYNC-03).
  /// Children are keyed to the parent (docs/04 §6).
  Future<void> upsertTransactionWithLines({
    required TransactionsCompanion header,
    required List<LineItemsCompanion> lines,
    List<String> removedLineItemIds = const [],
    required DateTime now,
  }) {
    return transaction(() async {
      await into(transactions).insertOnConflictUpdate(header);
      for (final line in lines) {
        await into(lineItems).insertOnConflictUpdate(line);
      }
      for (final id in removedLineItemIds) {
        await (update(lineItems)..where((l) => l.id.equals(id))).write(
          LineItemsCompanion(deleted: const Value(true), updatedAt: Value(now)),
        );
      }
    });
  }

  /// Soft-delete a transaction and tombstone its line items (cascade-as-
  /// tombstones for sync — docs/04 §7).
  Future<void> softDeleteTransaction(String id, DateTime now) {
    return transaction(() async {
      await (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deleted: const Value(true),
          status: const Value(TxStatus.deleted),
          updatedAt: Value(now),
        ),
      );
      await (update(lineItems)..where((l) => l.transactionId.equals(id))).write(
        LineItemsCompanion(deleted: const Value(true), updatedAt: Value(now)),
      );
    });
  }

  // --- Reference / lookup data ------------------------------------------

  Stream<List<Category>> watchCategories(String userId) {
    return (select(categories)
          ..where((c) => c.userId.equals(userId) & c.deleted.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  Stream<List<Account>> watchAccounts(String userId) {
    return (select(accounts)
          ..where((a) => a.userId.equals(userId) & a.deleted.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  Stream<List<Currency>> watchCurrencies() =>
      (select(currencies)..orderBy([(c) => OrderingTerm.asc(c.id)])).watch();

  Future<int> countCategories(String userId) async {
    final count = countAll();
    final row = await (selectOnly(categories)
          ..addColumns([count])
          ..where(categories.userId.equals(userId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Most recent rate for (from→to) on or before [onOrBefore] (docs/04 §3.3).
  Future<ExchangeRate?> rateOnOrBefore(
    String userId,
    String fromCode,
    String toCode,
    DateTime onOrBefore,
  ) {
    return (select(exchangeRates)
          ..where(
            (r) =>
                r.userId.equals(userId) &
                r.fromCode.equals(fromCode) &
                r.toCode.equals(toCode) &
                r.deleted.equals(false) &
                r.date.isSmallerOrEqualValue(onOrBefore),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.date)])
          ..limit(1))
        .getSingleOrNull();
  }
}
