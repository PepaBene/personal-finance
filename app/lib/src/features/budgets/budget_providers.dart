import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/analytics_service.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/budget.dart';

/// The current calendar month as a half-open UTC range [first, nextFirst).
/// Budgets are monthly (FR-BUD-01), so they always track the live month.
DateRange currentMonthRange([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateRange(
    DateTime.utc(n.year, n.month),
    DateTime.utc(n.year, n.month + 1),
  );
}

/// All active budgets for the signed-in user.
final budgetsProvider = StreamProvider.autoDispose<List<BudgetEntity>>((
  ref,
) async* {
  final service = await ref.watch(budgetServiceProvider.future);
  yield* service.watchAll();
});

/// Actual-vs-budget status for the current month (FR-ANL-06, FR-BUD-02),
/// reactive to both spend and budget edits.
final budgetStatusProvider = StreamProvider.autoDispose<List<BudgetStatus>>((
  ref,
) async* {
  final analytics = await ref.watch(analyticsServiceProvider.future);
  yield* analytics.watchBudgetStatus(currentMonthRange());
});
