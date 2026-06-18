import '../domain/categorization/categorizer.dart';
import '../domain/entities/categorization_rule.dart';

/// CRUD for auto-categorization rules (docs/04 §4.1, FR-CAT-05) plus assembly of
/// a ready-to-use [Categorizer] from the user's rules, merchant memory, and
/// categories. Implemented by a Drift adapter; consumed by the scan pipeline and
/// a rules settings screen.
abstract interface class CategorizationRuleService {
  /// The user's enabled rules, highest priority first.
  Stream<List<CategorizationRule>> watchRules();

  Future<void> upsert(CategorizationRule rule);

  /// Soft-delete (tombstone) so the removal converges across devices.
  Future<void> delete(String id);

  /// Build a [Categorizer] from the current rules + merchant defaults
  /// (FR-CAT-06) + the user's categories (for keyword-dictionary resolution).
  Future<Categorizer> buildCategorizer();
}
