import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Learned per-merchant extraction template (docs/05 §10, FR-SCAN-10). Keyed by
/// the normalized merchant name ([merchantKey]); `categoryHints` is a JSON
/// description→categoryId map. Synced like every other user table.
class MerchantTemplates extends Table with SyncColumns {
  TextColumn get merchantKey => text()();
  TextColumn get currencyCode => text().nullable()();
  TextColumn get docType => text().map(docTypeConverter).nullable()();
  TextColumn get categoryHints => text()
      .map(const StringMapConverter())
      .withDefault(const Constant('{}'))();
  IntColumn get sampleCount => integer().withDefault(const Constant(0))();
}
