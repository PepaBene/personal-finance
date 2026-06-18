import '../domain/entities/currency.dart';
import '../domain/money.dart';

/// Multi-currency conversion + reference data (FR-CUR). Implemented in `data/`.
abstract interface class CurrencyService {
  /// Available currencies (seeded reference data).
  Stream<List<CurrencyEntity>> watchCurrencies();

  /// The user's base/home currency code (FR-CUR-01); falls back to the
  /// configured default until set.
  Future<String> baseCurrencyCode();

  Future<void> setBaseCurrencyCode(String code);

  /// Convert [amount] to the base currency using the rate effective on [onDate]
  /// (most recent on or before that date — docs/04 §3.3). Returns the converted
  /// [Money] and the [rate] used; `rate` is null when amount is already base.
  Future<ConversionResult> toBase(Money amount, DateTime onDate);
}

class ConversionResult {
  const ConversionResult.converted(this.base, {this.rate}) : needsRate = false;

  /// No rate exists for the date and the caller must prompt for one
  /// (offline-safe manual entry — docs/04 §3.3 step 3).
  const ConversionResult.rateMissing()
      : base = null,
        rate = null,
        needsRate = true;

  /// Converted amount in the base currency (null when [needsRate]).
  final Money? base;

  /// orig→base rate applied (null when amount was already base, or missing).
  final String? rate;

  final bool needsRate;
}
