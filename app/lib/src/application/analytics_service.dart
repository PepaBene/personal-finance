import 'package:decimal/decimal.dart';

import '../domain/entities/budget.dart';
import '../domain/entities/transaction.dart';
import '../domain/money.dart';

/// Period granularity for time-series analytics (FR-ANL-03).
enum Grain { day, week, month, year }

/// A half-open date range [start, endExclusive) in UTC.
class DateRange {
  const DateRange(this.start, this.endExclusive);
  final DateTime start;
  final DateTime endExclusive;
}

/// Active analytics filter (FR-ANL-05). Phase 1 ships range + grain; category /
/// account narrowing is via drill-down.
class AnalyticsFilter {
  const AnalyticsFilter({required this.range, required this.grain});
  final DateRange range;
  final Grain grain;

  AnalyticsFilter copyWith({DateRange? range, Grain? grain}) =>
      AnalyticsFilter(range: range ?? this.range, grain: grain ?? this.grain);
}

/// Base-currency total for one category (FR-ANL-02).
class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.total});
  final String categoryId;
  final Money total;
}

/// Inflow/outflow for one period bucket (FR-ANL-03/04), in base currency.
class PeriodPoint {
  const PeriodPoint({
    required this.periodStart,
    required this.inflow,
    required this.outflow,
  });
  final DateTime periodStart;
  final Money inflow;
  final Money outflow;

  Money get net => inflow - outflow;
}

/// How a budget is tracking against actual spend (FR-BUD-02, docs/11 §5.5).
enum BudgetAlertLevel { ok, nearing, over }

/// Actual-vs-budget for one budgeted category over a month (FR-ANL-06). [actual]
/// is base-currency expense for the category; [budget] carries the limit.
class BudgetStatus {
  const BudgetStatus({required this.budget, required this.actual});

  /// Spend at/over this fraction of the limit (but under it) is "nearing".
  static const nearingThreshold = 0.8;

  final BudgetEntity budget;
  final Money actual;

  Money get limit => budget.amount;
  Money get remaining =>
      Money(limit.amount - actual.amount, limit.currencyCode);

  /// actual ÷ limit (0 when the limit is zero), as a 0..n fraction.
  double get utilization {
    if (limit.amount == Decimal.zero) return 0;
    return (actual.amount / limit.amount).toDouble();
  }

  BudgetAlertLevel get level {
    final u = utilization;
    if (u >= 1.0) return BudgetAlertLevel.over;
    if (u >= nearingThreshold) return BudgetAlertLevel.nearing;
    return BudgetAlertLevel.ok;
  }
}

/// Dashboard headline figures for the selected range (FR-ANL-01), base currency.
class DashboardSummary {
  const DashboardSummary({required this.income, required this.expense});
  final Money income;
  final Money expense;

  Money get net => income - expense;
}

/// Aggregations for the dashboard/analytics views (docs/13 §10). Every metric is
/// implemented once here so all screens reconcile. All results are in the base
/// currency, computed from the local DB (fully offline).
abstract interface class AnalyticsService {
  /// Expense totals per category over [range] (line-item level, so splits are
  /// attributed correctly), largest first.
  Stream<List<CategoryTotal>> watchSpendByCategory(DateRange range);

  /// Inflow/outflow per [grain] bucket across [range] (drives over-time and
  /// income-vs-expense charts).
  Stream<List<PeriodPoint>> watchByPeriod(Grain grain, DateRange range);

  /// Headline income/expense/net + top categories for [range].
  Stream<DashboardSummary> watchSummary(DateRange range);

  /// Transactions touching [categoryId] within [range] (drill-down, FR-ANL-10).
  Future<List<TransactionEntity>> transactionsInCategory(
    String categoryId,
    DateRange range,
  );

  /// Actual-vs-budget for each active budget over [monthRange] (FR-BUD-02,
  /// FR-ANL-06), reactive to both spend and budget changes. Sorted by
  /// utilization (most-stretched first).
  Stream<List<BudgetStatus>> watchBudgetStatus(DateRange monthRange);
}
