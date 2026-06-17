using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Ledgerly.Domain.ValueObjects;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Transactions;

/// <inheritdoc />
public sealed class TransactionService : ITransactionService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;
    private readonly TimeProvider _timeProvider;

    public TransactionService(
        IDbContextFactory<LedgerlyDbContext> contextFactory,
        TimeProvider timeProvider)
    {
        _contextFactory = contextFactory;
        _timeProvider = timeProvider;
    }

    public async Task<TransactionDto> CreateAsync(
        CreateTransactionRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        var rate = request.ExchangeRate <= 0m ? 1m : request.ExchangeRate;

        // Compute the cached base amount through the Money value object so the
        // banker's-rounding rule is applied consistently (ADR-005, docs/04 §3.4).
        var original = new Money(request.TotalAmount, request.CurrencyCode);
        var baseAmount = (original * rate).Round(4).Amount;

        var now = _timeProvider.GetUtcNow();

        var entity = new Transaction
        {
            Type = request.Type,
            Date = request.Date,
            CurrencyCode = request.CurrencyCode.Trim().ToUpperInvariant(),
            TotalAmount = request.TotalAmount,
            ExchangeRate = rate,
            BaseAmount = baseAmount,
            Note = request.Note,
            Source = request.Source,
            Status = TransactionStatus.Active,
            CreatedAt = now,
            UpdatedAt = now,
        };

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        db.Transactions.Add(entity);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Map(entity);
    }

    public async Task<IReadOnlyList<TransactionDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var entities = await db.Transactions
            .AsNoTracking()
            .Where(t => t.Status == TransactionStatus.Active)
            .OrderByDescending(t => t.Date)
            .ThenByDescending(t => t.CreatedAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return entities.Select(Map).ToList();
    }

    public async Task<TransactionDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var entity = await db.Transactions
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == id, cancellationToken)
            .ConfigureAwait(false);

        return entity is null ? null : Map(entity);
    }

    private static TransactionDto Map(Transaction t) => new(
        t.Id,
        t.Type,
        t.Date,
        t.CurrencyCode,
        t.TotalAmount,
        t.BaseAmount,
        t.ExchangeRate,
        t.Note,
        t.Source,
        t.CreatedAt);
}
