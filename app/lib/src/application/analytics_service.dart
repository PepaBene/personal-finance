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

/// Base-currency expense total for one merchant, ranked (FR-ANL-08, docs/11 §6).
class MerchantTotal {
  const MerchantTotal({
    required this.merchantId,
    required this.name,
    required this.total,
  });
  final String merchantId;
  final String name;
  final Money total;
}

/// One category's spend in two comparable periods (MoM/YoY — FR-ANL-09,
/// docs/11 §5.3). [current] and [previous] are base-currency expense totals.
class CategoryComparison {
  const CategoryComparison({
    required this.categoryId,
    required this.current,
    required this.previous,
  });
  final String categoryId;
  final Money current;
  final Money previous;

  /// (current − previous) ÷ previous; null when there is no prior spend (so the
  /// UI shows "new" rather than a meaningless ∞%).
  double? get change {
    if (previous.amount == Decimal.zero) return null;
    return ((current.amount - previous.amount) / previous.amount).toDouble();
  }
}

/// Base-currency expense for a single day (calendar heatmap — FR-ANL-07,
/// docs/11 §7). [day] is the UTC date (midnight).
class DailySpend {
  const DailySpend({required this.day, required this.amount});
  final DateTime day;
  final Money amount;
}

/// One step of a cash-flow waterfall (FR-ANL-07, docs/11 §4.2). [delta] is the
/// signed base-currency contribution; [isTotal] marks an absolute bar (the
/// ending net) drawn from zero rather than floating on the running total. [key]
/// is a category id for expense steps, or a reserved token ('income', 'other',
/// 'net').
class WaterfallStep {
  const WaterfallStep({
    required this.key,
    required this.delta,
    this.isTotal = false,
  });
  final String key;
  final Money delta;
  final bool isTotal;
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

  /// Transactions for [merchantId] within [range], newest first (drill-down from
  /// the top-merchants view, FR-ANL-10, docs/11 §6).
  Future<List<TransactionEntity>> transactionsForMerchant(
    String merchantId,
    DateRange range,
  );

  /// Actual-vs-budget for each active budget over [monthRange] (FR-BUD-02,
  /// FR-ANL-06), reactive to both spend and budget changes. Sorted by
  /// utilization (most-stretched first).
  Stream<List<BudgetStatus>> watchBudgetStatus(DateRange monthRange);

  /// Top merchants by base-currency expense over [range], ranked, capped at
  /// [limit] (FR-ANL-08).
  Stream<List<MerchantTotal>> watchTopMerchants(
    DateRange range, {
    int limit = 10,
  });

  /// Base-currency expense per day over [range] (FR-ANL-07, calendar heatmap).
  /// Only days with spend are returned.
  Stream<List<DailySpend>> watchDailySpend(DateRange range);

  /// Per-category spend in [current] vs [previous] comparable periods, ordered
  /// by the size of the move (FR-ANL-09, MoM/YoY).
  Future<List<CategoryComparison>> categoryComparison(
    DateRange current,
    DateRange previous,
  );

  /// Cash-flow waterfall over [range]: income (+), the [topCategories] largest
  /// expense categories (−), an "other" bucket (−), and the ending net total
  /// (FR-ANL-07, docs/11 §4.2).
  Future<List<WaterfallStep>> cashflowWaterfall(
    DateRange range, {
    int topCategories = 5,
  });
}
