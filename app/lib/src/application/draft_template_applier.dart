import '../domain/entities/merchant_template.dart';
import '../domain/scan/document_draft.dart';

/// Stage that applies a learned per-merchant template to a freshly parsed
/// [DocumentDraft] before categorization (docs/05 §10, FR-SCAN-10). Runs after
/// parse and before the keyword/rule categorizer, so merchant-specific memory
/// takes precedence over generic guesses.
abstract interface class DraftTemplateApplier {
  DocumentDraft apply(DocumentDraft draft);
}

/// Pure [DraftTemplateApplier]: given a snapshot of the user's templates keyed by
/// normalized merchant name, fills a draft's missing currency and assigns
/// categories to line items whose description matches a learned hint. Database-
/// free, so it is fully unit-testable.
class MerchantTemplateDraftApplier implements DraftTemplateApplier {
  const MerchantTemplateDraftApplier(this._byMerchantKey);

  final Map<String, MerchantTemplateEntity> _byMerchantKey;

  /// Confidence for a category assigned from a learned merchant hint — above the
  /// keyword dictionary, comparable to explicit merchant memory.
  static const hintConfidence = 0.9;

  @override
  DocumentDraft apply(DocumentDraft draft) {
    final key = MerchantTemplateEntity.keyFor(draft.merchant);
    final tpl = key == null ? null : _byMerchantKey[key];
    if (tpl == null) return draft;

    final hints = tpl.categoryHints;
    final items = [
      for (final item in draft.lineItems)
        if (item.categoryId != null)
          item
        else
          _applyHint(item, hints),
    ];

    return draft.copyWith(
      // Fill currency only when the parser couldn't determine it.
      currencyCode: draft.currencyCode ?? tpl.currencyCode,
      lineItems: items,
    );
  }

  LineItemDraft _applyHint(LineItemDraft item, Map<String, String> hints) {
    final categoryId = hints[MerchantTemplateEntity.normalize(item.description)];
    if (categoryId == null) return item;
    return item.copyWith(
      categoryId: categoryId,
      categoryConfidence: hintConfidence,
    );
  }
}
