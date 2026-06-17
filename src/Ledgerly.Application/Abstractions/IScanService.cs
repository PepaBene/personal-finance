using Ledgerly.Application.Scanning;

namespace Ledgerly.Application.Abstractions;

/// <summary>
/// Orchestrates the scan pipeline stages 1–6 (docs/05 §2): ingest → OCR → classify →
/// parse → suggest categories → draft. The result is reviewed by the user before saving
/// (FR-SCAN-06) — never auto-saved.
/// </summary>
public interface IScanService
{
    Task<DocumentDraft> ScanAsync(ScanInput input, CancellationToken cancellationToken = default);
}
