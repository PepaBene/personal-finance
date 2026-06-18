import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/document_parser.dart';
import 'package:ledgerly_app/src/data/documents/receipt_parser.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/scan/ocr_result.dart';

/// A word centered at ([x],[y]) in normalized coords.
OcrWord _w(String t, double x, double y, [double conf = 0.95]) => OcrWord(
      text: t,
      box: OcrBox(
          left: x - 0.05, top: y - 0.015, right: x + 0.05, bottom: y + 0.015),
      confidence: conf,
    );

OcrLine _line(String text, List<OcrWord> words) =>
    OcrLine(text: text, words: words);

void main() {
  // A simple CZK supermarket receipt (docs/04 §9 shape):
  //   ALBERT
  //   Mleko        49,80
  //   Chleba       34,90
  //   Maslo       149,40
  //   CELKEM      234,10
  //   DPH 15%      30,54
  //   08.06.2026   Kč
  final ocr = OcrResult(
    engineId: 'fixture',
    fullText: 'ALBERT\n'
        'Mleko 49,80\n'
        'Chleba 34,90\n'
        'Maslo 149,40\n'
        'CELKEM 234,10\n'
        'DPH 15% 30,54\n'
        '08.06.2026 Kč',
    lines: [
      _line('ALBERT', [_w('ALBERT', 0.20, 0.05)]),
      _line('Mleko 49,80', [_w('Mleko', 0.15, 0.20), _w('49,80', 0.85, 0.20)]),
      _line(
          'Chleba 34,90', [_w('Chleba', 0.15, 0.30), _w('34,90', 0.85, 0.30)]),
      _line(
          'Maslo 149,40', [_w('Maslo', 0.15, 0.40), _w('149,40', 0.85, 0.40)]),
      _line('CELKEM 234,10',
          [_w('CELKEM', 0.15, 0.55), _w('234,10', 0.85, 0.55)]),
      _line('DPH 15% 30,54', [
        _w('DPH', 0.15, 0.62),
        _w('15%', 0.40, 0.62),
        _w('30,54', 0.85, 0.62),
      ]),
      _line(
          '08.06.2026 Kč', [_w('08.06.2026', 0.20, 0.72), _w('Kč', 0.6, 0.72)]),
    ],
  );

  const parser = ReceiptParser();
  const ctx = ParseContext(defaultCurrencyCode: 'EUR', locale: 'cs');

  test('extracts header fields', () {
    final d = parser.parse(ocr, ctx);
    expect(d.type, DocType.receipt);
    expect(d.merchant, 'ALBERT');
    expect(d.date, DateTime.utc(2026, 6, 8));
    expect(d.currencyCode, 'CZK');
    expect(d.total, Decimal.parse('234.10'));
    expect(d.taxAmount, Decimal.parse('30.54'));
  });

  test('reconstructs multi-line items and excludes total/tax rows', () {
    final d = parser.parse(ocr, ctx);
    expect(d.lineItems.map((l) => l.description), ['Mleko', 'Chleba', 'Maslo']);
    expect(
      d.lineItems.map((l) => l.lineAmount),
      [Decimal.parse('49.80'), Decimal.parse('34.90'), Decimal.parse('149.40')],
    );
  });

  test('reconciles line items against the detected total', () {
    final d = parser.parse(ocr, ctx);
    expect(d.lineSum, Decimal.parse('234.10'));
    expect(d.isReconciled, isTrue);
  });

  test('falls back to default currency when none is present', () {
    final noCurrency = ocr.copyWith(fullText: 'ALBERT\nCELKEM 234,10');
    final d = parser.parse(noCurrency, ctx);
    expect(d.currencyCode, 'EUR');
  });
}
