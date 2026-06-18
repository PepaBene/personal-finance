import '../domain/entities/transaction.dart';

/// Port for transaction CRUD (docs/03 §5). Implemented in `data/` by a Drift
/// adapter; consumed by ViewModels via Riverpod. The local DB is the working
/// source of truth — sync runs underneath (docs/13 golden rule 1).
abstract interface class TransactionService {
  /// Reactive stream of the signed-in user's active transactions, newest first.
  Stream<List<TransactionEntity>> watchAll();

  /// Insert or update a transaction header (stamps `updatedAt`, bumps version).
  Future<TransactionEntity> upsert(TransactionEntity tx);

  /// Soft-delete: sets the `deleted` tombstone so the deletion propagates via
  /// sync (FR-CAP-08, FR-SYNC-03). Never hard-deletes a synced row on device.
  Future<void> softDelete(String id);
}
