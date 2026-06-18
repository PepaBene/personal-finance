import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';
import 'ocr_result.dart';

part 'document_draft.freezed.dart';

/// Where a scanned document came from (docs/05 §1 ingest).
enum ScanSource { imageFile, gallery, camera, scanner, pdf }

/// A draft line item extracted from a document (docs/05 §3). Amounts are
/// `Decimal`; category is suggested later (stage 6) or set on review.
@freezed
abstract class LineItemDraft with _$LineItemDraft {
  const factory LineItemDraft({
    required String description,
    required Decimal lineAmount,
    Decimal? quantity,
    Decimal? unitPrice,
    String? categoryId,
    double? categoryConfidence,
    @Default(1.0) double confidence,
  }) = _LineItemDraft;
}

/// Non-persisted draft the review screen binds to (docs/05 §3). On confirm it
/// maps to Transaction + LineItems + Attachment. Money is `Decimal` (ADR-005).
@freezed
abstract class DocumentDraft with _$DocumentDraft {
  const factory DocumentDraft({
    required DocType type,
    @Default(0.0) double typeConfidence,
    String? merchant,
    DateTime? date,
    Decimal? total,
    String? currencyCode,
    Decimal? taxAmount,
    @Default(<LineItemDraft>[]) List<LineItemDraft> lineItems,
    @Default(<String, double>{}) Map<String, double> fieldConfidence,
    OcrResult? ocr,
    @Default(ScanSource.imageFile) ScanSource source,
  }) = _DocumentDraft;
  const DocumentDraft._();

  /// Tolerance for reconciliation (one minor unit-ish), matches the domain rule.
  static final Decimal _tolerance = Decimal.parse('0.05');

  Decimal get lineSum =>
      lineItems.fold(Decimal.zero, (s, l) => s + l.lineAmount);

  /// True when line items sum to the detected total (docs/05 §5 reconciliation).
  bool get isReconciled {
    final t = total;
    if (t == null || lineItems.isEmpty) return false;
    return (t - lineSum).abs() <= _tolerance;
  }
}
