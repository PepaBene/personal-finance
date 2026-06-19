import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/analytics_service.dart';
import '../../core/di/providers.dart';
import '../dashboard/dashboard_providers.dart';

/// The period immediately before the active range, of equal length — the
/// comparison baseline for MoM/YoY (this month → last month, this year → last
/// year, etc.). FR-ANL-09.
DateRange previousRange(DateRange r) {
  final length = r.endExclusive.difference(r.start);
  return DateRange(r.start.subtract(length), r.start);
}

final topMerchantsProvider = StreamProvider.autoDispose<List<MerchantTotal>>((
  ref,
) async* {
  final service = await ref.watch(analyticsServiceProvider.future);
  final filter = ref.watch(analyticsFilterProvider);
  yield* service.watchTopMerchants(filter.range);
});

final dailySpendProvider = StreamProvider.autoDispose<List<DailySpend>>((
  ref,
) async* {
  final service = await ref.watch(analyticsServiceProvider.future);
  final filter = ref.watch(analyticsFilterProvider);
  yield* service.watchDailySpend(filter.range);
});

final categoryComparisonProvider =
    FutureProvider.autoDispose<List<CategoryComparison>>((ref) async {
  final service = await ref.watch(analyticsServiceProvider.future);
  final filter = ref.watch(analyticsFilterProvider);
  return service.categoryComparison(
    filter.range,
    previousRange(filter.range),
  );
});

final waterfallProvider =
    FutureProvider.autoDispose<List<WaterfallStep>>((ref) async {
  final service = await ref.watch(analyticsServiceProvider.future);
  final filter = ref.watch(analyticsFilterProvider);
  return service.cashflowWaterfall(filter.range);
});
