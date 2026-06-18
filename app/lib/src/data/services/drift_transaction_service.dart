import 'package:drift/drift.dart';

import '../../application/auth_service.dart';
import '../../application/transaction_service.dart';
import '../../domain/entities/line_item.dart';
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
    return _db
        .watchActive(_userId)
        .map((rows) => rows.map(_toEntity).toList(growable: false));
  }

  @override
  Stream<List<LineItemEntity>> watchLineItems(String transactionId) async* {
    final tx = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(transactionId))).getSingleOrNull();
    final currency = tx?.currencyCode ?? '';
    yield* _db
        .watchLineItems(transactionId)
        .map((rows) => rows.map((r) => _toLine(r, currency)).toList());
  }

  @override
  Future<TransactionEntity?> getById(String id) async {
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<TransactionEntity> upsert(TransactionEntity tx) =>
      upsertWithLines(tx, const []);

  @override
  Future<TransactionEntity> upsertWithLines(
    TransactionEntity header,
    List<LineItemEntity> lines, {
    List<String> removedLineItemIds = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final next = header.copyWith(updatedAt: now, version: header.version + 1);
    await _db.upsertTransactionWithLines(
      header: _toCompanion(next),
      lines: lines
          .map(
            (l) => _toLineCompanion(
              l.copyWith(updatedAt: now, version: l.version + 1),
            ),
          )
          .toList(),
      removedLineItemIds: removedLineItemIds,
      now: now,
    );
    return next;
  }

  @override
  Future<void> softDelete(String id) =>
      _db.softDeleteTransaction(id, DateTime.now().toUtc());

  // --- mapping ----------------------------------------------------------

  TransactionEntity _toEntity(db.Transaction r) => TransactionEntity(
    id: r.id,
    userId: r.userId,
    type: r.type,
    date: r.date,
    accountId: r.accountId,
    merchantId: r.merchantId,
    counterAccountId: r.counterAccountId,
    total: Money(r.totalAmount, r.currencyCode),
    base: Money(r.baseAmount, r.currencyCode),
    note: r.note,
    source: r.source,
    status: r.status,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deleted: r.deleted,
    version: r.version,
  );

  LineItemEntity _toLine(db.LineItem r, String currencyCode) => LineItemEntity(
    id: r.id,
    userId: r.userId,
    transactionId: r.transactionId,
    description: r.description,
    quantity: r.quantity,
    lineAmount: Money(r.lineAmount, currencyCode),
    categoryId: r.categoryId,
    unitPrice: r.unitPrice == null ? null : Money(r.unitPrice!, currencyCode),
    taxRate: r.taxRate,
    ocrConfidence: r.ocrConfidence,
    sortOrder: r.sortOrder,
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
        currencyCode: e.total.currencyCode,
        totalAmount: e.total.amount,
        baseAmount: e.base.amount,
        note: Value(e.note),
        source: e.source,
        status: e.status,
        createdAt: e.createdAt,
        deleted: Value(e.deleted),
        version: Value(e.version),
      );

  db.LineItemsCompanion _toLineCompanion(LineItemEntity e) =>
      db.LineItemsCompanion.insert(
        id: e.id,
        userId: e.userId,
        updatedAt: e.updatedAt,
        transactionId: e.transactionId,
        description: e.description,
        quantity: e.quantity,
        lineAmount: e.lineAmount.amount,
        categoryId: e.categoryId,
        unitPrice: Value(e.unitPrice?.amount),
        taxRate: Value(e.taxRate),
        ocrConfidence: Value(e.ocrConfidence),
        sortOrder: Value(e.sortOrder),
        deleted: Value(e.deleted),
        version: Value(e.version),
      );
}
