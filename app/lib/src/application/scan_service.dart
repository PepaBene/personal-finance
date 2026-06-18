import '../domain/scan/document_draft.dart';
import 'ocr_engine.dart';

/// Stage/percentage progress for the scanning UI (docs/05 §3).
class ScanProgress {
  const ScanProgress(this.stage, this.fraction);
  final String stage;
  final double fraction; // 0..1
}

/// Input to a scan: a (preprocessed) image plus its provenance. Ingest of
/// files/camera/PDF lands in a later increment.
class ScanInput {
  const ScanInput(this.image, {this.source = ScanSource.imageFile});
  final OcrImage image;
  final ScanSource source;
}

/// Orchestrates ingest → preprocess → OCR → classify → parse → suggest,
/// returning a non-persisted [DocumentDraft] for the review screen (docs/05 §3).
abstract interface class ScanService {
  Future<DocumentDraft> scan(ScanInput input, {CancellationToken? token});
  Stream<ScanProgress> get progress;
}
