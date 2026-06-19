import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/entities/transaction.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/money.dart';
import 'package:ledgerly_app/src/domain/rules/recurring_detector.dart';

void main() {
  TransactionEntity tx(
    String id,
    String merchant,
    String amount,
    DateTime date, {
    TxType type = TxType.expense,
  }) {
    return TransactionEntity(
      id: id,
      userId: 'u',
      type: type,
      date: date,
      accountId: 'a',
      merchantId: merchant,
      total: Money(Decimal.parse(amount), 'EUR'),
      base: Money(Decimal.parse(amount), 'EUR'),
      createdAt: date,
      updatedAt: date,
    );
  }

  const detector = RecurringDetector();

  test('detects a monthly subscription with stable amount', () {
    final txs = [
      tx('1', 'netflix', '9.99', DateTime.utc(2026, 1, 3)),
      tx('2', 'netflix', '9.99', DateTime.utc(2026, 2, 2)),
      tx('3', 'netflix', '9.99', DateTime.utc(2026, 3, 4)),
      tx('4', 'netflix', '9.99', DateTime.utc(2026, 4, 3)),
    ];
    final series = detector.detect(txs);
    expect(series, hasLength(1));
    expect(series.single.merchantId, 'netflix');
    expect(series.single.frequency, RecurringFrequency.monthly);
    expect(series.single.typicalAmount, Decimal.parse('9.99'));
    expect(series.single.occurrences, 4);
  });

  test('ignores too-few occurrences', () {
    final txs = [
      tx('1', 'gym', '30.00', DateTime.utc(2026, 1, 1)),
      tx('2', 'gym', '30.00', DateTime.utc(2026, 2, 1)),
    ];
    expect(detector.detect(txs), isEmpty);
  });

  test('ignores merchants with volatile amounts', () {
    final txs = [
      tx('1', 'store', '10.00', DateTime.utc(2026, 1, 1)),
      tx('2', 'store', '95.00', DateTime.utc(2026, 2, 1)),
      tx('3', 'store', '40.00', DateTime.utc(2026, 3, 1)),
    ];
    expect(detector.detect(txs), isEmpty);
  });

  test('ignores irregular cadence', () {
    final txs = [
      tx('1', 'shop', '12.00', DateTime.utc(2026, 1, 1)),
      tx('2', 'shop', '12.00', DateTime.utc(2026, 1, 3)),
      tx('3', 'shop', '12.00', DateTime.utc(2026, 5, 20)),
    ];
    expect(detector.detect(txs), isEmpty);
  });

  test('detects a weekly cadence', () {
    final txs = [
      tx('1', 'coffee', '4.50', DateTime.utc(2026, 1, 1)),
      tx('2', 'coffee', '4.50', DateTime.utc(2026, 1, 8)),
      tx('3', 'coffee', '4.50', DateTime.utc(2026, 1, 15)),
      tx('4', 'coffee', '4.50', DateTime.utc(2026, 1, 22)),
    ];
    final series = detector.detect(txs);
    expect(series.single.frequency, RecurringFrequency.weekly);
  });

  test('excludes income transactions', () {
    final txs = [
      tx('1', 'employer', '2000.00', DateTime.utc(2026, 1, 1),
          type: TxType.income),
      tx('2', 'employer', '2000.00', DateTime.utc(2026, 2, 1),
          type: TxType.income),
      tx('3', 'employer', '2000.00', DateTime.utc(2026, 3, 1),
          type: TxType.income),
    ];
    expect(detector.detect(txs), isEmpty);
  });
}
