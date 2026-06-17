using System.Globalization;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Analytics;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Analytics;

/// <inheritdoc />
public sealed class AnalyticsService : IAnalyticsService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;
    private readonly ICurrencyService _currency;

    public AnalyticsService(IDbContextFactory<LedgerlyDbContext> contextFactory, ICurrencyService currency)
    {
        _contextFactory = contextFactory;
        _currency = currency;
    }

    public async Task<TotalsDto> GetTotalsAsync(AnalyticsFilter filter, CancellationToken cancellationToken = default)
    {
        var (baseCode, _, transactions) = await LoadAsync(filter, cancellationToken).ConfigureAwait(false);

        decimal income = 0m;
        decimal expense = 0m;
        foreach (var t in transactions)
        {
            if (t.Type == TransactionType.Income)
            {
                income += t.BaseAmount;
            }
            else if (t.Type == TransactionType.Expense)
            {
                expense += t.BaseAmount;
            }
        }

        return new TotalsDto(income, expense, income - expense, baseCode);
    }

    public async Task<IReadOnlyList<CategorySpendDto>> GetSpendByCategoryAsync(
        AnalyticsFilter filter,
        CancellationToken cancellationToken = default)
    {
        var (_, digits, transactions) = await LoadAsync(filter, cancellationToken).ConfigureAwait(false);
        var categoryFilter = ToSet(filter.CategoryIds);

        var byCategory = new Dictionary<Guid, decimal>();
        foreach (var t in transactions.Where(t => t.Type == TransactionType.Expense))
        {
            foreach (var line in t.LineItems)
            {
                if (categoryFilter is not null && !categoryFilter.Contains(line.CategoryId))
                {
                    continue;
                }

                var baseShare = Round(line.LineAmount * t.ExchangeRate, digits);
                byCategory[line.CategoryId] = byCategory.GetValueOrDefault(line.CategoryId) + baseShare;
            }
        }

        var total = byCategory.Values.Sum();
        var names = await LoadCategoryNamesAsync(byCategory.Keys, cancellationToken).ConfigureAwait(false);

        return byCategory
            .Select(kvp => new CategorySpendDto(
                kvp.Key,
                names.GetValueOrDefault(kvp.Key, "(unknown)"),
                kvp.Value,
                total == 0m ? 0m : kvp.Value / total))
            .OrderByDescending(c => c.Amount)
            .ToList();
    }

    public async Task<IReadOnlyList<PeriodTotalsDto>> GetOverTimeAsync(
        AnalyticsFilter filter,
        PeriodGrain grain,
        CancellationToken cancellationToken = default)
    {
        var (_, _, transactions) = await LoadAsync(filter, cancellationToken).ConfigureAwait(false);

        var buckets = new Dictionary<DateOnly, (decimal Income, decimal Expense)>();
        foreach (var t in transactions)
        {
            if (t.Type == TransactionType.Transfer)
            {
                continue;
            }

            var start = PeriodStart(t.Date, grain);
            var current = buckets.GetValueOrDefault(start);
            if (t.Type == TransactionType.Income)
            {
                current.Income += t.BaseAmount;
            }
            else
            {
                current.Expense += t.BaseAmount;
            }

            buckets[start] = current;
        }

        return buckets
            .OrderBy(b => b.Key)
            .Select(b => new PeriodTotalsDto(b.Key, Label(b.Key, grain), b.Value.Income, b.Value.Expense))
            .ToList();
    }

    private async Task<(string BaseCode, int Digits, List<Transaction> Transactions)> LoadAsync(
        AnalyticsFilter filter,
        CancellationToken cancellationToken)
    {
        var baseCode = await _currency.GetBaseCurrencyAsync(cancellationToken).ConfigureAwait(false);
        var digits = await _currency.GetDecimalDigitsAsync(baseCode, cancellationToken).ConfigureAwait(false);

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var query = db.Transactions.AsNoTracking()
            .Include(t => t.LineItems)
            .Where(t => t.Status == TransactionStatus.Active);

        if (filter.From is { } from)
        {
            query = query.Where(t => t.Date >= from);
        }

        if (filter.To is { } to)
        {
            query = query.Where(t => t.Date <= to);
        }

        var accountFilter = ToSet(filter.AccountIds);
        var transactions = await query.ToListAsync(cancellationToken).ConfigureAwait(false);

        if (accountFilter is not null)
        {
            transactions = transactions
                .Where(t => (t.AccountId is { } a && accountFilter.Contains(a))
                    || (t.CounterAccountId is { } c && accountFilter.Contains(c)))
                .ToList();
        }

        return (baseCode, digits, transactions);
    }

    private async Task<Dictionary<Guid, string>> LoadCategoryNamesAsync(
        IEnumerable<Guid> ids,
        CancellationToken cancellationToken)
    {
        var idList = ids.Distinct().ToList();
        if (idList.Count == 0)
        {
            return [];
        }

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        return await db.Categories.AsNoTracking()
            .Where(c => idList.Contains(c.Id))
            .ToDictionaryAsync(c => c.Id, c => c.Name, cancellationToken)
            .ConfigureAwait(false);
    }

    private static HashSet<Guid>? ToSet(IReadOnlyList<Guid>? ids) =>
        ids is { Count: > 0 } ? [.. ids] : null;

    private static decimal Round(decimal value, int digits) =>
        Math.Round(value, digits, MidpointRounding.ToEven);

    private static DateOnly PeriodStart(DateOnly date, PeriodGrain grain) => grain switch
    {
        PeriodGrain.Day => date,
        PeriodGrain.Week => date.AddDays(-(((int)date.DayOfWeek + 6) % 7)), // Monday
        PeriodGrain.Month => new DateOnly(date.Year, date.Month, 1),
        PeriodGrain.Quarter => new DateOnly(date.Year, (((date.Month - 1) / 3) * 3) + 1, 1),
        PeriodGrain.Year => new DateOnly(date.Year, 1, 1),
        _ => new DateOnly(date.Year, date.Month, 1),
    };

    private static string Label(DateOnly start, PeriodGrain grain) => grain switch
    {
        PeriodGrain.Day => start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
        PeriodGrain.Week => start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
        PeriodGrain.Month => start.ToString("yyyy-MM", CultureInfo.InvariantCulture),
        PeriodGrain.Quarter => $"{start.Year}-Q{((start.Month - 1) / 3) + 1}",
        PeriodGrain.Year => start.Year.ToString(CultureInfo.InvariantCulture),
        _ => start.ToString("yyyy-MM", CultureInfo.InvariantCulture),
    };
}
