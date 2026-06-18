import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';

part 'category.freezed.dart';

/// Hierarchical category (docs/04 §2.3). `parentId` null = root.
@freezed
abstract class CategoryEntity with _$CategoryEntity {
  const factory CategoryEntity({
    required String id,
    required String userId,
    required String name,
    required CategoryKind kind,
    String? parentId,
    @Default('category') String icon,
    @Default('#4E79A7') String colorHex,
    @Default(false) bool isArchived,
    @Default(0) int sortOrder,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _CategoryEntity;

  const CategoryEntity._();

  bool get isRoot => parentId == null;
}

/// A category plus its direct children, for the hierarchical picker/list.
class CategoryNode {
  const CategoryNode(this.category, this.children);
  final CategoryEntity category;
  final List<CategoryEntity> children;
}
