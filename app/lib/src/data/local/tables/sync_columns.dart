import 'package:drift/drift.dart';

/// Sync columns shared by every synced table (docs/04 §1.1, FR-SYNC-03). Drift
/// mixes these into each synced table so the metadata is uniform.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
