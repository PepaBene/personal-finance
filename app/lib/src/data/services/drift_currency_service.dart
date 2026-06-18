import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../application/auth_service.dart';
import '../../application/currency_service.dart';
import '../../domain/entities/currency.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [CurrencyService] (FR-CUR). Conversion uses the most recent
/// manual rate on or before the transaction date (docs/04 §3.3); rounding to
/// the base currency's decimal digits is banker's rounding via [Decimal].
class DriftCurrencyService implements CurrencyService {
  DriftCurrencyService(this._db, this._auth, this._defaultBaseCurrency);

  final db.AppDatabase _db;
  final AuthService _auth;
  final String _defaultBaseCurrency;

  static const _baseCurrencyKey = 'base_currency';
  static const _fxNamespace = '1b671a64-40d5-491e-99b0-da01ff1f3341';

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  /// Settings ids embed the user so the key is unique in the multi-tenant cloud.
  String _settingId(String key) => '$_userId::$key';

  @override
  Stream<List<CurrencyEntity>> watchCurrencies() {
    return _db.watchCurrencies().map(
      (rows) => rows
          .map(
            (r) => CurrencyEntity(
              code: r.id,
              symbol: r.symbol,
              name: r.name,
              decimalDigits: r.decimalDigits,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<String> baseCurrencyCode() async {
    final row =
        await (_db.select(_db.settings)
              ..where((s) => s.id.equals(_settingId(_baseCurrencyKey))))
            .getSingleOrNull();
    return row?.value ?? _defaultBaseCurrency;
  }

  @override
  Future<void> setBaseCurrencyCode(String code) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          db.SettingsCompanion.insert(
            id: _settingId(_baseCurrencyKey),
            userId: _userId,
            updatedAt: DateTime.now().toUtc(),
            value: code,
          ),
        );
  }

  @override
  Future<ConversionResult> toBase(Money amount, DateTime onDate) async {
    final base = await baseCurrencyCode();
    if (amount.currencyCode == base) {
      return ConversionResult.converted(amount);
    }
    final rateRow = await _db.rateOnOrBefore(
      _userId,
      amount.currencyCode,
      base,
      onDate.toUtc(),
    );
    if (rateRow == null) return const ConversionResult.rateMissing();

    final digits = await _baseDigits(base);
    // Banker's rounding at the conversion boundary (ADR-005) via Money.
    final rounded = Money(amount.amount * rateRow.rate, base).roundedTo(digits);
    return ConversionResult.converted(
      Money(rounded, base),
      rate: rateRow.rate.toString(),
    );
  }

  @override
  Future<void> upsertRate({
    required String fromCode,
    required String toCode,
    required Decimal rate,
    required DateTime date,
  }) async {
    final day = DateTime.utc(date.year, date.month, date.day);
    // Deterministic id on (user, from, to, day) so re-entering a day's rate
    // updates in place and converges across devices (matches the unique index).
    final id = const Uuid().v5(
      _fxNamespace,
      '$_userId:fx:$fromCode:$toCode:${day.toIso8601String()}',
    );
    await _db
        .into(_db.exchangeRates)
        .insertOnConflictUpdate(
          db.ExchangeRatesCompanion.insert(
            id: id,
            userId: _userId,
            updatedAt: DateTime.now().toUtc(),
            fromCode: fromCode,
            toCode: toCode,
            rate: rate,
            date: day,
            source: RateSource.manual,
          ),
        );
  }

  Future<int> _baseDigits(String code) async {
    final row = await (_db.select(
      _db.currencies,
    )..where((c) => c.id.equals(code))).getSingleOrNull();
    return row?.decimalDigits ?? 2;
  }
}
