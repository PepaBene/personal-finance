import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';

/// Reactive list of the signed-in user's active transactions (FR-SYNC-02:
/// refreshes on local *and* sync-applied writes since it streams from Drift,
/// which shares the PowerSync store).
final transactionsProvider =
    StreamProvider.autoDispose<List<TransactionEntity>>((ref) async* {
  final service = await ref.watch(transactionServiceProvider.future);
  yield* service.watchAll();
});

/// Intents for the transactions screen. Phase 0 ships create + soft-delete of a
/// single-currency header (no line items yet — those land in Phase 1).
final transactionsControllerProvider = Provider.autoDispose(
  (ref) => TransactionsController(ref),
);

class TransactionsController {
  TransactionsController(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> addExpense({
    required Decimal amount,
    String? note,
  }) async {
    final auth = _ref.read(authServiceProvider).current.session;
    if (auth == null) {
      throw StateError('Cannot create a transaction while signed out.');
    }
    final currency = _ref.read(appConfigProvider).baseCurrencyCode;
    final now = DateTime.now().toUtc();
    final money = Money(amount, currency);

    final tx = TransactionEntity(
      id: _uuid.v4(),
      userId: auth.userId,
      type: TxType.expense,
      date: now,
      // Phase 0 has no Accounts entity yet; a single implicit account is used
      // until FR-ACC lands in Phase 1.
      accountId: 'default',
      total: money,
      base: money, // no FX in Phase 0 (docs/04 §3)
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    final service = await _ref.read(transactionServiceProvider.future);
    await service.upsert(tx);
  }

  Future<void> delete(String id) async {
    final service = await _ref.read(transactionServiceProvider.future);
    await service.softDelete(id);
  }
}
