import 'dart:typed_data';

import '../domain/scan/document_draft.dart';

/// A document the user picked/captured, ready for the scan pipeline.
class IngestedDocument {
  const IngestedDocument({
    required this.bytes,
    required this.fileName,
    required this.source,
  });

  final Uint8List bytes;
  final String fileName;
  final ScanSource source;
}

/// Picks a document to scan (docs/05 §1 ingest, FR-SCAN-01). Returns null when
/// the user cancels. Implemented per platform; the file path works everywhere,
/// camera/gallery/PDF land as additional sources.
abstract interface class ScanIngest {
  /// Whether [source] can be offered on the current platform.
  bool supports(ScanSource source);

  Future<IngestedDocument?> pick(ScanSource source);
}
