import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/money.dart';
import 'package:ledgerly_app/src/domain/scan/document_draft.dart';
import 'package:ledgerly_app/src/domain/scan/draft_mapper.dart';

void main() {
  const mapper = DraftMapper();
  final now = DateTime.utc(2026, 6, 18, 10);

  // Deterministic id generator: id0, id1, id2, ...
  DraftMappingContext ctx({
    String currency = 'CZK',
    Money? base,
    String? merchantId = 'm-albert',
    String fallback = 'cat-misc',
  }) {
    var n = 0;
    return DraftMappingContext(
      userId: 'u1',
      accountId: 'acc-cash',
      currencyCode: currency,
      base: base ?? Money(Decimal.parse('9.36'), currency),
      fallbackCategoryId: fallback,
      merchantId: merchantId,
      newId: () => 'id${n++}',
      now: now,
    );
  }

  DocumentDraft receipt() => DocumentDraft(
        type: DocType.receipt,
        merchant: 'Albert',
        date: DateTime.utc(2026, 6, 8),
        total: Decimal.parse('234.10'),
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
      );

  test('maps header fields from a reviewed receipt', () {
    final m = mapper.map(receipt(), ctx());
    final h = m.header;
    expect(h.type, TxType.expense);
    expect(h.source, TxSource.scan);
    expect(h.userId, 'u1');
    expect(h.accountId, 'acc-cash');
    expect(h.merchantId, 'm-albert');
    expect(h.date, DateTime.utc(2026, 6, 8));
    expect(h.total, Money(Decimal.parse('234.10'), 'CZK'));
    expect(h.base, Money(Decimal.parse('9.36'), 'CZK'));
    expect(h.createdAt, now);
    expect(h.updatedAt, now);
  });

  test('maps line items, preserving category, confidence and order', () {
    final m = mapper.map(receipt(), ctx());
    expect(m.lines.length, 2);
    final first = m.lines[0];
    expect(first.transactionId, m.header.id);
    expect(first.description, 'Mleko');
    expect(first.lineAmount, Money(Decimal.parse('49.80'), 'CZK'));
    expect(first.categoryId, 'cat-groceries');
    expect(first.ocrConfidence, 0.9);
    expect(first.quantity, Decimal.one);
    expect(first.sortOrder, 0);

    // Second line had no category → falls back; default order/qty.
    expect(m.lines[1].categoryId, 'cat-misc');
    expect(m.lines[1].sortOrder, 1);

    // Distinct generated ids, all sharing one transaction id.
    expect(m.lines.map((l) => l.id).toSet().length, 2);
    expect(m.lines.every((l) => l.transactionId == m.header.id), isTrue);
  });

  test('falls back to the line sum when no total was detected', () {
    final draft = receipt().copyWith(total: null);
    final m = mapper.map(draft, ctx());
    expect(m.header.total, Money(Decimal.parse('84.70'), 'CZK'));
  });

  test('produces a single line for a draft with no line items', () {
    final draft = DocumentDraft(
      type: DocType.receipt,
      merchant: 'Albert',
      total: Decimal.parse('234.10'),
      currencyCode: 'CZK',
    );
    final m = mapper.map(draft, ctx());
    expect(m.lines.single.description, 'Albert');
    expect(m.lines.single.lineAmount, Money(Decimal.parse('234.10'), 'CZK'));
    expect(m.lines.single.categoryId, 'cat-misc');
    expect(m.header.total, Money(Decimal.parse('234.10'), 'CZK'));
  });

  test('keeps the merchant id out of the note when one is resolved', () {
    expect(mapper.map(receipt(), ctx()).header.note, isNull);
  });

  test('falls back to the merchant name as note when no merchant id', () {
    final m = mapper.map(receipt(), ctx(merchantId: null));
    expect(m.header.merchantId, isNull);
    expect(m.header.note, 'Albert');
  });

  test('maps paychecks to income', () {
    final draft = receipt().copyWith(type: DocType.paycheck);
    expect(mapper.map(draft, ctx()).header.type, TxType.income);
  });

  test('uses now (date-only, UTC) when the draft has no date', () {
    final draft = receipt().copyWith(date: null);
    expect(mapper.map(draft, ctx()).header.date, DateTime.utc(2026, 6, 18));
  });
}
