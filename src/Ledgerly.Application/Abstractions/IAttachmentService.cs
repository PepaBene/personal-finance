using Ledgerly.Application.Documents;

namespace Ledgerly.Application.Abstractions;

/// <summary>Stores attachments (encrypted) with metadata and full-text OCR search (FR-SCAN-08).</summary>
public interface IAttachmentService
{
    Task<AttachmentDto> AddAsync(AddAttachmentRequest request, CancellationToken cancellationToken = default);

    Task<byte[]> GetContentAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Full-text search over stored OCR text (docs/11 §3.3).</summary>
    Task<IReadOnlyList<AttachmentDto>> SearchByTextAsync(string query, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AttachmentDto>> GetForTransactionAsync(Guid transactionId, CancellationToken cancellationToken = default);
}
