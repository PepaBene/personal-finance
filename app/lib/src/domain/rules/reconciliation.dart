import 'package:decimal/decimal.dart';

import '../entities/line_item.dart';
import '../money.dart';

/// Result of reconciling a transaction total against its line items (FR-CAP-05).
class Reconciliation {
  const Reconciliation({required this.total, required this.lineSum});

  final Money total;
  final Money lineSum;

  /// total − Σ lines (positive = under-allocated, negative = over-allocated).
  Money get difference => total - lineSum;

  bool get isBalanced => difference.amount.abs() <= _tolerance;

  /// One minor unit of tolerance to absorb rounding at boundaries (docs/04 §2.1
  /// "within rounding tolerance"). Currencies with more decimals tighten this.
  static final Decimal _tolerance = Decimal.parse('0.005');
}

/// Reconcile [total] against [lines]. All amounts must share the transaction's
/// currency; mixing currencies throws via [Money] arithmetic.
Reconciliation reconcile(Money total, List<LineItemEntity> lines) {
  var sum = Money.zero(total.currencyCode);
  for (final line in lines) {
    sum += line.lineAmount;
  }
  return Reconciliation(total: total, lineSum: sum);
}
