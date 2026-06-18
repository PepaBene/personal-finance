import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Transaction header table (docs/04 §2.1). Money columns are TEXT decimals via
/// [DecimalConverter]; dates are ISO-8601 TEXT (build.yaml
/// `store_date_time_values_as_text`). FK columns are plain text (PowerSync does
/// not enforce FKs; relationships are reconciled in the domain).
class Transactions extends Table with SyncColumns {
  TextColumn get type => text().map(txTypeConverter)();
  DateTimeColumn get date => dateTime()();
  TextColumn get accountId => text()();
  TextColumn get merchantId => text().nullable()();
  TextColumn get counterAccountId => text().nullable()();
  TextColumn get currencyCode => text()();
  TextColumn get totalAmount => text().map(const DecimalConverter())();
  TextColumn get baseAmount => text().map(const DecimalConverter())();
  TextColumn get exchangeRate => text().map(const DecimalConverter()).nullable()();
  TextColumn get taxAmount => text().map(const DecimalConverter()).nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().map(txSourceConverter)();
  TextColumn get status => text().map(txStatusConverter)();
  DateTimeColumn get createdAt => dateTime()();
}
