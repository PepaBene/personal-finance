import '../domain/enums.dart';
import '../domain/scan/document_draft.dart';
import '../domain/scan/ocr_result.dart';

/// Context passed to a parser (locale + default currency for the user).
class ParseContext {
  const ParseContext({required this.defaultCurrencyCode, this.locale = 'en'});
  final String defaultCurrencyCode;
  final String locale;
}

/// Per-document-type parser (docs/05 §5). Pure Dart and engine-agnostic: it
/// consumes an [OcrResult] and emits a [DocumentDraft], so it is unit-tested
/// against serialized OCR fixtures with no image/engine (docs/05 §7).
abstract interface class DocumentParser {
  DocType get type;
  DocumentDraft parse(OcrResult ocr, ParseContext ctx);
}

/// Result of classifying a document by type (docs/05 §4).
class DocumentClassification {
  const DocumentClassification(this.type, this.confidence);
  final DocType type;
  final double confidence;
}

/// Lightweight keyword/rule classifier picking a parser (docs/05 §4).
abstract interface class DocumentClassifier {
  DocumentClassification classify(OcrResult ocr);
}
