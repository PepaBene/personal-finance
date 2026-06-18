import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/entities/line_item.dart';
import 'package:ledgerly_app/src/domain/money.dart';
import 'package:ledgerly_app/src/domain/rules/reconciliation.dart';

void main() {
  Money czk(String v) => Money.parse(v, 'CZK');

  LineItemEntity line(String amount, String category) => LineItemEntity(
        id: 'l-$category',
        userId: 'u',
        transactionId: 't',
        description: category,
        quantity: Decimal.one,
        lineAmount: czk(amount),
        categoryId: category,
        updatedAt: DateTime.utc(2026),
      );

  test('balances a multi-category split that sums to the total', () {
    // docs/04 §9 example: 49.80 + 89.90 + 149.40 + 34.90 = 324.00
    final r = reconcile(czk('324.00'), [
      line('49.80', 'groceries'),
      line('89.90', 'household'),
      line('149.40', 'alcohol'),
      line('34.90', 'groceries'),
    ]);
    expect(r.isBalanced, isTrue);
    expect(r.difference.amount, Decimal.zero);
  });

  test('flags an unbalanced split and reports the difference', () {
    final r = reconcile(czk('100.00'), [line('60.00', 'a')]);
    expect(r.isBalanced, isFalse);
    expect(r.difference.amount, Decimal.parse('40.00')); // under-allocated
  });

  test('absorbs sub-cent rounding within tolerance', () {
    final r = reconcile(czk('10.00'), [line('9.996', 'a')]);
    expect(r.isBalanced, isTrue);
  });

  test('throws when a line uses a different currency', () {
    final mixed = LineItemEntity(
      id: 'l',
      userId: 'u',
      transactionId: 't',
      description: 'x',
      quantity: Decimal.one,
      lineAmount: Money.parse('1.00', 'EUR'),
      categoryId: 'a',
      updatedAt: DateTime.utc(2026),
    );
    expect(
      () => reconcile(czk('1.00'), [mixed]),
      throwsA(isA<CurrencyMismatchError>()),
    );
  });
}
