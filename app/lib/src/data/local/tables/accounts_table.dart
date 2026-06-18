import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Account (docs/04 §2.5). Current balance = openingBalance + signed sum of
/// transactions/transfers, computed via SQL aggregation (FR-ACC-02).
class Accounts extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get kind => text().map(accountKindConverter)();
  TextColumn get currencyCode => text()();
  TextColumn get openingBalance => text().map(const DecimalConverter())();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}
