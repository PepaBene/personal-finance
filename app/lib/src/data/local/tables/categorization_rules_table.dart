import 'package:drift/drift.dart';

import '../converters.dart';
import 'sync_columns.dart';

/// Auto-categorization rule (docs/04 §4.1, FR-CAT-05). Applied in [priority]
/// order during scan parsing and as a "re-apply rules" action; first enabled
/// match wins. Synced so rules converge across the user's devices.
@DataClassName('CategorizationRuleRow')
class CategorizationRules extends Table with SyncColumns {
  TextColumn get matchType => text().map(categoryMatchTypeConverter)();
  TextColumn get pattern => text()();
  TextColumn get categoryId => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
}
