import 'dart:typed_data';

import '../domain/enums.dart';
import '../domain/scan/document_draft.dart';
import 'ocr_engine.dart';
import 'scan_ingest.dart';
import 'scan_service.dart';

/// Outcome of a capture: the draft to review plus the original image bytes (for
/// the overlay + the encrypted attachment). [usedOcr] is false when no engine
/// was available and the user starts from a blank draft (docs/05 §6).
class ScanResult {
  const ScanResult({
    required this.draft,
    required this.imageBytes,
    required this.usedOcr,
  });

  final DocumentDraft draft;
  final Uint8List imageBytes;
  final bool usedOcr;
}

/// Drives capture (docs/05 §2): ingest → (OCR pipeline when an engine exists,
/// else a blank draft) → a [ScanResult] the review screen binds to. Cancelling
/// the picker yields null. Engine/parse failures degrade gracefully to manual
/// entry so the user is never blocked (docs/05 §6).
class ScanCoordinator {
  ScanCoordinator({required ScanIngest ingest, ScanService? scanService})
      : _ingest = ingest,
        _scanService = scanService;

  final ScanIngest _ingest;
  final ScanService? _scanService;

  /// True when a real OCR pipeline is wired (vs. manual-entry fallback).
  bool get hasOcr => _scanService != null;

  Future<ScanResult?> capture(
    ScanSource source, {
    CancellationToken? token,
  }) async {
    final doc = await _ingest.pick(source);
    if (doc == null) return null; // user cancelled

    final service = _scanService;
    if (service != null) {
      try {
        final draft = await service.scan(
          ScanInput(OcrImage(doc.bytes), source: source),
          token: token,
        );
        return ScanResult(draft: draft, imageBytes: doc.bytes, usedOcr: true);
      } on Object {
        // OCR/parse failed — fall through to manual entry (docs/05 §6).
      }
    }

    return ScanResult(
      draft: DocumentDraft(type: DocType.receipt, source: source),
      imageBytes: doc.bytes,
      usedOcr: false,
    );
  }
}
