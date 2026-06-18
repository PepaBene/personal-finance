import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../domain/enums.dart';
import '../../domain/scan/document_draft.dart';
import '../../domain/scan/draft_mapper.dart';

/// One editable line on the review screen. Mutable so text-field edits update in
/// place; [confidence]/[categoryConfidence] are carried for the highlight UI.
class EditableLine {
  EditableLine({
    required this.description,
    required this.amount,
    this.categoryId,
    this.confidence = 1.0,
    this.categoryConfidence,
  });

  String description;
  Decimal amount;
  String? categoryId;
  double confidence;
  double? categoryConfidence;
}

/// Editable, framework-light state for the scan review screen (docs/06 §2.5,
/// FR-SCAN-06/11). Holds the user-correctable mirror of a parsed [DocumentDraft],
/// exposes reconciliation + confidence signals, and maps the reviewed result to
/// persistable entities via [DraftMapper]. Pure enough to unit-test without a
/// widget tree or database.
class ScanReviewController extends ChangeNotifier {
  ScanReviewController(DocumentDraft draft)
      : _source = draft,
        docType = draft.type,
        merchant = draft.merchant ?? '',
        date = draft.date,
        total = draft.total,
        currencyCode = draft.currencyCode ?? '',
        lines = [
          for (final l in draft.lineItems)
            EditableLine(
              description: l.description,
              amount: l.lineAmount,
              categoryId: l.categoryId,
              confidence: l.confidence,
              categoryConfidence: l.categoryConfidence,
            ),
        ];

  /// Fields scoring below this are flagged low-confidence (FR-SCAN-11).
  static const lowConfidence = 0.75;

  /// Reconciliation tolerance (matches [DocumentDraft]).
  static final Decimal _tolerance = Decimal.parse('0.05');

  final DocumentDraft _source;

  DocType docType;
  String merchant;
  DateTime? date;
  Decimal? total;
  String currencyCode;
  final List<EditableLine> lines;

  // --- mutations (called by the form widgets) ----------------------------

  void setDocType(DocType v) => _set(() => docType = v);
  void setMerchant(String v) => _set(() => merchant = v);
  void setDate(DateTime? v) => _set(() => date = v);
  void setTotal(Decimal? v) => _set(() => total = v);
  void setCurrency(String v) => _set(() => currencyCode = v);

  void setLineDescription(int i, String v) =>
      _set(() => lines[i].description = v);
  void setLineAmount(int i, Decimal v) => _set(() => lines[i].amount = v);
  void setLineCategory(int i, String categoryId) => _set(() {
        lines[i].categoryId = categoryId;
        lines[i].categoryConfidence = 1.0; // user-chosen = certain
      });

  void addLine() => _set(
        () => lines.add(EditableLine(description: '', amount: Decimal.zero)),
      );

  void removeLine(int i) => _set(() => lines.removeAt(i));

  // --- derived signals ---------------------------------------------------

  /// Σ of the current line amounts.
  Decimal get lineSum => lines.fold(Decimal.zero, (s, l) => s + l.amount);

  /// True when there are line items and they sum to the entered total.
  bool get isReconciled {
    final t = total;
    if (t == null || lines.isEmpty) return false;
    return (t - lineSum).abs() <= _tolerance;
  }

  /// total − Σ lines (null when there is no total).
  Decimal? get reconciliationDelta => total == null ? null : total! - lineSum;

  /// Confidence for a header field key ('merchant'/'date'/'total'/'currency').
  double? fieldConfidence(String key) => _source.fieldConfidence[key];

  bool isFieldLow(String key) {
    final c = fieldConfidence(key);
    return c != null && c < lowConfidence;
  }

  /// The reviewed draft rebuilt from the editable state.
  DocumentDraft get reviewedDraft => _source.copyWith(
        type: docType,
        merchant: merchant.trim().isEmpty ? null : merchant.trim(),
        date: date,
        total: total,
        currencyCode: currencyCode.isEmpty ? null : currencyCode,
        lineItems: [
          for (final l in lines)
            LineItemDraft(
              description: l.description,
              lineAmount: l.amount,
              categoryId: l.categoryId,
              categoryConfidence: l.categoryConfidence,
              confidence: l.confidence,
            ),
        ],
      );

  /// Map the reviewed draft to a persistable header + lines (docs/05 §8).
  DraftMapping buildMapping(DraftMappingContext ctx) =>
      const DraftMapper().map(reviewedDraft, ctx);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}
