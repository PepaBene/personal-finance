import 'package:drift/drift.dart';

import '../../application/auth_service.dart';
import '../../application/categorization_rule_service.dart';
import '../../domain/categorization/categorizer.dart';
import '../../domain/entities/categorization_rule.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [CategorizationRuleService]. Reads/writes the local store only;
/// PowerSync replicates rows underneath (docs/13 §5).
class DriftCategorizationRuleService implements CategorizationRuleService {
  DriftCategorizationRuleService(this._db, this._auth);

  final db.AppDatabase _db;
  final AuthService _auth;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) {
      throw StateError('No authenticated user; cannot access rules.');
    }
    return session.userId;
  }

  @override
  Stream<List<CategorizationRule>> watchRules() => _db
      .watchCategorizationRules(_userId)
      .map((rows) => rows.map(_toEntity).toList(growable: false));

  @override
  Future<void> upsert(CategorizationRule rule) {
    final now = DateTime.now().toUtc();
    return _db.upsertCategorizationRule(
      db.CategorizationRulesCompanion.insert(
        id: rule.id,
        userId: rule.userId,
        updatedAt: now,
        matchType: rule.matchType,
        pattern: rule.pattern,
        categoryId: rule.categoryId,
        priority: Value(rule.priority),
        isEnabled: Value(rule.isEnabled),
        deleted: Value(rule.deleted),
        version: Value(rule.version + 1),
      ),
    );
  }

  @override
  Future<void> delete(String id) =>
      _db.softDeleteCategorizationRule(id, DateTime.now().toUtc());

  @override
  Future<Categorizer> buildCategorizer() async {
    final userId = _userId;
    final rows = await _db.watchCategorizationRules(userId).first;
    final merchantDefaults = await _db.merchantDefaultCategories(userId);
    final categoryIdByName = await _db.categoryIdsByName(userId);
    return Categorizer(
      rules: rows.map(_toEntity).toList(growable: false),
      merchantDefaults: merchantDefaults,
      categoryIdByName: categoryIdByName,
    );
  }

  CategorizationRule _toEntity(db.CategorizationRuleRow r) =>
      CategorizationRule(
        id: r.id,
        userId: r.userId,
        matchType: r.matchType,
        pattern: r.pattern,
        categoryId: r.categoryId,
        priority: r.priority,
        isEnabled: r.isEnabled,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );
}
