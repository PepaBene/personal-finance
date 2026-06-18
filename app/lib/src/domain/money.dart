import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Money is never a `double` (docs/13 golden rule 3, ADR-005). [Decimal]
/// everywhere; banker's rounding (round-half-to-even) only at persistence /
/// display boundaries.
@immutable
class Money {
  const Money(this.amount, this.currencyCode);

  Money.zero(this.currencyCode) : amount = Decimal.zero;

  /// Parse the canonical TEXT-decimal storage form (docs/04 §3.4).
  factory Money.parse(String value, String currencyCode) =>
      Money(Decimal.parse(value), currencyCode);

  final Decimal amount;

  /// ISO 4217 code, e.g. CZK / EUR / USD.
  final String currencyCode;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount + other.amount, currencyCode);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amount - other.amount, currencyCode);
  }

  bool get isNegative => amount < Decimal.zero;
  bool get isZero => amount == Decimal.zero;

  /// Banker's rounding applied ONLY at persistence/display boundaries.
  Decimal roundedTo(int digits) =>
      amount.round(scale: digits); // decimal package rounds half-to-even

  /// Canonical full-precision string for storage (no float, no locale).
  String toStorageString() => amount.toString();

  void _assertSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw CurrencyMismatchError(currencyCode, other.currencyCode);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.amount == amount &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(amount, currencyCode);

  @override
  String toString() => '$amount $currencyCode';
}

/// Thrown when arithmetic mixes currencies without an exchange rate.
class CurrencyMismatchError extends Error {
  CurrencyMismatchError(this.expected, this.actual);
  final String expected;
  final String actual;

  @override
  String toString() =>
      'CurrencyMismatchError: cannot combine $expected with $actual';
}
