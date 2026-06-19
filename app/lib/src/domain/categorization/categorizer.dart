import '../entities/categorization_rule.dart';
import 'category_suggestion.dart';
import 'keyword_category_dictionary.dart';

/// One thing to categorize: a line description plus the document-level merchant.
class CategorizationInput {
  const CategorizationInput({this.merchant, this.description = ''});
  final String? merchant;
  final String description;
}

/// Pure, deterministic category-suggestion engine (docs/05 §6, FR-SCAN-07,
/// FR-CAT-05/06). Evidence is tried in priority order; the first hit wins:
///
///   1. [rules]            — user/learned [CategorizationRule]s (highest priority)
///   2. [merchantDefaults] — a merchant's learned default category (memory)
///   3. [keywords]         — built-in keyword → category dictionary
///   4. nothing            — [CategorySuggestion.none]
///
/// All runtime data (rules, merchant memory, the user's category ids) is injected
/// so the engine stays free of any database/Flutter dependency and is fully
/// unit-testable.
class Categorizer {
  Categorizer({
    List<CategorizationRule> rules = const [],
    this.merchantDefaults = const {},
    Map<String, String> categoryIdByName = const {},
    this.keywords = const KeywordCategoryDictionary(),
  })  : _rules = [...rules.where((r) => r.isEnabled && !r.deleted)]
          ..sort((a, b) => b.priority.compareTo(a.priority)),
        _categoryIdByName = {
          for (final e in categoryIdByName.entries)
            e.key.toLowerCase(): e.value,
        };

  /// Confidence assigned per evidence tier.
  static const ruleConfidence = 0.95;
  static const merchantConfidence = 0.85;
  static const keywordConfidence = 0.6;

  final List<CategorizationRule> _rules; // enabled, sorted by priority desc
  /// Normalized merchant name → categoryId (Merchant.defaultCategoryId, FR-CAT-06).
  final Map<String, String> merchantDefaults;
  final Map<String, String> _categoryIdByName; // lowercased name → id
  final KeywordCategoryDictionary keywords;

  CategorySuggestion suggest(CategorizationInput input) {
    // 1) Explicit rules (priority order, first enabled match wins).
    for (final rule in _rules) {
      if (rule.matches(
          merchant: input.merchant, description: input.description)) {
        return CategorySuggestion(
          categoryId: rule.categoryId,
          confidence: ruleConfidence,
          source: CategorySource.rule,
        );
      }
    }

    // 2) Merchant memory.
    final merchant = input.merchant?.trim().toLowerCase();
    if (merchant != null && merchant.isNotEmpty) {
      final catId = merchantDefaults[merchant];
      if (catId != null) {
        return CategorySuggestion(
          categoryId: catId,
          confidence: merchantConfidence,
          source: CategorySource.merchant,
        );
      }
    }

    // 3) Keyword dictionary (match the description, then the merchant name).
    for (final text in [input.description, input.merchant ?? '']) {
      if (text.trim().isEmpty) continue;
      final name = keywords.categoryNameFor(text);
      final catId = name == null ? null : _categoryIdByName[name.toLowerCase()];
      if (catId != null) {
        return CategorySuggestion(
          categoryId: catId,
          confidence: keywordConfidence,
          source: CategorySource.keyword,
        );
      }
    }

    // 4) Nothing matched.
    return CategorySuggestion.none;
  }
}
