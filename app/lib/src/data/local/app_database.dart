import 'package:decimal/decimal.dart'; // referenced by generated companions
import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart'; // converters referenced by generated companions
import 'tables/accounts_table.dart';
import 'tables/attachments_table.dart';
import 'tables/budgets_table.dart';
import 'tables/categories_table.dart';
import 'tables/categorization_rules_table.dart';
import 'tables/currencies_table.dart';
import 'tables/exchange_rates_table.dart';
import 'tables/line_items_table.dart';
import 'tables/merchants_table.dart';
import 'tables/recurring_templates_table.dart';
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
    CategorizationRules,
    Attachments,
    Budgets,
    RecurringTemplates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Schema moves in lockstep with PowerSync's schema and the Postgres
  /// migration (docs/04 §8). v3 adds the Phase 2 scan tables; v4 adds the
  /// Phase 3 budgets + recurring-template tables.
  @override
  int get schemaVersion => 4;

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

  /// Undo a soft-delete: un-tombstone the header and its line items (for the
  /// delete → Undo affordance). Mirrors [softDeleteTransaction].
  Future<void> restoreTransaction(String id, DateTime now) {
    return transaction(() async {
      await (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deleted: const Value(false),
          status: const Value(TxStatus.active),
          updatedAt: Value(now),
        ),
      );
      await (update(lineItems)..where((l) => l.transactionId.equals(id))).write(
        LineItemsCompanion(deleted: const Value(false), updatedAt: Value(now)),
      );
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

  /// Lowercased category name → id, for resolving keyword-dictionary hits to the
  /// user's actual categories (docs/05 §6). Last write wins on duplicate names.
  Future<Map<String, String>> categoryIdsByName(String userId) async {
    final rows = await (select(categories)
          ..where((c) => c.userId.equals(userId) & c.deleted.equals(false)))
        .get();
    return {for (final c in rows) c.name.toLowerCase(): c.id};
  }

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

  // --- Scan: categorization rules + attachments -------------------------

  /// Enabled rules for [userId], highest priority first (docs/04 §4.1).
  Stream<List<CategorizationRuleRow>> watchCategorizationRules(String userId) {
    return (select(categorizationRules)
          ..where((r) => r.userId.equals(userId) & r.deleted.equals(false))
          ..orderBy([(r) => OrderingTerm.desc(r.priority)]))
        .watch();
  }

  Future<void> upsertCategorizationRule(CategorizationRulesCompanion rule) =>
      into(categorizationRules).insertOnConflictUpdate(rule);

  Future<void> softDeleteCategorizationRule(String id, DateTime now) {
    return (update(categorizationRules)..where((r) => r.id.equals(id))).write(
      CategorizationRulesCompanion(
        deleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Merchant → learned default category (FR-CAT-06), for categorization memory.
  Future<Map<String, String>> merchantDefaultCategories(String userId) async {
    final rows = await (select(merchants)
          ..where(
            (m) =>
                m.userId.equals(userId) &
                m.deleted.equals(false) &
                m.defaultCategoryId.isNotNull(),
          ))
        .get();
    return {
      for (final m in rows) m.name.toLowerCase(): m.defaultCategoryId!,
    };
  }

  /// Attachments for a transaction (docs/04 §2.6), newest first.
  Stream<List<AttachmentRow>> watchAttachments(String transactionId) {
    return (select(attachments)
          ..where(
            (a) =>
                a.transactionId.equals(transactionId) & a.deleted.equals(false),
          )
          ..orderBy([(a) => OrderingTerm.desc(a.importedAt)]))
        .watch();
  }

  Future<void> upsertAttachment(AttachmentsCompanion attachment) =>
      into(attachments).insertOnConflictUpdate(attachment);

  Future<void> softDeleteAttachment(String id, DateTime now) {
    return (update(attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  }

  // --- Merchants ---------------------------------------------------------

  /// Active merchants for [userId], by name (for top-merchant analysis and the
  /// merchant picker).
  Stream<List<Merchant>> watchMerchants(String userId) {
    return (select(merchants)
          ..where((m) => m.userId.equals(userId) & m.deleted.equals(false))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .watch();
  }

  /// Merchant id → display name, for resolving aggregates to readable labels.
  Future<Map<String, String>> merchantNames(String userId) async {
    final rows = await (select(merchants)
          ..where((m) => m.userId.equals(userId) & m.deleted.equals(false)))
        .get();
    return {for (final m in rows) m.id: m.name};
  }

  // --- Budgets (docs/04 §4.2, FR-BUD) -----------------------------------

  /// Active (non-tombstoned) budgets for [userId].
  Stream<List<Budget>> watchBudgets(String userId) {
    return (select(budgets)
          ..where((b) => b.userId.equals(userId) & b.deleted.equals(false)))
        .watch();
  }

  Future<List<Budget>> getBudgets(String userId) {
    return (select(budgets)
          ..where((b) => b.userId.equals(userId) & b.deleted.equals(false)))
        .get();
  }

  Future<void> upsertBudget(BudgetsCompanion budget) =>
      into(budgets).insertOnConflictUpdate(budget);

  Future<void> softDeleteBudget(String id, DateTime now) {
    return (update(budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  }

  // --- Recurring templates (docs/04 §4.3, FR-CAP-07) --------------------

  /// Active (non-tombstoned) recurring templates for [userId], next-due first.
  Stream<List<RecurringTemplate>> watchRecurringTemplates(String userId) {
    return (select(recurringTemplates)
          ..where((r) => r.userId.equals(userId) & r.deleted.equals(false))
          ..orderBy([(r) => OrderingTerm.asc(r.nextDate)]))
        .watch();
  }

  Future<List<RecurringTemplate>> getRecurringTemplates(String userId) {
    return (select(recurringTemplates)
          ..where((r) => r.userId.equals(userId) & r.deleted.equals(false)))
        .get();
  }

  Future<void> upsertRecurringTemplate(RecurringTemplatesCompanion tpl) =>
      into(recurringTemplates).insertOnConflictUpdate(tpl);

  Future<void> softDeleteRecurringTemplate(String id, DateTime now) {
    return (update(recurringTemplates)..where((r) => r.id.equals(id))).write(
      RecurringTemplatesCompanion(
        deleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }
}
