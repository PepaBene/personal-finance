using Ledgerly.Domain.Common;

namespace Ledgerly.Domain.Entities;

/// <summary>
/// An original scanned/imported document, stored encrypted and linked to a transaction
/// (docs/04 §2.6, FR-SCAN-08). The full OCR text is kept for full-text search.
/// </summary>
public class Attachment
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Nullable until linked to a saved transaction.</summary>
    public Guid? TransactionId { get; set; }

    public AttachmentDocType DocType { get; set; } = AttachmentDocType.Other;

    public string FileName { get; set; } = default!;

    /// <summary>Path to the encrypted file, relative to the app data directory.</summary>
    public string StoragePath { get; set; } = default!;

    /// <summary>SHA-256 of the plaintext, for dedupe and integrity.</summary>
    public string Sha256 { get; set; } = default!;

    /// <summary>Full extracted text (searchable).</summary>
    public string? OcrText { get; set; }

    public ScanStatus ScanStatus { get; set; } = ScanStatus.Pending;

    public int PageCount { get; set; }

    public DateTimeOffset ImportedAt { get; set; }
}
