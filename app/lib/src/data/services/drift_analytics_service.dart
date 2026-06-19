import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:rational/rational.dart';

import '../../application/analytics_service.dart';
import '../../application/auth_service.dart';
import '../../domain/entities/budget.dart';
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
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.id.equals('$_userId::base_currency')))
        .getSingleOrNull();
    return row?.value ?? _defaultBaseCurrency;
  }

  // --- spend by category (line-item level) ------------------------------

  @override
  Stream<List<CategoryTotal>> watchSpendByCategory(DateRange range) async* {
    final base = await _baseCurrency();
    yield* _spendByCategory(range).map((acc) {
      return acc.entries
          .map(
            (e) => CategoryTotal(
              categoryId: e.key,
              total: Money(
                e.value.toDecimal(scaleOnInfinitePrecision: 2),
                base,
              ),
            ),
          )
          .toList()
        ..sort((a, b) => b.total.amount.compareTo(a.total.amount));
    });
  }

  /// Reactive `categoryId → base-currency spend share` over [range] (expense
  /// lines only). The exact [Rational] is kept until the boundary so splits and
  /// multi-currency conversions stay precise (docs/11 §1.2). Single source of
  /// truth for both spend-by-category and budget actuals.
  Stream<Map<String, Rational>> _spendByCategory(DateRange range) {
    final query = _db.select(_db.lineItems).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(_db.lineItems.transactionId),
      ),
    ])
      ..where(
        _db.transactions.userId.equals(_userId) &
            _db.lineItems.deleted.equals(false) &
            _db.transactions.deleted.equals(false) &
            _db.transactions.status.equalsValue(TxStatus.active) &
            _db.transactions.type.equalsValue(TxType.expense) &
            _inRange(_db.transactions.date, range),
      );

    return query.watch().map((rows) {
      final acc = <String, Rational>{};
      for (final row in rows) {
        final line = row.readTable(_db.lineItems);
        final tx = row.readTable(_db.transactions);
        if (tx.totalAmount == Decimal.zero) continue;
        // Decimal / Decimal yields an exact Rational (no premature rounding).
        final share = (line.lineAmount * tx.baseAmount) / tx.totalAmount;
        acc[line.categoryId] = (acc[line.categoryId] ?? Rational.zero) + share;
      }
      return acc;
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
          .map(
            (b) => PeriodPoint(
              periodStart: b,
              inflow: Money(inflow[b] ?? Decimal.zero, base),
              outflow: Money(outflow[b] ?? Decimal.zero, base),
            ),
          )
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
          ..where(
            _db.lineItems.userId.equals(_userId) &
                _db.lineItems.categoryId.equals(categoryId) &
                _db.lineItems.deleted.equals(false),
          ))
        .map((r) => r.read(_db.lineItems.transactionId)!)
        .get();
    if (ids.isEmpty) return const [];

    final rows = await (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.id.isIn(ids) &
                t.userId.equals(_userId) &
                t.deleted.equals(false) &
                t.status.equalsValue(TxStatus.active) &
                t.type.equalsValue(TxType.expense) &
                _inRange(t.date, range),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<TransactionEntity>> transactionsForMerchant(
    String merchantId,
    DateRange range,
  ) async {
    final rows = await (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.merchantId.equals(merchantId) &
                t.userId.equals(_userId) &
                t.deleted.equals(false) &
                t.status.equalsValue(TxStatus.active) &
                t.type.equalsValue(TxType.expense) &
                _inRange(t.date, range),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  // --- budgets (actual vs budget) ---------------------------------------

  @override
  Stream<List<BudgetStatus>> watchBudgetStatus(DateRange monthRange) async* {
    final base = await _baseCurrency();
    final month = monthRange.start;
    yield* _combineLatest2(
      _spendByCategory(monthRange),
      _db.watchBudgets(_userId),
      (spend, budgetRows) {
        final statuses = <BudgetStatus>[];
        for (final row in budgetRows) {
          final budget = _toBudget(row);
          if (!budget.appliesTo(month)) continue;
          final share = spend[budget.categoryId] ?? Rational.zero;
          final actual = Money(
            share.toDecimal(scaleOnInfinitePrecision: 2),
            base,
          );
          // Treat the budget's stored amount as a base-currency magnitude so
          // actual and limit are always in the same currency (H2).
          final limit = Money(budget.amount.amount, base);
          statuses.add(
            BudgetStatus(budget: budget, actual: actual, limit: limit),
          );
        }
        statuses.sort((a, b) => b.utilization.compareTo(a.utilization));
        return statuses;
      },
    );
  }

  BudgetEntity _toBudget(db.Budget r) => BudgetEntity(
        id: r.id,
        userId: r.userId,
        categoryId: r.categoryId,
        amount: Money(r.amount, r.currencyCode),
        period: r.period,
        startMonth: r.startMonth,
        isActive: r.isActive,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );

  // --- advanced analytics (FR-ANL-07/08/09) -----------------------------

  @override
  Stream<List<MerchantTotal>> watchTopMerchants(
    DateRange range, {
    int limit = 10,
  }) async* {
    final base = await _baseCurrency();
    final names = await _db.merchantNames(_userId);
    yield* _headerQuery(range).watch().map((rows) {
      final acc = <String, Decimal>{};
      for (final r in rows) {
        if (r.type != TxType.expense || r.merchantId == null) continue;
        acc[r.merchantId!] = (acc[r.merchantId!] ?? Decimal.zero) + r.baseAmount;
      }
      final totals = acc.entries
          .map(
            (e) => MerchantTotal(
              merchantId: e.key,
              name: names[e.key] ?? e.key,
              total: Money(e.value, base),
            ),
          )
          .toList()
        ..sort((a, b) => b.total.amount.compareTo(a.total.amount));
      return totals.take(limit).toList();
    });
  }

  @override
  Stream<List<DailySpend>> watchDailySpend(DateRange range) async* {
    final base = await _baseCurrency();
    yield* _headerQuery(range).watch().map((rows) {
      final acc = <DateTime, Decimal>{};
      for (final r in rows) {
        if (r.type != TxType.expense) continue;
        final d = r.date.toUtc();
        final day = DateTime.utc(d.year, d.month, d.day);
        acc[day] = (acc[day] ?? Decimal.zero) + r.baseAmount;
      }
      final days = acc.keys.toList()..sort();
      return [
        for (final day in days)
          DailySpend(day: day, amount: Money(acc[day]!, base)),
      ];
    });
  }

  @override
  Future<List<CategoryComparison>> categoryComparison(
    DateRange current,
    DateRange previous,
  ) async {
    final base = await _baseCurrency();
    final cur = await _spendByCategory(current).first;
    final prev = await _spendByCategory(previous).first;
    final ids = {...cur.keys, ...prev.keys};
    Money money(Rational? r) =>
        Money((r ?? Rational.zero).toDecimal(scaleOnInfinitePrecision: 2), base);
    final out = [
      for (final id in ids)
        CategoryComparison(
          categoryId: id,
          current: money(cur[id]),
          previous: money(prev[id]),
        ),
    ]..sort((a, b) {
        final da = (a.current.amount - a.previous.amount).abs();
        final dbv = (b.current.amount - b.previous.amount).abs();
        return dbv.compareTo(da);
      });
    return out;
  }

  @override
  Future<List<WaterfallStep>> cashflowWaterfall(
    DateRange range, {
    int topCategories = 5,
  }) async {
    final base = await _baseCurrency();
    final summary = await watchSummary(range).first;
    final byCat = await watchSpendByCategory(range).first;

    final steps = <WaterfallStep>[
      WaterfallStep(key: 'income', delta: summary.income),
    ];
    final top = byCat.take(topCategories).toList();
    var topSum = Decimal.zero;
    for (final c in top) {
      topSum += c.total.amount;
      steps.add(
        WaterfallStep(
          key: c.categoryId,
          delta: Money(Decimal.zero - c.total.amount, base),
        ),
      );
    }
    final other = summary.expense.amount - topSum;
    if (other > Decimal.zero) {
      steps.add(
        WaterfallStep(key: 'other', delta: Money(Decimal.zero - other, base)),
      );
    }
    steps.add(
      WaterfallStep(key: 'net', delta: summary.net, isTotal: true),
    );
    return steps;
  }

  // --- helpers -----------------------------------------------------------

  Selectable<db.Transaction> _headerQuery(DateRange range) {
    return _db.select(_db.transactions)
      ..where(
        (t) =>
            t.userId.equals(_userId) &
            t.deleted.equals(false) &
            t.status.equalsValue(TxStatus.active) &
            _inRange(t.date, range),
      );
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

/// Emits [combine] of the latest value of [a] and [b] whenever either emits,
/// once both have produced a value. Dependency-free `combineLatest` for two
/// reactive Drift streams (e.g. spend + budgets), so budget status refreshes on
/// changes to either. Single-subscription; cancels both sources on cancel.
Stream<R> _combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  late StreamSubscription<A> subA;
  late StreamSubscription<B> subB;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen(
        (v) {
          latestA = v;
          hasA = true;
          emit();
        },
        onError: controller.addError,
      );
      subB = b.listen(
        (v) {
          latestB = v;
          hasB = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA.cancel();
      await subB.cancel();
    },
  );
  return controller.stream;
}

/// Start of the period bucket containing [d] (UTC), Monday-based weeks.
DateTime periodStart(DateTime d, Grain grain) {
  final day = DateTime.utc(d.year, d.month, d.day);
  return switch (grain) {
    Grain.day => day,
    Grain.week => day.subtract(
        Duration(days: (day.weekday - DateTime.monday) % 7),
      ),
    Grain.month => DateTime.utc(d.year, d.month),
    Grain.year => DateTime.utc(d.year),
  };
}
