import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../domain/enums.dart';

/// Stores [Decimal] money as a full-precision TEXT string (docs/04 §3.4):
/// no float, no per-currency scale bugs.
class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toString();
}

/// Generic enum <-> TEXT converter using [Enum.name].
class EnumNameConverter<T extends Enum> extends TypeConverter<T, String> {
  const EnumNameConverter(this.values, this.fallback);

  final List<T> values;
  final T fallback;

  @override
  T fromSql(String fromDb) => enumByName(values, fromDb, fallback);

  @override
  String toSql(T value) => value.name;
}

/// Stores a `List<String>` (e.g. merchant aliases) as a JSON TEXT array.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    final decoded = jsonDecode(fromDb);
    return (decoded as List).cast<String>();
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Stores a `Map<String, String>` (e.g. per-merchant description→category hints)
/// as a JSON TEXT object.
class StringMapConverter extends TypeConverter<Map<String, String>, String> {
  const StringMapConverter();

  @override
  Map<String, String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const {};
    final decoded = jsonDecode(fromDb) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);
}

const txTypeConverter = EnumNameConverter(TxType.values, TxType.expense);
const txSourceConverter = EnumNameConverter(TxSource.values, TxSource.manual);
const txStatusConverter = EnumNameConverter(TxStatus.values, TxStatus.active);
const categoryKindConverter = EnumNameConverter(
  CategoryKind.values,
  CategoryKind.expense,
);
const accountKindConverter = EnumNameConverter(
  AccountKind.values,
  AccountKind.cash,
);
const rateSourceConverter = EnumNameConverter(
  RateSource.values,
  RateSource.manual,
);
const docTypeConverter = EnumNameConverter(DocType.values, DocType.receipt);
const scanStatusConverter = EnumNameConverter(
  ScanStatus.values,
  ScanStatus.pending,
);
const categoryMatchTypeConverter = EnumNameConverter(
  CategoryMatchType.values,
  CategoryMatchType.descriptionContains,
);
const budgetPeriodConverter = EnumNameConverter(
  BudgetPeriod.values,
  BudgetPeriod.monthly,
);
const recurringFrequencyConverter = EnumNameConverter(
  RecurringFrequency.values,
  RecurringFrequency.monthly,
);
