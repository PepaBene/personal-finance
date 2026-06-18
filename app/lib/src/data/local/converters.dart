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

const txTypeConverter = EnumNameConverter(TxType.values, TxType.expense);
const txSourceConverter = EnumNameConverter(TxSource.values, TxSource.manual);
const txStatusConverter = EnumNameConverter(TxStatus.values, TxStatus.active);
