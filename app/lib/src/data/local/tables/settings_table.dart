import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// User-scoped key/value settings (docs/04 §4.4) — base currency, locale, theme,
/// etc. Synced so a user's preferences converge across devices. `id` holds the
/// setting key.
class Settings extends Table with SyncColumns {
  TextColumn get value => text()();
}
