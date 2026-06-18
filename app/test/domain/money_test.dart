import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/money.dart';

void main() {
  group('Money', () {
    Money eur(String v) => Money.parse(v, 'EUR');

    test('adds same-currency amounts without float drift', () {
      final sum = eur('0.10') + eur('0.20');
      expect(sum.amount, Decimal.parse('0.30'));
      expect(sum.currencyCode, 'EUR');
    });

    test('subtracts same-currency amounts', () {
      expect((eur('5.00') - eur('1.25')).amount, Decimal.parse('3.75'));
    });

    test('throws when currencies are mixed', () {
      expect(
        () => eur('1.00') + Money.parse('1.00', 'USD'),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });

    test("rounds half-to-even (banker's rounding) at the boundary", () {
      // 2.5 -> 2 and 3.5 -> 4 under round-half-to-even.
      expect(Money.parse('2.5', 'EUR').roundedTo(0), Decimal.parse('2'));
      expect(Money.parse('3.5', 'EUR').roundedTo(0), Decimal.parse('4'));
    });

    test('preserves full precision in storage form', () {
      expect(eur('842.00').toStorageString(), '842.00');
    });

    test('value equality', () {
      expect(eur('1.00'), eur('1.00'));
      expect(eur('1.00') == eur('2.00'), isFalse);
    });
  });
}
