import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency.freezed.dart';

/// Currency reference data (docs/04 §3.1).
@freezed
class CurrencyEntity with _$CurrencyEntity {
  const factory CurrencyEntity({
    required String code, // ISO 4217
    required String symbol,
    required String name,
    @Default(2) int decimalDigits,
  }) = _CurrencyEntity;
}
