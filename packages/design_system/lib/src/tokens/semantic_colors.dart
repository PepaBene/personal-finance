import 'package:flutter/material.dart';

/// Fixed-meaning finance palette (docs/12 §3.2 P4). Held as a [ThemeExtension]
/// so it stays stable regardless of dynamic color. Color is never the *only*
/// signal (P11) — widgets pair these with icons/labels.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.onIncome,
    required this.onExpense,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color onIncome;
  final Color onExpense;

  static const SemanticColors light = SemanticColors(
    income: Color(0xFF1B7F4B),
    expense: Color(0xFFB3261E),
    transfer: Color(0xFF3B6EA5),
    success: Color(0xFF1B7F4B),
    warning: Color(0xFFB26A00),
    danger: Color(0xFFB3261E),
    info: Color(0xFF3B6EA5),
    onIncome: Color(0xFFFFFFFF),
    onExpense: Color(0xFFFFFFFF),
  );

  static const SemanticColors dark = SemanticColors(
    income: Color(0xFF6FD79C),
    expense: Color(0xFFF2B8B5),
    transfer: Color(0xFF9FC2EC),
    success: Color(0xFF6FD79C),
    warning: Color(0xFFE6B873),
    danger: Color(0xFFF2B8B5),
    info: Color(0xFF9FC2EC),
    onIncome: Color(0xFF00210F),
    onExpense: Color(0xFF601410),
  );

  @override
  SemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? onIncome,
    Color? onExpense,
  }) {
    return SemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      onIncome: onIncome ?? this.onIncome,
      onExpense: onExpense ?? this.onExpense,
    );
  }

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      onIncome: Color.lerp(onIncome, other.onIncome, t)!,
      onExpense: Color.lerp(onExpense, other.onExpense, t)!,
    );
  }
}
