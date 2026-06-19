import 'package:decimal/decimal.dart';

import '../entities/transaction.dart';
import '../enums.dart';

/// A detected recurring charge: repeated, similarly-sized expenses to the same
/// merchant at a regular cadence (FR-ANL-08, docs/07 §5). This is a heuristic
/// suggestion the user can turn into a [RecurringTemplate]; it does not persist
/// anything itself.
class RecurringSeries {
  const RecurringSeries({
    required this.merchantId,
    required this.frequency,
    required this.typicalAmount,
    required this.currencyCode,
    required this.occurrences,
    required this.lastDate,
    required this.nextExpected,
  });

  final String merchantId;
  final RecurringFrequency frequency;

  /// Median base/original amount of the occurrences (original currency).
  final Decimal typicalAmount;
  final String currencyCode;
  final int occurrences;
  final DateTime lastDate;
  final DateTime nextExpected;
}

/// Detects recurring expense series from a transaction history. Pure and
/// deterministic so it is fully unit-testable; the UI surfaces results as
/// "create a recurring template?" suggestions.
class RecurringDetector {
  const RecurringDetector({
    this.minOccurrences = 3,
    this.amountTolerance = 0.15,
  });

  /// At least this many occurrences before a series is reported.
  final int minOccurrences;

  /// Allowed fractional spread of amounts around the median (e.g. 0.15 = ±15%).
  final double amountTolerance;

  /// Cadence buckets (in days) with a tolerance window each.
  static const _cadences = <(RecurringFrequency, int, int)>[
    (RecurringFrequency.weekly, 7, 2),
    (RecurringFrequency.monthly, 30, 5),
    (RecurringFrequency.yearly, 365, 20),
  ];

  List<RecurringSeries> detect(List<TransactionEntity> transactions) {
    // Group active expenses by merchant.
    final byMerchant = <String, List<TransactionEntity>>{};
    for (final t in transactions) {
      if (t.type != TxType.expense || !t.isActive || t.merchantId == null) {
        continue;
      }
      byMerchant.putIfAbsent(t.merchantId!, () => []).add(t);
    }

    final out = <RecurringSeries>[];
    for (final entry in byMerchant.entries) {
      final txs = entry.value
        ..sort((a, b) => a.date.compareTo(b.date));
      if (txs.length < minOccurrences) continue;

      // Amounts must be consistent (subscriptions don't jump around).
      final amounts = txs.map((t) => t.total.amount).toList();
      final median = _median(amounts);
      if (median == Decimal.zero) continue;
      final withinTolerance = amounts.every((a) {
        final diff = (a - median).abs().toDouble();
        return diff <= median.toDouble() * amountTolerance;
      });
      if (!withinTolerance) continue;

      // Intervals between consecutive dates must cluster around one cadence.
      final gaps = <int>[];
      for (var i = 1; i < txs.length; i++) {
        gaps.add(txs[i].date.difference(txs[i - 1].date).inDays);
      }
      final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
      final cadence = _matchCadence(avgGap);
      if (cadence == null) continue;

      final last = txs.last.date;
      out.add(
        RecurringSeries(
          merchantId: entry.key,
          frequency: cadence.$1,
          typicalAmount: median,
          currencyCode: txs.last.total.currencyCode,
          occurrences: txs.length,
          lastDate: last,
          nextExpected: last.add(Duration(days: cadence.$2)),
        ),
      );
    }
    out.sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return out;
  }

  (RecurringFrequency, int)? _matchCadence(double avgGapDays) {
    for (final (freq, period, tol) in _cadences) {
      if ((avgGapDays - period).abs() <= tol) return (freq, period);
    }
    return null;
  }

  static Decimal _median(List<Decimal> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    // Decimal / Decimal yields a Rational; resolve to a 2-dp Decimal.
    final sum = sorted[mid - 1] + sorted[mid];
    return (sum / Decimal.fromInt(2)).toDecimal(scaleOnInfinitePrecision: 2);
  }
}
