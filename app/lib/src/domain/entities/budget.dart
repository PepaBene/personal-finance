import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';
import '../money.dart';

part 'budget.freezed.dart';

/// Periodic (monthly) budget for one category (docs/04 §4.2, FR-BUD-01). The
/// limit [amount] is held in [currencyCode] — normally the user's base currency
/// so it compares directly with base-currency actuals. [startMonth] is the first
/// month (UTC, day 1) the budget applies from; an inactive budget is ignored.
@freezed
abstract class BudgetEntity with _$BudgetEntity {
  const factory BudgetEntity({
    required String id,
    required String userId,
    required String categoryId,
    required Money amount,
    @Default(BudgetPeriod.monthly) BudgetPeriod period,
    required DateTime startMonth,
    @Default(true) bool isActive,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _BudgetEntity;

  const BudgetEntity._();

  /// Whether this budget applies to [month] (a UTC first-of-month date): active
  /// and starting on or before that month.
  bool appliesTo(DateTime month) =>
      isActive && !startMonth.isAfter(DateTime.utc(month.year, month.month));
}
