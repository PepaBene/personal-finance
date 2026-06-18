import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/categorization_service.dart';
import 'package:ledgerly_app/src/domain/categorization/categorizer.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/scan/document_draft.dart';

void main() {
  const categoryIdByName = {'Groceries': 'cat-groceries', 'Fuel': 'cat-fuel'};

  LineItemDraft item(String desc, {String? categoryId}) => LineItemDraft(
        description: desc,
        lineAmount: Decimal.parse('1.00'),
        categoryId: categoryId,
      );

  DocumentDraft draft(List<LineItemDraft> items, {String? merchant}) =>
      DocumentDraft(
          type: DocType.receipt, merchant: merchant, lineItems: items);

  test('annotates uncategorized line items via the engine', () {
    final categorizer = CategorizingDraftCategorizer(
      Categorizer(categoryIdByName: categoryIdByName),
    );
    final result = categorizer.categorize(
      draft([item('Mléko'), item('Nafta')], merchant: 'Albert'),
    );
    expect(result.lineItems[0].categoryId, 'cat-groceries');
    expect(
        result.lineItems[0].categoryConfidence, Categorizer.keywordConfidence);
    expect(result.lineItems[1].categoryId, 'cat-fuel');
  });

  test('leaves already-categorized line items untouched', () {
    final categorizer = CategorizingDraftCategorizer(
      Categorizer(categoryIdByName: categoryIdByName),
    );
    final result = categorizer.categorize(
      draft([item('Mléko', categoryId: 'user-picked')]),
    );
    expect(result.lineItems.single.categoryId, 'user-picked');
    expect(result.lineItems.single.categoryConfidence, isNull);
  });

  test('merchant memory applies to generic line descriptions', () {
    final categorizer = CategorizingDraftCategorizer(
      Categorizer(merchantDefaults: const {'albert': 'cat-groceries'}),
    );
    final result = categorizer.categorize(
      draft([item('položka 1')], merchant: 'Albert'),
    );
    expect(result.lineItems.single.categoryId, 'cat-groceries');
    expect(
      result.lineItems.single.categoryConfidence,
      Categorizer.merchantConfidence,
    );
  });
}
