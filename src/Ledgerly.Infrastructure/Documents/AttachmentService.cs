using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Documents;
using Ledgerly.Domain.Entities;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Documents;

/// <inheritdoc />
public sealed class AttachmentService : IAttachmentService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;
    private readonly IFileStore _fileStore;
    private readonly TimeProvider _timeProvider;

    public AttachmentService(
        IDbContextFactory<LedgerlyDbContext> contextFactory,
        IFileStore fileStore,
        TimeProvider timeProvider)
    {
        _contextFactory = contextFactory;
        _fileStore = fileStore;
        _timeProvider = timeProvider;
    }

    public async Task<AttachmentDto> AddAsync(AddAttachmentRequest request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        var stored = await _fileStore.SaveAsync(request.Data, cancellationToken).ConfigureAwait(false);

        var attachment = new Attachment
        {
            TransactionId = request.TransactionId,
            DocType = request.DocType,
            FileName = request.FileName,
            StoragePath = stored.StoragePath,
            Sha256 = stored.Sha256,
            OcrText = request.OcrText,
            ScanStatus = request.ScanStatus,
            PageCount = request.PageCount,
            ImportedAt = _timeProvider.GetUtcNow(),
        };

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        db.Attachments.Add(attachment);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Map(attachment);
    }

    public async Task<byte[]> GetContentAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var attachment = await db.Attachments.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken)
            .ConfigureAwait(false)
            ?? throw new ArgumentException($"Unknown attachment '{id}'.", nameof(id));

        return await _fileStore.ReadAsync(attachment.StoragePath, cancellationToken).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<AttachmentDto>> SearchByTextAsync(string query, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return [];
        }

        var pattern = "%" + query.Trim() + "%";

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var matches = await db.Attachments.AsNoTracking()
            .Where(a => a.OcrText != null && EF.Functions.Like(a.OcrText!, pattern))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        // SQLite can't ORDER BY a DateTimeOffset; sort client-side after materializing.
        return matches.OrderByDescending(a => a.ImportedAt).Select(Map).ToList();
    }

    public async Task<IReadOnlyList<AttachmentDto>> GetForTransactionAsync(Guid transactionId, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var matches = await db.Attachments.AsNoTracking()
            .Where(a => a.TransactionId == transactionId)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return matches.Select(Map).ToList();
    }

    private static AttachmentDto Map(Attachment a) => new(
        a.Id,
        a.TransactionId,
        a.DocType,
        a.FileName,
        a.Sha256,
        a.ScanStatus,
        a.PageCount,
        a.ImportedAt,
        !string.IsNullOrEmpty(a.OcrText));
}
