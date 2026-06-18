import '../../application/document_parser.dart';
import '../../domain/enums.dart';
import '../../domain/scan/ocr_result.dart';

/// Lightweight keyword classifier (docs/05 §4), CS + EN. Receipts are the common
/// case, so they're the default when nothing else scores higher.
class KeywordDocumentClassifier implements DocumentClassifier {
  const KeywordDocumentClassifier();

  static const _invoice = [
    'invoice',
    'faktura',
    'daňový doklad',
    'danovy doklad',
    'dič',
    'dic',
    'ičo',
    'ico',
    'due date',
    'splatnost',
    'variabilní symbol',
    'variabilni symbol',
  ];
  static const _paycheck = [
    'payslip',
    'payroll',
    'net pay',
    'gross pay',
    'salary',
    'mzda',
    'výplata',
    'vyplata',
    'výplatní',
    'vyplatni',
    'čistá mzda',
  ];
  static const _receipt = [
    'receipt',
    'účtenka',
    'uctenka',
    'pokladní',
    'pokladni',
    'celkem',
    'suma',
    'total',
    'děkujeme',
    'dekujeme',
    'thank you',
  ];

  @override
  DocumentClassification classify(OcrResult ocr) {
    final text = ocr.fullText.toLowerCase();
    final scores = {
      DocType.invoice: _score(text, _invoice),
      DocType.paycheck: _score(text, _paycheck),
      DocType.receipt: _score(text, _receipt),
    };
    final total = scores.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return const DocumentClassification(DocType.receipt, 0.3);
    }
    // Highest score wins; ties favour the more specific document types.
    var best = DocType.receipt;
    var bestScore = -1;
    for (final type in [DocType.invoice, DocType.paycheck, DocType.receipt]) {
      if (scores[type]! > bestScore) {
        bestScore = scores[type]!;
        best = type;
      }
    }
    final confidence = (0.4 + 0.6 * bestScore / total).clamp(0.0, 1.0);
    return DocumentClassification(best, confidence);
  }

  int _score(String text, List<String> keywords) {
    var n = 0;
    for (final k in keywords) {
      if (text.contains(k)) n++;
    }
    return n;
  }
}
