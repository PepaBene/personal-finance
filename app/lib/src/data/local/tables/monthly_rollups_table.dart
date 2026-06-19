import 'package:drift/drift.dart';

import '../converters.dart';

/// Pre-aggregated monthly spend per category (docs/11 §11). A **local-only**,
/// derived cache (like `currencies` it is not synced) that gives instant
/// historical dashboards on large datasets (NFR-01/02). Rebuilt from the line
/// items by [RollupService]; `id` is deterministic on (user, month, category).
@DataClassName('MonthlyRollup')
class MonthlyRollups extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get periodMonth => dateTime()();
  TextColumn get categoryId => text()();
  TextColumn get baseAmount => text().map(const DecimalConverter())();

  @override
  Set<Column> get primaryKey => {id};
}
