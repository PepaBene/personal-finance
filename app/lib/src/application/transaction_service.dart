import '../domain/entities/line_item.dart';
import '../domain/entities/transaction.dart';

/// Port for transaction CRUD (docs/03 §5). Implemented in `data/` by a Drift
/// adapter; consumed by ViewModels via Riverpod. The local DB is the working
/// source of truth — sync runs underneath (docs/13 golden rule 1).
abstract interface class TransactionService {
  /// Reactive stream of the signed-in user's active transactions, newest first.
  Stream<List<TransactionEntity>> watchAll();

  /// Reactive line items for a transaction, in display order.
  Stream<List<LineItemEntity>> watchLineItems(String transactionId);

  /// Fetch a single transaction header by id (for editing), or null.
  Future<TransactionEntity?> getById(String id);

  /// Insert/update a header with no explicit line items (FR-CAP-04: treated as
  /// a single implicit line). Stamps `updatedAt`, bumps version.
  Future<TransactionEntity> upsert(TransactionEntity tx);

  /// Insert/update a header together with its line items atomically, tombstoning
  /// any [removedLineItemIds] (FR-CAP-03/05). Caller is responsible for the
  /// Σ-lines == total invariant (enforced in the domain + editor).
  Future<TransactionEntity> upsertWithLines(
    TransactionEntity header,
    List<LineItemEntity> lines, {
    List<String> removedLineItemIds,
  });

  /// Soft-delete: tombstones the header and its line items so the deletion
  /// propagates via sync (FR-CAP-08, FR-SYNC-03).
  Future<void> softDelete(String id);
}
