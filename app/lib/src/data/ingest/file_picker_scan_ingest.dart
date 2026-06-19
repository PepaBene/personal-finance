import 'package:file_picker/file_picker.dart';

import '../../application/scan_ingest.dart';
import '../../domain/scan/document_draft.dart';

/// [ScanIngest] backed by `file_picker` — works on web, desktop and mobile
/// (FR-SCAN-01). Loads the bytes in-memory (`withData`) so the pipeline can run
/// without a file path (required on web). Camera/gallery/PDF sources land later
/// via `image_picker`/`camera` and the PDF rasterizer.
class FilePickerScanIngest implements ScanIngest {
  const FilePickerScanIngest();

  @override
  bool supports(ScanSource source) => source == ScanSource.imageFile;

  @override
  Future<IngestedDocument?> pick(ScanSource source) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return IngestedDocument(
      bytes: bytes,
      fileName: file.name,
      source: ScanSource.imageFile,
    );
  }
}
