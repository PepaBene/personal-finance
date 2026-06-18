import 'package:drift/drift.dart';

import '../../application/auth_service.dart';
import '../../application/transaction_service.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [TransactionService]. Reads/writes the local encrypted DB only;
/// PowerSync replicates rows underneath (docs/13 §5). All UI streams originate
/// here so they refresh on any local write — including sync-applied writes.
class DriftTransactionService implements TransactionService {
  DriftTransactionService(this._db, this._auth);

  final db.AppDatabase _db;
  final AuthService _auth;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) {
      throw StateError('No authenticated user; cannot access transactions.');
    }
    return session.userId;
  }

  @override
  Stream<List<TransactionEntity>> watchAll() {
    return _db.watchActive(_userId).map(
          (rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<TransactionEntity> upsert(TransactionEntity tx) async {
    final now = DateTime.now().toUtc();
    final next = tx.copyWith(updatedAt: now, version: tx.version + 1);
    await _db.upsertTransaction(_toCompanion(next));
    return next;
  }

  @override
  Future<void> softDelete(String id) => _db.tombstone(id, DateTime.now().toUtc());

  TransactionEntity _toEntity(db.Transaction r) => TransactionEntity(
        id: r.id,
        userId: r.userId,
        type: r.type,
        date: r.date,
        accountId: r.accountId,
        merchantId: r.merchantId,
        counterAccountId: r.counterAccountId,
        total: Money(r.totalAmount, r.currencyCode),
        // Phase 0 has no FX yet: base shares the original currency (docs/04 §3).
        base: Money(r.baseAmount, r.currencyCode),
        note: r.note,
        source: r.source,
        status: r.status,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );

  db.TransactionsCompanion _toCompanion(TransactionEntity e) =>
      db.TransactionsCompanion.insert(
        id: e.id,
        userId: e.userId,
        updatedAt: e.updatedAt,
        type: e.type,
        date: e.date,
        accountId: e.accountId,
        merchantId: Value(e.merchantId),
        counterAccountId: Value(e.counterAccountId),
        currencyCode: e.currencyCode,
        totalAmount: e.total.amount,
        baseAmount: e.base.amount,
        note: Value(e.note),
        source: e.source,
        status: e.status,
        createdAt: e.createdAt,
        deleted: Value(e.deleted),
        version: Value(e.version),
      );
}

extension on TransactionEntity {
  // currencyCode is duplicated on the entity for the row; keep it explicit.
  String get currencyCode => total.currencyCode;
}
