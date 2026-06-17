using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Documents;

/// <summary>Read model for an attachment (no bytes; content is fetched on demand).</summary>
public sealed record AttachmentDto(
    Guid Id,
    Guid? TransactionId,
    AttachmentDocType DocType,
    string FileName,
    string Sha256,
    ScanStatus ScanStatus,
    int PageCount,
    DateTimeOffset ImportedAt,
    bool HasOcrText);

/// <summary>Input for storing an attachment (FR-SCAN-08).</summary>
public sealed record AddAttachmentRequest
{
    public required byte[] Data { get; init; }

    public required string FileName { get; init; }

    public AttachmentDocType DocType { get; init; } = AttachmentDocType.Other;

    public string? OcrText { get; init; }

    public ScanStatus ScanStatus { get; init; } = ScanStatus.Pending;

    public int PageCount { get; init; } = 1;

    public Guid? TransactionId { get; init; }
}
