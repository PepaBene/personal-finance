import 'package:decimal/decimal.dart';

import '../../../application/document_parser.dart';
import '../../../domain/scan/document_draft.dart';
import '../../../domain/scan/ocr_result.dart';

/// Expected ground-truth for one labelled document (docs/05 §7). Only the fields
/// that are present are scored, so partial labels are fine.
class ExpectedDocument {
  const ExpectedDocument({
    this.merchant,
    this.date,
    this.total,
    this.currencyCode,
    this.lines = const [],
  });

  final String? merchant;
  final DateTime? date;
  final Decimal? total;
  final String? currencyCode;
  final List<ExpectedLine> lines;
}

class ExpectedLine {
  const ExpectedLine(this.description, this.amount);
  final String description;
  final Decimal amount;
}

/// One labelled fixture: a serialized [OcrResult] plus its ground truth.
class AccuracyCase {
  const AccuracyCase(this.name, this.ocr, this.expected);
  final String name;
  final OcrResult ocr;
  final ExpectedDocument expected;
}

/// Per-document score. Header fields are scored only when an expected value
/// exists; line items are scored as precision/recall (docs/05 §1).
class CaseScore {
  const CaseScore({
    required this.merchant,
    required this.date,
    required this.total,
    required this.currency,
    required this.linesMatched,
    required this.linesPredicted,
    required this.linesExpected,
  });

  /// Header fields: true = correct, false = wrong, null = not labelled.
  final bool? merchant;
  final bool? date;
  final bool? total;
  final bool? currency;

  final int linesMatched;
  final int linesPredicted;
  final int linesExpected;
}

/// Aggregate accuracy across a corpus, comparable to the targets in docs/05 §1
/// (total/date ≥ 0.90, merchant ≥ 0.85, line-item recall ≥ 0.70).
class AccuracyReport {
  const AccuracyReport({
    required this.merchantAccuracy,
    required this.dateAccuracy,
    required this.totalAccuracy,
    required this.currencyAccuracy,
    required this.lineItemPrecision,
    required this.lineItemRecall,
    required this.cases,
  });

  final double merchantAccuracy;
  final double dateAccuracy;
  final double totalAccuracy;
  final double currencyAccuracy;
  final double lineItemPrecision;
  final double lineItemRecall;
  final int cases;

  @override
  String toString() => 'AccuracyReport(cases: $cases, '
      'merchant: ${_pct(merchantAccuracy)}, date: ${_pct(dateAccuracy)}, '
      'total: ${_pct(totalAccuracy)}, currency: ${_pct(currencyAccuracy)}, '
      'lineP: ${_pct(lineItemPrecision)}, lineR: ${_pct(lineItemRecall)})';

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

/// Scores parser output against labelled fixtures (docs/05 §7). Engine-agnostic:
/// it consumes serialized [OcrResult]s, so it measures *parser* accuracy
/// independent of which OCR engine produced the text.
class ScanAccuracy {
  const ScanAccuracy();

  CaseScore score(DocumentParser parser, AccuracyCase c, ParseContext ctx) {
    final draft = parser.parse(c.ocr, ctx);
    final e = c.expected;

    final lines = _lineOverlap(draft.lineItems, e.lines);
    return CaseScore(
      merchant: e.merchant == null ? null : _eqText(draft.merchant, e.merchant),
      date: e.date == null ? null : draft.date == e.date,
      total: e.total == null ? null : draft.total == e.total,
      currency:
          e.currencyCode == null ? null : draft.currencyCode == e.currencyCode,
      linesMatched: lines,
      linesPredicted: draft.lineItems.length,
      linesExpected: e.lines.length,
    );
  }

  AccuracyReport evaluate(
    DocumentParser parser,
    List<AccuracyCase> cases,
    ParseContext ctx,
  ) {
    final scores = [for (final c in cases) score(parser, c, ctx)];
    var matched = 0, predicted = 0, expected = 0;
    for (final s in scores) {
      matched += s.linesMatched;
      predicted += s.linesPredicted;
      expected += s.linesExpected;
    }
    return AccuracyReport(
      merchantAccuracy: _accuracy(scores, (s) => s.merchant),
      dateAccuracy: _accuracy(scores, (s) => s.date),
      totalAccuracy: _accuracy(scores, (s) => s.total),
      currencyAccuracy: _accuracy(scores, (s) => s.currency),
      lineItemPrecision: predicted == 0 ? 1 : matched / predicted,
      lineItemRecall: expected == 0 ? 1 : matched / expected,
      cases: cases.length,
    );
  }

  /// Count of predicted lines that match an expected line (description +
  /// amount), each expected line consumed at most once.
  int _lineOverlap(List<LineItemDraft> predicted, List<ExpectedLine> expected) {
    final remaining = [...expected];
    var matched = 0;
    for (final p in predicted) {
      final i = remaining.indexWhere(
        (e) =>
            _eqText(p.description, e.description) && p.lineAmount == e.amount,
      );
      if (i >= 0) {
        remaining.removeAt(i);
        matched++;
      }
    }
    return matched;
  }

  double _accuracy(List<CaseScore> scores, bool? Function(CaseScore) pick) {
    var ok = 0, total = 0;
    for (final s in scores) {
      final v = pick(s);
      if (v == null) continue; // unlabelled → not counted
      total++;
      if (v) ok++;
    }
    return total == 0 ? 1 : ok / total;
  }

  bool _eqText(String? a, String? b) =>
      (a ?? '').trim().toLowerCase() == (b ?? '').trim().toLowerCase();
}
