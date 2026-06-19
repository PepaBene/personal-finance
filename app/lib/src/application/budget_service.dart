import '../domain/entities/budget.dart';

/// Budget management (FR-BUD-01). Implemented in `data/`. Actual-vs-budget
/// computation lives in [AnalyticsService] so all spend numbers reconcile.
abstract interface class BudgetService {
  /// Active budgets for the signed-in user.
  Stream<List<BudgetEntity>> watchAll();

  /// Snapshot of active budgets (non-reactive).
  Future<List<BudgetEntity>> getAll();

  /// Create or update a budget; stamps sync metadata and bumps the version.
  Future<BudgetEntity> upsert(BudgetEntity budget);

  /// Soft-delete (tombstone) a budget so the deletion converges (FR-SYNC-03).
  Future<void> delete(String id);
}
