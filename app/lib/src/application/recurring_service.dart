import '../domain/entities/recurring_template.dart';

/// Recurring transaction templates (FR-CAP-07). Implemented in `data/`.
abstract interface class RecurringService {
  /// Active templates for the signed-in user, next-due first.
  Stream<List<RecurringTemplateEntity>> watchAll();

  /// Create or update a template; stamps sync metadata and bumps the version.
  Future<RecurringTemplateEntity> upsert(RecurringTemplateEntity template);

  /// Soft-delete (tombstone) a template so the deletion converges.
  Future<void> delete(String id);

  /// Generate every occurrence due on or before [asOf] across all active
  /// templates, advancing each template's `nextDate`/`lastRunDate`. Idempotent:
  /// re-running with the same [asOf] generates nothing further. Returns the
  /// number of transactions created.
  Future<int> generateDue(DateTime asOf);
}
