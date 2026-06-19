import 'dart:async';

import '../../application/categorization_service.dart';
import '../../application/document_parser.dart';
import '../../application/ocr_engine.dart';
import '../../application/scan_service.dart';
import '../../domain/enums.dart';
import '../../domain/scan/document_draft.dart';

/// Default orchestrator (docs/05 §2/§3): OCR → classify → parse → suggest → draft.
/// Ingest and preprocessing land in a later increment; this consumes an
/// already-loaded [OcrImage]. The parser is chosen by the classifier and the
/// optional [DraftCategorizer] runs stage 6 — both are fully swappable.
class DefaultScanService implements ScanService {
  DefaultScanService({
    required OcrEngine engine,
    required DocumentClassifier classifier,
    required Map<DocType, DocumentParser> parsers,
    required ParseContext Function() contextBuilder,
    DraftCategorizer? categorizer,
  })  : _engine = engine,
        _classifier = classifier,
        _parsers = parsers,
        _contextBuilder = contextBuilder,
        _categorizer = categorizer;

  final OcrEngine _engine;
  final DocumentClassifier _classifier;
  final Map<DocType, DocumentParser> _parsers;
  final ParseContext Function() _contextBuilder;
  final DraftCategorizer? _categorizer;
  final _progress = StreamController<ScanProgress>.broadcast();

  @override
  Stream<ScanProgress> get progress => _progress.stream;

  @override
  Future<DocumentDraft> scan(ScanInput input,
      {CancellationToken? token}) async {
    _emit('ocr', 0.3);
    final ocr = await _engine.recognize(input.image, token: token);

    _emit('classify', 0.6);
    final classification = _classifier.classify(ocr);

    _emit('parse', 0.8);
    final parser = _parsers[classification.type] ?? _parsers[DocType.receipt]!;
    var draft = parser.parse(ocr, _contextBuilder()).copyWith(
          type: classification.type,
          typeConfidence: classification.confidence,
          source: input.source,
        );

    final categorizer = _categorizer;
    if (categorizer != null) {
      _emit('suggest', 0.92);
      draft = categorizer.categorize(draft);
    }

    _emit('done', 1.0);
    return draft;
  }

  void _emit(String stage, double fraction) {
    if (!_progress.isClosed) _progress.add(ScanProgress(stage, fraction));
  }

  void dispose() => _progress.close();
}
