import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Merchant / payee (docs/04 §2.4). `defaultCategoryId` is the learned
/// suggestion (FR-CAT-06); `aliases` hold OCR/name variants for matching.
class Merchants extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get defaultCategoryId => text().nullable()();
  TextColumn get aliases =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
}
