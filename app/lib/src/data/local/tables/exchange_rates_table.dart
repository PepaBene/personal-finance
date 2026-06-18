import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Historical exchange rate (docs/04 §3.2). Unique on (fromCode, toCode, date);
/// rate is orig→to on that date. Entered manually in MVP (FR-CUR-04).
class ExchangeRates extends Table with SyncColumns {
  TextColumn get fromCode => text()();
  TextColumn get toCode => text()();
  TextColumn get rate => text().map(const DecimalConverter())();
  DateTimeColumn get date => dateTime()();
  TextColumn get source => text().map(rateSourceConverter)();
}
