import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Per-category monthly budget (docs/04 §4.2, FR-BUD-01). `amount` is a TEXT
/// decimal in `currencyCode` (normally the base currency). `startMonth` is the
/// first month (UTC) the budget applies from. FK columns are plain text;
/// PowerSync does not enforce FKs (relationships reconciled in the domain).
class Budgets extends Table with SyncColumns {
  TextColumn get categoryId => text()();
  TextColumn get period => text().map(budgetPeriodConverter)();
  TextColumn get amount => text().map(const DecimalConverter())();
  TextColumn get currencyCode => text()();
  DateTimeColumn get startMonth => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
