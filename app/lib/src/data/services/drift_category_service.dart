import 'package:drift/drift.dart';

import '../../application/auth_service.dart';
import '../../application/category_service.dart';
import '../../domain/entities/category.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [CategoryService].
class DriftCategoryService implements CategoryService {
  DriftCategoryService(this._db, this._auth);

  final db.AppDatabase _db;
  final AuthService _auth;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  @override
  Stream<List<CategoryEntity>> watchAll() {
    return _db
        .watchCategories(_userId)
        .map((rows) => rows.map(_toEntity).toList(growable: false));
  }

  @override
  Stream<List<CategoryNode>> watchTree() {
    return watchAll().map((all) {
      final roots = all.where((c) => c.isRoot).toList();
      final byParent = <String, List<CategoryEntity>>{};
      for (final c in all) {
        if (c.parentId != null) {
          byParent.putIfAbsent(c.parentId!, () => []).add(c);
        }
      }
      return roots
          .map((r) => CategoryNode(r, byParent[r.id] ?? const []))
          .toList(growable: false);
    });
  }

  @override
  Future<CategoryEntity> upsert(CategoryEntity category) async {
    final next = category.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version: category.version + 1,
    );
    await _db.into(_db.categories).insertOnConflictUpdate(_toCompanion(next));
    return next;
  }

  @override
  Future<void> archive(String id) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      db.CategoriesCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  CategoryEntity _toEntity(db.Category r) => CategoryEntity(
        id: r.id,
        userId: r.userId,
        name: r.name,
        kind: r.kind,
        parentId: r.parentId,
        icon: r.icon,
        colorHex: r.colorHex,
        isArchived: r.isArchived,
        sortOrder: r.sortOrder,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );

  db.CategoriesCompanion _toCompanion(CategoryEntity e) =>
      db.CategoriesCompanion.insert(
        id: e.id,
        userId: e.userId,
        updatedAt: e.updatedAt,
        name: e.name,
        kind: e.kind,
        parentId: Value(e.parentId),
        icon: Value(e.icon),
        colorHex: Value(e.colorHex),
        isArchived: Value(e.isArchived),
        sortOrder: Value(e.sortOrder),
        deleted: Value(e.deleted),
        version: Value(e.version),
      );
}
