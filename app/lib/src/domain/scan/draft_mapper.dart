import 'package:decimal/decimal.dart';

import '../entities/line_item.dart';
import '../entities/transaction.dart';
import '../enums.dart';
import '../money.dart';
import 'document_draft.dart';

/// Everything the [DraftMapper] needs that lives *outside* the draft — resolved
/// by the caller (review-screen view-model) before persisting: the signed-in
/// user, the chosen account, the currency actually stored, the FX-converted
/// [base] for the header, an optional resolved [merchantId], and the category to
/// fall back to for any line the user/auto-categorizer left unset.
///
/// [newId] and [now] are injected so mapping is deterministic and unit-testable.
class DraftMappingContext {
  const DraftMappingContext({
    required this.userId,
    required this.accountId,
    required this.currencyCode,
    required this.base,
    required this.fallbackCategoryId,
    required this.newId,
    required this.now,
    this.merchantId,
  });

  final String userId;
  final String accountId;
  final String currencyCode;

  /// Header total converted to the base currency (FR-CUR-02). Equals the total
  /// when the document is already in the base currency.
  final Money base;

  /// Category for line items with no `categoryId` (docs/05 §6 "Uncategorized").
  final String fallbackCategoryId;

  /// Resolved/learned merchant id, or null to leave the header merchant unset.
  final String? merchantId;

  final String Function() newId;
  final DateTime now;
}

/// Result of mapping a reviewed [DocumentDraft] to persistable entities, ready
/// for `TransactionService.upsertWithLines`.
class DraftMapping {
  const DraftMapping(this.header, this.lines);
  final TransactionEntity header;
  final List<LineItemEntity> lines;
}

/// Maps a reviewed [DocumentDraft] (docs/05 §8 stage 8) to a [TransactionEntity]
/// plus [LineItemEntity]s. Pure and synchronous: FX, merchant resolution, and the
/// fallback category are resolved by the caller and passed via
/// [DraftMappingContext]. Tax is informational on tax-inclusive receipts, so it
/// is not emitted as a separate line; the header total is taken from the (already
/// reconciled) draft, falling back to the sum of line amounts.
class DraftMapper {
  const DraftMapper();

  DraftMapping map(DocumentDraft draft, DraftMappingContext ctx) {
    final currency = ctx.currencyCode;
    final txId = ctx.newId();
    final lines = _lines(draft, ctx, currency, txId);

    final lineSum = lines.fold(Decimal.zero, (s, l) => s + l.lineAmount.amount);
    final totalAmount = draft.total ?? lineSum;
    final total = Money(totalAmount, currency);

    final date = draft.date ?? ctx.now;
    final header = TransactionEntity(
      id: txId,
      userId: ctx.userId,
      type: _txType(draft.type),
      date: DateTime.utc(date.year, date.month, date.day),
      accountId: ctx.accountId,
      merchantId: ctx.merchantId,
      total: total,
      base: ctx.base,
      source: TxSource.scan,
      createdAt: ctx.now,
      updatedAt: ctx.now,
    );
    return DraftMapping(header, lines);
  }

  List<LineItemEntity> _lines(
    DocumentDraft draft,
    DraftMappingContext ctx,
    String currency,
    String txId,
  ) {
    if (draft.lineItems.isEmpty) {
      // Single-line fallback (docs/05 §6): one line for the whole total.
      final amount = draft.total ?? Decimal.zero;
      return [
        LineItemEntity(
          id: ctx.newId(),
          userId: ctx.userId,
          transactionId: txId,
          description: _desc(draft.merchant),
          quantity: Decimal.one,
          lineAmount: Money(amount, currency),
          categoryId: ctx.fallbackCategoryId,
          updatedAt: ctx.now,
        ),
      ];
    }

    var i = 0;
    return [
      for (final item in draft.lineItems)
        LineItemEntity(
          id: ctx.newId(),
          userId: ctx.userId,
          transactionId: txId,
          description: _desc(item.description),
          quantity: item.quantity ?? Decimal.one,
          lineAmount: Money(item.lineAmount, currency),
          categoryId: item.categoryId ?? ctx.fallbackCategoryId,
          unitPrice:
              item.unitPrice == null ? null : Money(item.unitPrice!, currency),
          ocrConfidence: item.confidence,
          sortOrder: i++,
          updatedAt: ctx.now,
        ),
    ];
  }

  /// Receipts/invoices/bills are expenses; paychecks are income (docs/05 §4).
  TxType _txType(DocType type) =>
      type == DocType.paycheck ? TxType.income : TxType.expense;

  String _desc(String? raw) {
    final t = raw?.trim() ?? '';
    return t.isEmpty ? 'Item' : t;
  }
}
