import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// Free-form tag (docs/04 §2.7) — cross-cutting labels that complement the
/// single primary category (FR-CAT-08).
class Tags extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get colorHex => text().withDefault(const Constant('#BAB0AC'))();
}

/// Many-to-many join between line items and tags. The join row carries its own
/// id + sync columns so the relationship converges independently (docs/04 §2.7).
class LineItemTags extends Table with SyncColumns {
  TextColumn get lineItemId => text()();
  TextColumn get tagId => text()();
}
