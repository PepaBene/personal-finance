import 'package:drift/drift.dart';

/// Currency reference data (docs/04 §3.1). Local-only in PowerSync (it is shared
/// reference data, not per-user), seeded on each device. `id` holds the ISO 4217
/// code (e.g. CZK / EUR / USD).
@DataClassName('Currency')
class Currencies extends Table {
  TextColumn get id => text()();
  TextColumn get symbol => text()();
  IntColumn get decimalDigits => integer().withDefault(const Constant(2))();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}
