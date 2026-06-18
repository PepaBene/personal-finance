import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/transaction.dart';

/// Reactive list of the signed-in user's active transactions (FR-SYNC-02:
/// refreshes on local *and* sync-applied writes since it streams from Drift,
/// which shares the PowerSync store).
final transactionsProvider =
    StreamProvider.autoDispose<List<TransactionEntity>>((ref) async* {
      final service = await ref.watch(transactionServiceProvider.future);
      yield* service.watchAll();
    });

/// Intents for the transactions list (creation/edit happen in the editor screen).
final transactionsControllerProvider = Provider.autoDispose(
  (ref) => TransactionsController(ref),
);

class TransactionsController {
  TransactionsController(this._ref);

  final Ref _ref;

  Future<void> delete(String id) async {
    final service = await _ref.read(transactionServiceProvider.future);
    await service.softDelete(id);
  }
}
