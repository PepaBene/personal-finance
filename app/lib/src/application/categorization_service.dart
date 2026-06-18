import '../domain/categorization/categorizer.dart';
import '../domain/scan/document_draft.dart';

export '../domain/categorization/category_suggestion.dart';
export '../domain/categorization/categorizer.dart' show CategorizationInput;

/// Stage 6 port (docs/05 §6): annotate a parsed [DocumentDraft] with suggested
/// categories for each line item. Implementations load the user's rules, merchant
/// memory, and categories; the orchestrator depends only on this interface.
abstract interface class DraftCategorizer {
  /// Returns a copy of [draft] with each line item's `categoryId` /
  /// `categoryConfidence` filled from the best available suggestion. Line items
  /// that already have a category are left untouched.
  DocumentDraft categorize(DocumentDraft draft);
}

/// A [DraftCategorizer] backed by the pure [Categorizer]. Constructed with the
/// runtime data the engine needs; the engine itself stays database-free.
class CategorizingDraftCategorizer implements DraftCategorizer {
  const CategorizingDraftCategorizer(this._categorizer);

  final Categorizer _categorizer;

  @override
  DocumentDraft categorize(DocumentDraft draft) {
    if (draft.lineItems.isEmpty) return draft;
    final items = [
      for (final item in draft.lineItems)
        if (item.categoryId != null) item else _annotate(item, draft.merchant),
    ];
    return draft.copyWith(lineItems: items);
  }

  LineItemDraft _annotate(LineItemDraft item, String? merchant) {
    final s = _categorizer.suggest(
      CategorizationInput(merchant: merchant, description: item.description),
    );
    if (!s.hasMatch) return item;
    return item.copyWith(
      categoryId: s.categoryId,
      categoryConfidence: s.confidence,
    );
  }
}
