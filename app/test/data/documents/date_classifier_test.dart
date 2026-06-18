import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/data/documents/keyword_document_classifier.dart';
import 'package:ledgerly_app/src/data/documents/parsing/date_parsing.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/scan/ocr_result.dart';

void main() {
  group('DateParsing', () {
    test('parses DD.MM.YYYY, YYYY-MM-DD and D/M/YY', () {
      expect(
          DateParsing.findDate('Datum 08.06.2026'), DateTime.utc(2026, 6, 8));
      expect(
          DateParsing.findDate('2026-06-08 12:00'), DateTime.utc(2026, 6, 8));
      expect(DateParsing.findDate('on 8/6/26'), DateTime.utc(2026, 6, 8));
    });

    test('rejects impossible dates and missing dates', () {
      expect(DateParsing.findDate('31.02.2026'), isNull);
      expect(DateParsing.findDate('no date'), isNull);
    });
  });

  group('KeywordDocumentClassifier', () {
    const c = KeywordDocumentClassifier();
    OcrResult ocr(String text) => OcrResult(fullText: text);

    test('detects receipts (default)', () {
      expect(c.classify(ocr('ALBERT\nCELKEM 234,10\nDěkujeme')).type,
          DocType.receipt);
    });
    test('detects invoices', () {
      expect(c.classify(ocr('Faktura č. 2026-1\nDIČ CZ123\nSplatnost')).type,
          DocType.invoice);
    });
    test('detects paychecks', () {
      expect(c.classify(ocr('Výplatní páska\nČistá mzda\nnet pay')).type,
          DocType.paycheck);
    });
    test('unknown text defaults to receipt with low confidence', () {
      final r = c.classify(ocr('xxxxx'));
      expect(r.type, DocType.receipt);
      expect(r.confidence, lessThan(0.5));
    });
  });
}
