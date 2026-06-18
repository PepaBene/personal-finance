import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Hierarchical category (docs/04 §2.3). `parentId` null = root; one level of
/// nesting minimum (FR-CAT-03).
@DataClassName('Category')
class Categories extends Table with SyncColumns {
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get kind => text().map(categoryKindConverter)();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  TextColumn get colorHex => text().withDefault(const Constant('#4E79A7'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
