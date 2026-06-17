namespace Ledgerly.Application.Abstractions;

/// <summary>CSV export/import of transactions (FR-DAT-04/05).</summary>
public interface IImportExportService
{
    /// <summary>Exports active transactions as CSV (one row per transaction header).</summary>
    Task<string> ExportTransactionsCsvAsync(CancellationToken cancellationToken = default);

    /// <summary>Imports transactions from CSV in the export format; returns the count created.</summary>
    Task<int> ImportTransactionsCsvAsync(string csv, CancellationToken cancellationToken = default);
}
