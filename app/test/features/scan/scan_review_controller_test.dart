import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/money.dart';
import 'package:ledgerly_app/src/domain/scan/document_draft.dart';
import 'package:ledgerly_app/src/domain/scan/draft_mapper.dart';
import 'package:ledgerly_app/src/features/scan/scan_review_controller.dart';

DocumentDraft _draft() => DocumentDraft(
      type: DocType.receipt,
      typeConfidence: 0.8,
      merchant: 'Albert',
      date: DateTime.utc(2026, 6, 8),
      total: Decimal.parse('84.70'),
      currencyCode: 'CZK',
      lineItems: [
        LineItemDraft(
          description: 'Mleko',
          lineAmount: Decimal.parse('49.80'),
          categoryId: 'cat-groceries',
          categoryConfidence: 0.6,
          confidence: 0.9,
        ),
        LineItemDraft(
          description: 'Chleba',
          lineAmount: Decimal.parse('34.90'),
        ),
      ],
      fieldConfidence: const {
        'merchant': 0.8,
        'date': 0.9,
        'total': 0.5,
        'currency': 0.9,
      },
    );

void main() {
  test('seeds editable state from the draft', () {
    final c = ScanReviewController(_draft());
    expect(c.docType, DocType.receipt);
    expect(c.merchant, 'Albert');
    expect(c.date, DateTime.utc(2026, 6, 8));
    expect(c.total, Decimal.parse('84.70'));
    expect(c.currencyCode, 'CZK');
    expect(c.lines, hasLength(2));
    expect(c.lines.first.categoryId, 'cat-groceries');
  });

  test('reconciliation reflects the entered total vs the line sum', () {
    final c = ScanReviewController(_draft());
    expect(c.lineSum, Decimal.parse('84.70'));
    expect(c.isReconciled, isTrue);
    expect(c.reconciliationDelta, Decimal.zero);

    c.setLineAmount(0, Decimal.parse('40.00'));
    expect(c.isReconciled, isFalse);
    // total 84.70 − (40.00 + 34.90) = 9.80
    expect(c.reconciliationDelta, Decimal.parse('9.80'));
  });

  test('flags low-confidence header fields (FR-SCAN-11)', () {
    final c = ScanReviewController(_draft());
    expect(c.isFieldLow('total'), isTrue); // 0.5 < 0.75
    expect(c.isFieldLow('merchant'), isFalse); // 0.8
    expect(c.isFieldLow('missing'), isFalse); // no score
  });

  test('notifies listeners on edits', () {
    final c = ScanReviewController(_draft());
    var n = 0;
    c.addListener(() => n++);
    c.setMerchant('Lidl');
    c.setTotal(Decimal.parse('90.00'));
    expect(n, 2);
    expect(c.merchant, 'Lidl');
  });

  test('choosing a category marks it fully confident', () {
    final c = ScanReviewController(_draft());
    c.setLineCategory(1, 'cat-bakery');
    expect(c.lines[1].categoryId, 'cat-bakery');
    expect(c.lines[1].categoryConfidence, 1.0);
  });

  test('add/remove line items updates the reviewed draft', () {
    final c = ScanReviewController(_draft());
    c.addLine();
    expect(c.lines, hasLength(3));
    c.removeLine(0);
    expect(c.lines, hasLength(2));
    expect(c.reviewedDraft.lineItems.first.description, 'Chleba');
  });

  test('reviewedDraft reflects edits and drops a blank merchant', () {
    final c = ScanReviewController(_draft())
      ..setMerchant('   ')
      ..setDocType(DocType.invoice);
    final d = c.reviewedDraft;
    expect(d.merchant, isNull);
    expect(d.type, DocType.invoice);
  });

  test('buildMapping produces persistable entities via DraftMapper', () {
    final c = ScanReviewController(_draft());
    var n = 0;
    final mapping = c.buildMapping(
      DraftMappingContext(
        userId: 'u1',
        accountId: 'acc',
        currencyCode: 'CZK',
        base: Money(Decimal.parse('3.39'), 'CZK'),
        fallbackCategoryId: 'cat-misc',
        merchantId: null,
        newId: () => 'id${n++}',
        now: DateTime.utc(2026, 6, 18),
      ),
    );
    expect(mapping.header.type, TxType.expense);
    expect(mapping.header.total, Money(Decimal.parse('84.70'), 'CZK'));
    expect(mapping.header.note, 'Albert'); // no merchant id → kept as note
    expect(mapping.lines, hasLength(2));
    expect(mapping.lines[1].categoryId, 'cat-misc'); // fallback applied
  });
}
