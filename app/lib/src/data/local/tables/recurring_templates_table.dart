import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Recurring transaction template (docs/04 §4.3, FR-CAP-07). Generates draft
/// transactions on/after `nextDate`. Money columns are TEXT decimals; FK columns
/// are plain text (PowerSync does not enforce FKs). `lastRunDate` records the
/// date of the most recently generated occurrence so generation is idempotent.
class RecurringTemplates extends Table with SyncColumns {
  TextColumn get type => text().map(txTypeConverter)();
  TextColumn get name => text()();
  TextColumn get accountId => text()();
  TextColumn get merchantId => text().nullable()();
  TextColumn get categoryId => text()();
  TextColumn get currencyCode => text()();
  TextColumn get amount => text().map(const DecimalConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get frequency => text().map(recurringFrequencyConverter)();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get lastRunDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
