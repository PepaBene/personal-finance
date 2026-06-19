import '../domain/money.dart';

/// Pre-aggregated spend for one (month, category) bucket, base currency.
class MonthlyCategoryRollup {
  const MonthlyCategoryRollup({
    required this.month,
    required this.categoryId,
    required this.amount,
  });
  final DateTime month;
  final String categoryId;
  final Money amount;
}

/// Total expense for one month, base currency (a fast dashboard/trend series).
class MonthlyTotal {
  const MonthlyTotal({required this.month, required this.amount});
  final DateTime month;
  final Money amount;
}

/// Maintains the local monthly rollup cache (docs/11 §11, NFR-01/02). Rebuilt
/// from the line items so it is exact; reads are then O(months) instead of
/// scanning every transaction — the path to instant dashboards on 100k+ rows.
abstract interface class RollupService {
  /// Recompute the whole cache for the signed-in user. Idempotent. Returns the
  /// number of (month, category) rows written.
  Future<int> rebuild();

  /// Per-(month, category) spend from the cache.
  Future<List<MonthlyCategoryRollup>> categoryRollups();

  /// Total expense per month from the cache (rolls up categories).
  Future<List<MonthlyTotal>> monthlyTotals();
}
