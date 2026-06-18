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
}
