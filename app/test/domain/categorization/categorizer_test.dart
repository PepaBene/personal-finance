import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/categorization/categorizer.dart';
import 'package:ledgerly_app/src/domain/categorization/category_suggestion.dart';
import 'package:ledgerly_app/src/domain/entities/categorization_rule.dart';
import 'package:ledgerly_app/src/domain/enums.dart';

CategorizationRule _rule(
  CategoryMatchType type,
  String pattern,
  String categoryId, {
  int priority = 0,
  bool enabled = true,
}) =>
    CategorizationRule(
      id: pattern,
      userId: 'u1',
      matchType: type,
      pattern: pattern,
      categoryId: categoryId,
      priority: priority,
      isEnabled: enabled,
      updatedAt: DateTime.utc(2026),
    );

void main() {
  // Maps the built-in dictionary's category names to this user's ids.
  const categoryIdByName = {
    'Groceries': 'cat-groceries',
    'Fuel': 'cat-fuel',
    'Dining': 'cat-dining',
    'Health': 'cat-health',
  };

  group('rules', () {
    test('explicit rule wins over everything with high confidence', () {
      final c = Categorizer(
        rules: [_rule(CategoryMatchType.merchantEquals, 'Albert', 'cat-x')],
        categoryIdByName: categoryIdByName,
      );
      final s = c.suggest(
        const CategorizationInput(merchant: 'Albert', description: 'Mléko'),
      );
      expect(s.categoryId, 'cat-x');
      expect(s.source, CategorySource.rule);
      expect(s.confidence, Categorizer.ruleConfidence);
    });

    test('higher priority rule beats a lower one', () {
      final c = Categorizer(
        rules: [
          _rule(CategoryMatchType.descriptionContains, 'milk', 'cat-low',
              priority: 1),
          _rule(CategoryMatchType.descriptionContains, 'milk', 'cat-high',
              priority: 10),
        ],
      );
      final s =
          c.suggest(const CategorizationInput(description: 'organic milk'));
      expect(s.categoryId, 'cat-high');
    });

    test('disabled rules are ignored', () {
      final c = Categorizer(
        rules: [
          _rule(CategoryMatchType.descriptionContains, 'milk', 'cat-off',
              enabled: false),
        ],
        categoryIdByName: categoryIdByName,
      );
      final s = c.suggest(const CategorizationInput(description: 'milk'));
      // Falls through to the keyword dictionary (milk → Groceries).
      expect(s.categoryId, 'cat-groceries');
      expect(s.source, CategorySource.keyword);
    });

    test('regex rule matches case-insensitively and survives bad patterns', () {
      final c = Categorizer(
        rules: [
          _rule(CategoryMatchType.regex, r'shell|omv', 'cat-fuel-rule'),
          _rule(CategoryMatchType.regex, r'[unclosed', 'cat-never'),
        ],
      );
      expect(
        c
            .suggest(const CategorizationInput(description: 'SHELL station'))
            .categoryId,
        'cat-fuel-rule',
      );
      // Invalid regex never throws and never matches.
      expect(
        c.suggest(const CategorizationInput(description: 'nothing')).source,
        CategorySource.none,
      );
    });
  });

  group('merchant memory', () {
    test('uses a merchant default when no rule matches', () {
      final c = Categorizer(
        merchantDefaults: const {'kaufland': 'cat-mem'},
        categoryIdByName: categoryIdByName,
      );
      final s = c.suggest(
        const CategorizationInput(merchant: 'Kaufland', description: 'xyz'),
      );
      expect(s.categoryId, 'cat-mem');
      expect(s.source, CategorySource.merchant);
      expect(s.confidence, Categorizer.merchantConfidence);
    });
  });

  group('keyword dictionary', () {
    test('matches Czech and English grocery terms', () {
      final c = Categorizer(categoryIdByName: categoryIdByName);
      expect(
          c.suggest(const CategorizationInput(description: 'Mléko')).categoryId,
          'cat-groceries');
      expect(
          c.suggest(const CategorizationInput(description: 'Bread')).categoryId,
          'cat-groceries');
    });

    test('matches on the merchant name when the description is generic', () {
      final c = Categorizer(categoryIdByName: categoryIdByName);
      final s = c.suggest(
        const CategorizationInput(merchant: 'Shell', description: 'item 1'),
      );
      expect(s.categoryId, 'cat-fuel');
      expect(s.source, CategorySource.keyword);
    });

    test('a keyword with no mapped category id falls through to none', () {
      // 'kino' → Leisure, but this user has no Leisure category id.
      final c = Categorizer(categoryIdByName: categoryIdByName);
      final s =
          c.suggest(const CategorizationInput(description: 'Kino lístek'));
      expect(s.source, CategorySource.none);
    });
  });

  test('returns none when nothing matches', () {
    final c = Categorizer(categoryIdByName: categoryIdByName);
    expect(
      c.suggest(const CategorizationInput(description: 'zxqw')),
      CategorySuggestion.none,
    );
  });
}
