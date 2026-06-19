import 'package:drift/drift.dart';

import '../../application/auth_service.dart';
import '../../application/budget_service.dart';
import '../../domain/entities/budget.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [BudgetService]. Reads/writes the local encrypted DB only;
/// PowerSync replicates rows underneath (docs/13 §5).
class DriftBudgetService implements BudgetService {
  DriftBudgetService(this._db, this._auth);

  final db.AppDatabase _db;
  final AuthService _auth;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  @override
  Stream<List<BudgetEntity>> watchAll() {
    return _db
        .watchBudgets(_userId)
        .map((rows) => rows.map(_toEntity).toList(growable: false));
  }

  @override
  Future<List<BudgetEntity>> getAll() async {
    final rows = await _db.getBudgets(_userId);
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<BudgetEntity> upsert(BudgetEntity budget) async {
    final next = budget.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version: budget.version + 1,
    );
    await _db.upsertBudget(_toCompanion(next));
    return next;
  }

  @override
  Future<void> delete(String id) =>
      _db.softDeleteBudget(id, DateTime.now().toUtc());

  BudgetEntity _toEntity(db.Budget r) => BudgetEntity(
        id: r.id,
        userId: r.userId,
        categoryId: r.categoryId,
        amount: Money(r.amount, r.currencyCode),
        period: r.period,
        startMonth: r.startMonth,
        isActive: r.isActive,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );

  db.BudgetsCompanion _toCompanion(BudgetEntity e) =>
      db.BudgetsCompanion.insert(
        id: e.id,
        userId: e.userId,
        updatedAt: e.updatedAt,
        categoryId: e.categoryId,
        period: e.period,
        amount: e.amount.amount,
        currencyCode: e.amount.currencyCode,
        startMonth: e.startMonth,
        isActive: Value(e.isActive),
        deleted: Value(e.deleted),
        version: Value(e.version),
      );
}
