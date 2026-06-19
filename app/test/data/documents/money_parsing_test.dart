import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/data/documents/parsing/money_parsing.dart';

void main() {
  Decimal? p(String s) => MoneyParsing.parseAmount(s);
  Decimal d(String s) => Decimal.parse(s);

  test('comma-decimal (CS) and dot-decimal (EN)', () {
    expect(p('49,80'), d('49.80'));
    expect(p('234.10'), d('234.10'));
    expect(p('0,99'), d('0.99'));
  });

  test('space and non-breaking-space thousands separators', () {
    expect(p('1 234,56'), d('1234.56'));
    expect(p('1 234,56'), d('1234.56'));
  });

  test('mixed thousands + decimal separators', () {
    expect(p('1,234.56'), d('1234.56'));
    expect(p('1.234,56'), d('1234.56'));
  });

  test('single separator with a 3-digit tail is treated as thousands', () {
    expect(p('1,500'), d('1500'));
    expect(p('1.234'), d('1234'));
  });

  test('strips currency markers and handles signs', () {
    expect(p('Kč 49,80'), d('49.80'));
    expect(p(r'$1,299.00'), d('1299.00'));
    expect(p('-50,00'), d('-50.00'));
  });

  test('returns null when there is no number', () {
    expect(p('TOTAL'), isNull);
    expect(p(''), isNull);
  });

  test('priceToken matches 2-decimal amounts only', () {
    expect(MoneyParsing.priceToken.hasMatch('49,80'), isTrue);
    expect(MoneyParsing.priceToken.hasMatch('15%'), isFalse);
    expect(MoneyParsing.priceToken.hasMatch('2026'), isFalse);
  });
}
