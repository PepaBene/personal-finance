import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:rational/rational.dart';

import '../../application/analytics_service.dart';
import '../../application/auth_service.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [AnalyticsService]. All aggregation runs over the local DB and
/// is reactive (recomputes when the underlying tables change). Money is TEXT
/// decimal so sums are folded with [Decimal]/[Rational], never SQL SUM.
///
/// Per-line base attribution (docs/04 §3.3): a line's share of the base amount
/// is `lineAmount * baseAmount / totalAmount`, so multi-currency splits are
/// counted correctly. Same-currency transactions have ratio 1.
class DriftAnalyticsService implements AnalyticsService {
  DriftAnalyticsService(this._db, this._auth, this._defaultBaseCurrency);

  final db.AppDatabase _db;
  final AuthService _auth;
  final String _defaultBaseCurrency;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  Future<String> _baseCurrency() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.id.equals('$_userId::base_currency')))
        .getSingleOrNull();
    return row?.value ?? _defaultBaseCurrency;
  }

  // --- spend by category (line-item level) ------------------------------

  @override
  Stream<List<CategoryTotal>> watchSpendByCategory(DateRange range) async* {
    final base = await _baseCurrency();
    final query = _db.select(_db.lineItems).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(_db.lineItems.transactionId),
      ),
    ])
      ..where(_db.lineItems.deleted.equals(false) &
          _db.transactions.deleted.equals(false) &
          _db.transactions.status.equalsValue(TxStatus.active) &
          _db.transactions.type.equalsValue(TxType.expense) &
          _inRange(_db.transactions.date, range));

    yield* query.watch().map((rows) {
      final acc = <String, Rational>{};
      for (final row in rows) {
        final line = row.readTable(_db.lineItems);
        final tx = row.readTable(_db.transactions);
        if (tx.totalAmount == Decimal.zero) continue;
        // Decimal / Decimal yields an exact Rational (no premature rounding).
        final share = (line.lineAmount * tx.baseAmount) / tx.totalAmount;
        acc[line.categoryId] = (acc[line.categoryId] ?? Rational.zero) + share;
      }
      final totals = acc.entries
          .map((e) => CategoryTotal(
                categoryId: e.key,
                total: Money(e.value.toDecimal(scaleOnInfinitePrecision: 2), base),
              ))
          .toList()
        ..sort((a, b) => b.total.amount.compareTo(a.total.amount));
      return totals;
    });
  }

  // --- income / expense by period ---------------------------------------

  @override
  Stream<List<PeriodPoint>> watchByPeriod(Grain grain, DateRange range) async* {
    final base = await _baseCurrency();
    yield* _headerQuery(range).watch().map((rows) {
      final inflow = <DateTime, Decimal>{};
      final outflow = <DateTime, Decimal>{};
      for (final r in rows) {
        final bucket = periodStart(r.date.toUtc(), grain);
        if (r.type == TxType.income) {
          inflow[bucket] = (inflow[bucket] ?? Decimal.zero) + r.baseAmount;
        } else if (r.type == TxType.expense) {
          outflow[bucket] = (outflow[bucket] ?? Decimal.zero) + r.baseAmount;
        }
      }
      final buckets = {...inflow.keys, ...outflow.keys}.toList()..sort();
      return buckets
          .map((b) => PeriodPoint(
                periodStart: b,
                inflow: Money(inflow[b] ?? Decimal.zero, base),
                outflow: Money(outflow[b] ?? Decimal.zero, base),
              ))
          .toList();
    });
  }

  // --- summary -----------------------------------------------------------

  @override
  Stream<DashboardSummary> watchSummary(DateRange range) async* {
    final base = await _baseCurrency();
    yield* _headerQuery(range).watch().map((rows) {
      var income = Decimal.zero;
      var expense = Decimal.zero;
      for (final r in rows) {
        if (r.type == TxType.income) {
          income += r.baseAmount;
        } else if (r.type == TxType.expense) {
          expense += r.baseAmount;
        }
      }
      return DashboardSummary(
        income: Money(income, base),
        expense: Money(expense, base),
      );
    });
  }

  // --- drill-down --------------------------------------------------------

  @override
  Future<List<TransactionEntity>> transactionsInCategory(
    String categoryId,
    DateRange range,
  ) async {
    final ids = await (_db.selectOnly(_db.lineItems, distinct: true)
          ..addColumns([_db.lineItems.transactionId])
          ..where(_db.lineItems.categoryId.equals(categoryId) &
              _db.lineItems.deleted.equals(false)))
        .map((r) => r.read(_db.lineItems.transactionId)!)
        .get();
    if (ids.isEmpty) return const [];

    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.id.isIn(ids) &
              t.deleted.equals(false) &
              _inRange(t.date, range))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  // --- helpers -----------------------------------------------------------

  Selectable<db.Transaction> _headerQuery(DateRange range) {
    return _db.select(_db.transactions)
      ..where((t) =>
          t.deleted.equals(false) &
          t.status.equalsValue(TxStatus.active) &
          _inRange(t.date, range));
  }

  Expression<bool> _inRange(Expression<DateTime> col, DateRange range) {
    return col.isBiggerOrEqualValue(range.start) &
        col.isSmallerThanValue(range.endExclusive);
  }

  TransactionEntity _toEntity(db.Transaction r) => TransactionEntity(
        id: r.id,
        userId: r.userId,
        type: r.type,
        date: r.date,
        accountId: r.accountId,
        merchantId: r.merchantId,
        counterAccountId: r.counterAccountId,
        total: Money(r.totalAmount, r.currencyCode),
        base: Money(r.baseAmount, r.currencyCode),
        note: r.note,
        source: r.source,
        status: r.status,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );
}

/// Start of the period bucket containing [d] (UTC), Monday-based weeks.
DateTime periodStart(DateTime d, Grain grain) {
  final day = DateTime.utc(d.year, d.month, d.day);
  return switch (grain) {
    Grain.day => day,
    Grain.week => day.subtract(Duration(days: (day.weekday - DateTime.monday) % 7)),
    Grain.month => DateTime.utc(d.year, d.month),
    Grain.year => DateTime.utc(d.year),
  };
}
