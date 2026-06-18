import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/analytics_service.dart';
import '../../core/di/providers.dart';

/// Date-range presets for the analytics filter (FR-ANL-05).
enum RangePreset { thisMonth, last30Days, thisYear, last12Months }

extension RangePresetX on RangePreset {
  String get label => switch (this) {
        RangePreset.thisMonth => 'This month',
        RangePreset.last30Days => 'Last 30 days',
        RangePreset.thisYear => 'This year',
        RangePreset.last12Months => 'Last 12 months',
      };

  /// Half-open [start, endExclusive) in UTC, relative to [now].
  DateRange toRange(DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return switch (this) {
      RangePreset.thisMonth => DateRange(
          DateTime.utc(now.year, now.month),
          DateTime.utc(now.year, now.month + 1),
        ),
      RangePreset.last30Days => DateRange(
          today.subtract(const Duration(days: 30)),
          tomorrow,
        ),
      RangePreset.thisYear => DateRange(
          DateTime.utc(now.year),
          DateTime.utc(now.year + 1),
        ),
      RangePreset.last12Months => DateRange(
          DateTime.utc(now.year, now.month - 11),
          tomorrow,
        ),
    };
  }

  /// A sensible default grain for this preset.
  Grain get grain => switch (this) {
        RangePreset.thisMonth || RangePreset.last30Days => Grain.day,
        RangePreset.thisYear || RangePreset.last12Months => Grain.month,
      };
}

/// The selected preset (drives the filter below).
final rangePresetProvider = StateProvider<RangePreset>(
  (ref) => RangePreset.thisMonth,
);

/// The resolved analytics filter (range + grain).
final analyticsFilterProvider = Provider<AnalyticsFilter>((ref) {
  final preset = ref.watch(rangePresetProvider);
  return AnalyticsFilter(
    range: preset.toRange(DateTime.now()),
    grain: preset.grain,
  );
});

final summaryProvider = StreamProvider.autoDispose<DashboardSummary>((
  ref,
) async* {
  final service = await ref.watch(analyticsServiceProvider.future);
  final filter = ref.watch(analyticsFilterProvider);
  yield* service.watchSummary(filter.range);
});

final spendByCategoryProvider = StreamProvider.autoDispose<List<CategoryTotal>>(
  (ref) async* {
    final service = await ref.watch(analyticsServiceProvider.future);
    final filter = ref.watch(analyticsFilterProvider);
    yield* service.watchSpendByCategory(filter.range);
  },
);

final byPeriodProvider = StreamProvider.autoDispose<List<PeriodPoint>>((
  ref,
) async* {
  final service = await ref.watch(analyticsServiceProvider.future);
  final filter = ref.watch(analyticsFilterProvider);
  yield* service.watchByPeriod(filter.grain, filter.range);
});
