import 'package:decimal/decimal.dart';

import '../../application/document_parser.dart';
import '../../domain/enums.dart';
import '../../domain/scan/document_draft.dart';
import '../../domain/scan/ocr_result.dart';
import 'parsing/date_parsing.dart';
import 'parsing/money_parsing.dart';

/// Receipt parser (docs/05 §5): reconstructs rows from OCR word geometry, finds
/// the right-aligned price column, and extracts merchant/date/total/tax + line
/// items. Pure Dart and engine-agnostic — unit-tested against OCR fixtures.
class ReceiptParser implements DocumentParser {
  const ReceiptParser();

  @override
  DocType get type => DocType.receipt;

  static const _totalKw = [
    'celkem',
    'suma',
    'total',
    'k úhradě',
    'k uhrade',
    'úhrada',
    'uhrada',
    'to pay',
    'amount due',
  ];
  static const _taxKw = ['dph', 'vat', 'tax', 'daň', 'dan'];
  static const _subtotalKw = [
    'mezisoučet',
    'mezisoucet',
    'subtotal',
    'souhrn',
    'celkem bez',
  ];

  @override
  DocumentDraft parse(OcrResult ocr, ParseContext ctx) {
    final rows = _buildRows(ocr);
    final field = <String, double>{};

    final merchant = _merchant(rows);
    if (merchant != null) field['merchant'] = 0.8;

    final date = DateParsing.findDate(ocr.fullText);
    if (date != null) field['date'] = 0.9;

    final currency = _currency(ocr.fullText, ctx.defaultCurrencyCode);
    field['currency'] = currency == ctx.defaultCurrencyCode ? 0.5 : 0.9;

    Decimal? total;
    Decimal? tax;
    final lineItems = <LineItemDraft>[];

    for (final row in rows) {
      final amount = _rowAmount(row);
      if (amount == null) continue;
      final lower = row.text.toLowerCase();

      if (_containsAny(lower, _taxKw)) {
        tax = amount;
        continue;
      }
      if (_containsAny(lower, _subtotalKw)) {
        continue; // ignore subtotals
      }
      if (_containsAny(lower, _totalKw)) {
        total = amount; // last total keyword wins
        continue;
      }

      final desc = _description(row);
      if (desc.isEmpty) continue;
      lineItems.add(LineItemDraft(
        description: desc,
        lineAmount: amount,
        confidence: row.confidence,
      ));
    }

    // Fallbacks for the total (docs/05 §6: never fabricate, prefer evidence).
    if (total != null) {
      field['total'] = 0.9;
    } else if (lineItems.isNotEmpty) {
      total = lineItems.fold<Decimal>(Decimal.zero, (s, l) => s + l.lineAmount);
      field['total'] = 0.5;
    }

    return DocumentDraft(
      type: DocType.receipt,
      typeConfidence: 0.8,
      merchant: merchant,
      date: date,
      total: total,
      taxAmount: tax,
      currencyCode: currency,
      lineItems: lineItems,
      fieldConfidence: field,
      ocr: ocr,
    );
  }

  // --- row reconstruction ------------------------------------------------

  List<_Row> _buildRows(OcrResult ocr) {
    final words = ocr.allWords.toList();
    if (words.isEmpty) {
      // No geometry: fall back to text lines.
      final lines = ocr.lines.isNotEmpty
          ? ocr.lines.map((l) => l.text).toList()
          : ocr.fullText.split('\n');
      return [
        for (final t in lines)
          if (t.trim().isNotEmpty) _Row(t.trim(), const [], 1, 0),
      ];
    }
    words.sort((a, b) => a.box.centerY.compareTo(b.box.centerY));
    const threshold = 0.02;
    final rows = <_Row>[];
    var current = <OcrWord>[];
    var rowY = words.first.box.centerY;
    for (final w in words) {
      if (current.isEmpty || (w.box.centerY - rowY).abs() <= threshold) {
        current.add(w);
        rowY = current.map((e) => e.box.centerY).reduce((a, b) => a + b) /
            current.length;
      } else {
        rows.add(_row(current));
        current = [w];
        rowY = w.box.centerY;
      }
    }
    if (current.isNotEmpty) rows.add(_row(current));
    return rows;
  }

  _Row _row(List<OcrWord> words) {
    final sorted = [...words]
      ..sort((a, b) => a.box.centerX.compareTo(b.box.centerX));
    final text = sorted.map((w) => w.text).join(' ');
    final conf =
        sorted.map((w) => w.confidence).reduce((a, b) => a + b) / sorted.length;
    return _Row(text, sorted, conf, sorted.first.box.top);
  }

  /// Right-most price-looking token in the row = the amount.
  Decimal? _rowAmount(_Row row) {
    if (row.words.isEmpty) {
      // Text-only row: take the last price token in the text.
      final matches = MoneyParsing.priceToken.allMatches(row.text).toList();
      if (matches.isEmpty) return null;
      return MoneyParsing.parseAmount(matches.last.group(0)!);
    }
    for (final w in row.words.reversed) {
      if (MoneyParsing.priceToken.hasMatch(w.text)) {
        return MoneyParsing.parseAmount(w.text);
      }
    }
    return null;
  }

  /// Description = everything left of the price column.
  String _description(_Row row) {
    if (row.words.isEmpty) {
      return row.text.replaceAll(MoneyParsing.priceToken, '').trim();
    }
    final parts = <String>[];
    for (final w in row.words) {
      if (MoneyParsing.priceToken.hasMatch(w.text)) break;
      parts.add(w.text);
    }
    return parts.join(' ').trim();
  }

  String? _merchant(List<_Row> rows) {
    for (final row in rows) {
      final t = row.text.trim();
      // Skip rows that are mostly numeric or a date.
      if (t.length < 2) continue;
      final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ž]'), '').length;
      if (letters >= 2 && DateParsing.findDate(t) == null) return t;
    }
    return null;
  }

  String _currency(String text, String fallback) {
    final t = text.toLowerCase();
    if (t.contains('kč') || t.contains('czk')) return 'CZK';
    if (text.contains('€') || t.contains('eur')) return 'EUR';
    if (text.contains('£') || t.contains('gbp')) return 'GBP';
    if (text.contains(r'$') || t.contains('usd')) return 'USD';
    return fallback;
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);
}

class _Row {
  const _Row(this.text, this.words, this.confidence, this.top);
  final String text;
  final List<OcrWord> words;
  final double confidence;
  final double top;
}
