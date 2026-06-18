import '../domain/entities/category.dart';

/// Category management (FR-CAT-01..03). Implemented in `data/`.
abstract interface class CategoryService {
  /// All active categories for the signed-in user, flat.
  Stream<List<CategoryEntity>> watchAll();

  /// Active categories arranged as roots with their direct children.
  Stream<List<CategoryNode>> watchTree();

  Future<CategoryEntity> upsert(CategoryEntity category);

  /// Archive (hide without deleting history — FR-CAT-02).
  Future<void> archive(String id);
}
