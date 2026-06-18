import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Line item (docs/04 §2.2) — where categorization & multi-category splitting
/// happen. A transaction whose line items span different categories *is* a
/// split bill (FR-CAT-04).
class LineItems extends Table with SyncColumns {
  TextColumn get transactionId => text()();
  TextColumn get description => text()();
  TextColumn get quantity => text().map(const DecimalConverter())();
  TextColumn get unitPrice => text().map(const DecimalConverter()).nullable()();
  TextColumn get lineAmount => text().map(const DecimalConverter())();
  TextColumn get categoryId => text()();
  TextColumn get taxRate => text().map(const DecimalConverter()).nullable()();
  RealColumn get ocrConfidence => real().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
