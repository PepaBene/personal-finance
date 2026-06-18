/// CSV import/export (FR-DAT-04/05). Works on CSV *strings* so the core logic is
/// pure and unit-testable; the UI handles file I/O.

/// Outcome of an import run.
class ImportReport {
  const ImportReport({
    required this.imported,
    required this.skipped,
    required this.errors,
  });

  final int imported; // transactions created/updated
  final int skipped; // rows that could not be parsed
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

abstract interface class ImportExportService {
  /// All active transactions and their line items as a CSV string (line-level
  /// rows, with a `transaction_id` column so splits regroup on re-import).
  Future<String> exportCsv();

  /// Parse [csv] and upsert transactions. Rows sharing a `transaction_id` are
  /// grouped into one transaction (its line items); rows without one become a
  /// single-line transaction. Categories/accounts are matched by name and
  /// created if missing.
  Future<ImportReport> importCsv(String csv);
}
