import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/document_parser.dart';
import 'package:ledgerly_app/src/data/documents/accuracy/scan_accuracy.dart';
import 'package:ledgerly_app/src/data/documents/receipt_parser.dart';
import 'package:ledgerly_app/src/domain/scan/ocr_result.dart';

OcrWord _w(String t, double x, double y) => OcrWord(
      text: t,
      box: OcrBox(
        left: x - 0.05,
        top: y - 0.015,
        right: x + 0.05,
        bottom: y + 0.015,
      ),
    );

OcrLine _row(String desc, double y, String price, [double px = 0.85]) =>
    OcrLine(
      text: '$desc $price',
      words: [_w(desc, 0.15, y), _w(price, px, y)],
    );

Decimal _d(String s) => Decimal.parse(s);

/// Two labelled CZK receipt fixtures (docs/05 §7 corpus, in miniature).
List<AccuracyCase> _corpus() => [
      AccuracyCase(
        'albert',
        OcrResult(
          engineId: 'fixture',
          fullText: 'ALBERT\nMleko 49,80\nChleba 34,90\nMaslo 149,40\n'
              'CELKEM 234,10\nDPH 15% 30,54\n08.06.2026 Kč',
          lines: [
            OcrLine(text: 'ALBERT', words: [_w('ALBERT', 0.2, 0.05)]),
            _row('Mleko', 0.20, '49,80'),
            _row('Chleba', 0.30, '34,90'),
            _row('Maslo', 0.40, '149,40'),
            _row('CELKEM', 0.55, '234,10'),
            _row('DPH', 0.62, '30,54'),
            OcrLine(
              text: '08.06.2026 Kč',
              words: [_w('08.06.2026', 0.2, 0.72), _w('Kč', 0.6, 0.72)],
            ),
          ],
        ),
        ExpectedDocument(
          merchant: 'ALBERT',
          date: DateTime.utc(2026, 6, 8),
          total: _d('234.10'),
          currencyCode: 'CZK',
          lines: [
            ExpectedLine('Mleko', _d('49.80')),
            ExpectedLine('Chleba', _d('34.90')),
            ExpectedLine('Maslo', _d('149.40')),
          ],
        ),
      ),
      AccuracyCase(
        'tesco',
        OcrResult(
          engineId: 'fixture',
          fullText: 'TESCO\nRohlik 5,90\nSyr 89,90\n'
              'CELKEM 95,80\n11.06.2026 Kč',
          lines: [
            OcrLine(text: 'TESCO', words: [_w('TESCO', 0.2, 0.05)]),
            _row('Rohlik', 0.22, '5,90'),
            _row('Syr', 0.32, '89,90'),
            _row('CELKEM', 0.48, '95,80'),
            OcrLine(
              text: '11.06.2026 Kč',
              words: [_w('11.06.2026', 0.2, 0.66), _w('Kč', 0.6, 0.66)],
            ),
          ],
        ),
        ExpectedDocument(
          merchant: 'TESCO',
          date: DateTime.utc(2026, 6, 11),
          total: _d('95.80'),
          currencyCode: 'CZK',
          lines: [
            ExpectedLine('Rohlik', _d('5.90')),
            ExpectedLine('Syr', _d('89.90')),
          ],
        ),
      ),
    ];

void main() {
  const scorer = ScanAccuracy();
  const parser = ReceiptParser();
  const ctx = ParseContext(defaultCurrencyCode: 'EUR', locale: 'cs');

  test('receipt parser meets the docs/05 §1 accuracy targets on the corpus',
      () {
    final report = scorer.evaluate(parser, _corpus(), ctx);
    // Targets: total & date ≥ 0.90, merchant ≥ 0.85, line-item recall ≥ 0.70.
    expect(report.totalAccuracy, greaterThanOrEqualTo(0.90), reason: '$report');
    expect(report.dateAccuracy, greaterThanOrEqualTo(0.90), reason: '$report');
    expect(report.merchantAccuracy, greaterThanOrEqualTo(0.85),
        reason: '$report');
    expect(report.lineItemRecall, greaterThanOrEqualTo(0.70),
        reason: '$report');
  });

  test('scores a wrong field as a miss and counts line precision/recall', () {
    final corpus = [
      AccuracyCase(
        'partial',
        _corpus().first.ocr,
        ExpectedDocument(
          merchant: 'WRONG NAME', // parser will disagree → miss
          total: _d('234.10'), // correct → hit
          lines: const [],
        ),
      ),
    ];
    final report = scorer.evaluate(parser, corpus, ctx);
    expect(report.merchantAccuracy, 0.0);
    expect(report.totalAccuracy, 1.0);
    // No expected lines, but the parser predicts some → precision < 1, recall = 1.
    expect(report.lineItemPrecision, lessThan(1.0));
    expect(report.lineItemRecall, 1.0);
  });

  test('unlabelled fields do not drag down accuracy', () {
    final corpus = [
      AccuracyCase(
        'only-total',
        _corpus().first.ocr,
        ExpectedDocument(total: _d('234.10')),
      ),
    ];
    final report = scorer.evaluate(parser, corpus, ctx);
    expect(report.totalAccuracy, 1.0);
    expect(report.merchantAccuracy, 1.0); // nothing labelled → treated as 100%
  });
}
