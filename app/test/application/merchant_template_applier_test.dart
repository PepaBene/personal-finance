import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/draft_template_applier.dart';
import 'package:ledgerly_app/src/domain/entities/merchant_template.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/scan/document_draft.dart';

void main() {
  MerchantTemplateEntity template({
    String key = 'albert',
    String? currency,
    Map<String, String> hints = const {},
  }) {
    return MerchantTemplateEntity(
      id: 't',
      userId: 'u',
      merchantKey: key,
      currencyCode: currency,
      categoryHints: hints,
      updatedAt: DateTime.utc(2026),
    );
  }

  DocumentDraft draft({
    String? merchant = 'Albert',
    String? currency,
    List<LineItemDraft> lines = const [],
  }) {
    return DocumentDraft(
      type: DocType.receipt,
      merchant: merchant,
      currencyCode: currency,
      lineItems: lines,
    );
  }

  LineItemDraft line(String desc, {String? categoryId}) => LineItemDraft(
        description: desc,
        lineAmount: Decimal.parse('10.00'),
        categoryId: categoryId,
      );

  test('fills missing currency and assigns learned category hints', () {
    final applier = MerchantTemplateDraftApplier({
      'albert': template(currency: 'CZK', hints: {'milk 1l': 'groceries'}),
    });
    final result = applier.apply(
      draft(lines: [line('Milk 1L'), line('Unknown item')]),
    );
    expect(result.currencyCode, 'CZK');
    expect(result.lineItems[0].categoryId, 'groceries');
    expect(
      result.lineItems[0].categoryConfidence,
      MerchantTemplateDraftApplier.hintConfidence,
    );
    expect(result.lineItems[1].categoryId, isNull); // no hint
  });

  test('does not override a category the parser already set', () {
    final applier = MerchantTemplateDraftApplier({
      'albert': template(hints: {'milk 1l': 'groceries'}),
    });
    final result = applier.apply(
      draft(lines: [line('Milk 1L', categoryId: 'dining')]),
    );
    expect(result.lineItems.single.categoryId, 'dining');
  });

  test('does not override a currency the parser already detected', () {
    final applier = MerchantTemplateDraftApplier({
      'albert': template(currency: 'CZK'),
    });
    final result = applier.apply(draft(currency: 'EUR'));
    expect(result.currencyCode, 'EUR');
  });

  test('no template for the merchant leaves the draft unchanged', () {
    const applier = MerchantTemplateDraftApplier({});
    final input = draft(lines: [line('Milk 1L')]);
    final result = applier.apply(input);
    expect(result.currencyCode, isNull);
    expect(result.lineItems.single.categoryId, isNull);
  });

  test('matches merchant case-insensitively', () {
    final applier = MerchantTemplateDraftApplier({
      'albert': template(currency: 'CZK'),
    });
    final result = applier.apply(draft(merchant: '  ALBERT '));
    expect(result.currencyCode, 'CZK');
  });
}
