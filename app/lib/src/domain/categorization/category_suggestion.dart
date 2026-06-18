/// Where a category suggestion came from (docs/05 §6 ordering). Higher in the
/// list = stronger evidence.
enum CategorySource { rule, merchant, keyword, none }

/// A suggested category for a line item, with the evidence behind it (FR-SCAN-07,
/// FR-SCAN-11). [categoryId] is null when nothing matched.
class CategorySuggestion {
  const CategorySuggestion({
    required this.categoryId,
    required this.confidence,
    required this.source,
  });

  /// Empty suggestion — nothing matched; the user must pick a category.
  static const none = CategorySuggestion(
    categoryId: null,
    confidence: 0,
    source: CategorySource.none,
  );

  final String? categoryId;
  final double confidence;
  final CategorySource source;

  bool get hasMatch => categoryId != null;

  @override
  bool operator ==(Object other) =>
      other is CategorySuggestion &&
      other.categoryId == categoryId &&
      other.confidence == confidence &&
      other.source == source;

  @override
  int get hashCode => Object.hash(categoryId, confidence, source);

  @override
  String toString() =>
      'CategorySuggestion($categoryId, $confidence, ${source.name})';
}
