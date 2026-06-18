import 'package:drift/drift.dart';

import '../converters.dart';

/// Sync columns shared by every synced table (docs/04 §1.1, FR-SYNC-03).
/// Drift mixes these into each table so the metadata is uniform.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(0))();
}

/// Transaction header table (docs/04 §2.1). Phase 0 ships the header; line
/// items arrive in Phase 1. Money columns are TEXT decimals via
/// [DecimalConverter]; dates are ISO-8601 TEXT (build.yaml
/// `store_date_time_values_as_text`).
class Transactions extends Table with SyncColumns {
  TextColumn get type => text().map(txTypeConverter)();
  DateTimeColumn get date => dateTime()();
  TextColumn get accountId => text()();
  TextColumn get merchantId => text().nullable()();
  TextColumn get counterAccountId => text().nullable()();
  TextColumn get currencyCode => text()();
  TextColumn get totalAmount => text().map(const DecimalConverter())();
  TextColumn get baseAmount => text().map(const DecimalConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().map(txSourceConverter)();
  TextColumn get status => text().map(txStatusConverter)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
