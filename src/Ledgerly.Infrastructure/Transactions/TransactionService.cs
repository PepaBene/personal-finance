using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Ledgerly.Domain.Transactions;
using Ledgerly.Domain.ValueObjects;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Transactions;

/// <inheritdoc />
public sealed class TransactionService : ITransactionService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;
    private readonly ICurrencyService _currency;
    private readonly TimeProvider _timeProvider;

    public TransactionService(
        IDbContextFactory<LedgerlyDbContext> contextFactory,
        ICurrencyService currency,
        TimeProvider timeProvider)
    {
        _contextFactory = contextFactory;
        _currency = currency;
        _timeProvider = timeProvider;
    }

    public async Task<TransactionDto> CreateAsync(
        CreateTransactionRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        var currency = request.CurrencyCode.Trim().ToUpperInvariant();
        var baseCode = await _currency.GetBaseCurrencyAsync(cancellationToken).ConfigureAwait(false);
        var sameCurrency = string.Equals(currency, baseCode, StringComparison.Ordinal);

        // Record an explicitly-supplied rate, then convert through the FX engine so the
        // cached base amount uses one consistent rounding rule (ADR-005, docs/04 §3.3).
        if (request.ExchangeRate is { } explicitRate && explicitRate > 0m && !sameCurrency)
        {
            await _currency.UpsertRateAsync(currency, baseCode, explicitRate, request.Date, RateSource.Manual, cancellationToken)
                .ConfigureAwait(false);
        }

        var baseMoney = await _currency.ConvertToBaseAsync(new Money(request.TotalAmount, currency), request.Date, cancellationToken)
            .ConfigureAwait(false);
        var rate = sameCurrency
            ? 1m
            : await _currency.GetRateAsync(currency, baseCode, request.Date, cancellationToken).ConfigureAwait(false) ?? 1m;

        var lineItems = BuildLineItems(request);
        if (lineItems.Count > 0)
        {
            var digits = await _currency.GetDecimalDigitsAsync(currency, cancellationToken).ConfigureAwait(false);
            var tolerance = TransactionReconciler.ToleranceFor(digits);
            var lineAmounts = lineItems.Select(li => li.LineAmount).ToList();
            if (!TransactionReconciler.IsBalanced(request.TotalAmount, lineAmounts, tolerance))
            {
                throw new ReconciliationException(
                    request.TotalAmount,
                    TransactionReconciler.SumLineAmounts(lineAmounts),
                    currency);
            }
        }

        var now = _timeProvider.GetUtcNow();
        var entity = new Transaction
        {
            Type = request.Type,
            Date = request.Date,
            CurrencyCode = currency,
            TotalAmount = request.TotalAmount,
            ExchangeRate = rate,
            BaseAmount = baseMoney.Amount,
            Note = request.Note,
            Source = request.Source,
            Status = TransactionStatus.Active,
            CreatedAt = now,
            UpdatedAt = now,
        };
        entity.LineItems.AddRange(lineItems);

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
            .Include(t => t.LineItems)
            .Where(t => t.Status == TransactionStatus.Active)
            .OrderByDescending(t => t.Date)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        // SQLite can't ORDER BY a DateTimeOffset, so apply the CreatedAt tiebreaker
        // client-side after materializing (the Date ordering above uses the index).
        return entities
            .OrderByDescending(t => t.Date)
            .ThenByDescending(t => t.CreatedAt)
            .Select(Map)
            .ToList();
    }

    public async Task<TransactionDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var entity = await db.Transactions
            .AsNoTracking()
            .Include(t => t.LineItems)
            .FirstOrDefaultAsync(t => t.Id == id, cancellationToken)
            .ConfigureAwait(false);

        return entity is null ? null : Map(entity);
    }

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var entity = await db.Transactions
            .FirstOrDefaultAsync(t => t.Id == id, cancellationToken)
            .ConfigureAwait(false);
        if (entity is null)
        {
            return;
        }

        entity.Status = TransactionStatus.Deleted;
        entity.UpdatedAt = _timeProvider.GetUtcNow();
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    private static List<LineItem> BuildLineItems(CreateTransactionRequest request)
    {
        if (request.LineItems.Count > 0)
        {
            var order = 0;
            return request.LineItems
                .Select(li => new LineItem
                {
                    Description = li.Description,
                    Quantity = li.Quantity,
                    UnitPrice = li.UnitPrice,
                    LineAmount = li.LineAmount,
                    CategoryId = li.CategoryId,
                    TaxRate = li.TaxRate,
                    SortOrder = order++,
                })
                .ToList();
        }

        // No explicit lines: a single implicit line in the chosen category (FR-CAP-04).
        if (request.CategoryId is { } categoryId)
        {
            return
            [
                new LineItem
                {
                    Description = string.IsNullOrWhiteSpace(request.Note) ? "—" : request.Note!,
                    Quantity = 1m,
                    LineAmount = request.TotalAmount,
                    CategoryId = categoryId,
                    SortOrder = 0,
                },
            ];
        }

        return [];
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
        t.CreatedAt,
        t.LineItems
            .OrderBy(li => li.SortOrder)
            .Select(li => new LineItemDto(li.Id, li.Description, li.Quantity, li.UnitPrice, li.LineAmount, li.CategoryId, li.SortOrder))
            .ToList());
}
