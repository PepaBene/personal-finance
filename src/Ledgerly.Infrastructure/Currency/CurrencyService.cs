using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Common;
using Ledgerly.Application.Currency;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Ledgerly.Domain.ValueObjects;
using Ledgerly.Infrastructure.Persistence;
using Ledgerly.Infrastructure.Persistence.Seeding;
using Microsoft.EntityFrameworkCore;

// NOTE: namespace is 'Fx' (not 'Currency') on purpose: a 'Currency' namespace under
// Ledgerly.Infrastructure would shadow the Currency entity type in sibling files.
namespace Ledgerly.Infrastructure.Fx;

/// <inheritdoc />
public sealed class CurrencyService : ICurrencyService
{
    private const int FallbackDecimalDigits = 2;

    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;
    private readonly ISettingsStore _settings;

    public CurrencyService(IDbContextFactory<LedgerlyDbContext> contextFactory, ISettingsStore settings)
    {
        _contextFactory = contextFactory;
        _settings = settings;
    }

    public async Task<string> GetBaseCurrencyAsync(CancellationToken cancellationToken = default)
    {
        var code = await _settings.GetAsync(SettingKeys.BaseCurrency, cancellationToken)
            .ConfigureAwait(false);
        return string.IsNullOrWhiteSpace(code) ? DatabaseSeeder.DefaultBaseCurrency : code;
    }

    public async Task<int> GetDecimalDigitsAsync(string code, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        return await GetDecimalDigitsAsync(db, Normalize(code), cancellationToken).ConfigureAwait(false);
    }

    public async Task SetBaseCurrencyAsync(string code, CancellationToken cancellationToken = default)
    {
        var normalized = Normalize(code);

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var exists = await db.Currencies.AsNoTracking()
            .AnyAsync(c => c.Code == normalized, cancellationToken)
            .ConfigureAwait(false);
        if (!exists)
        {
            throw new ArgumentException($"Unknown currency '{normalized}'.", nameof(code));
        }

        // NOTE: changing the base currency should trigger a background recompute of all
        // cached Transaction.BaseAmount values (docs/04 §3.3). That lands with the
        // transaction/line-item model in a later Phase 1 increment.
        await _settings.SetAsync(SettingKeys.BaseCurrency, normalized, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task UpsertRateAsync(
        string fromCode,
        string toCode,
        decimal rate,
        DateOnly date,
        RateSource source = RateSource.Manual,
        CancellationToken cancellationToken = default)
    {
        var from = Normalize(fromCode);
        var to = Normalize(toCode);

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var existing = await db.ExchangeRates
            .FirstOrDefaultAsync(r => r.FromCode == from && r.ToCode == to && r.Date == date, cancellationToken)
            .ConfigureAwait(false);

        if (existing is null)
        {
            db.ExchangeRates.Add(new ExchangeRate
            {
                FromCode = from,
                ToCode = to,
                Rate = rate,
                Date = date,
                Source = source,
            });
        }
        else
        {
            existing.Rate = rate;
            existing.Source = source;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task<decimal?> GetRateAsync(
        string fromCode,
        string toCode,
        DateOnly date,
        CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        return await ResolveRateAsync(db, Normalize(fromCode), Normalize(toCode), date, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<Money> ConvertToBaseAsync(
        Money amount,
        DateOnly date,
        CancellationToken cancellationToken = default)
    {
        var baseCode = await GetBaseCurrencyAsync(cancellationToken).ConfigureAwait(false);

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var digits = await GetDecimalDigitsAsync(db, baseCode, cancellationToken).ConfigureAwait(false);

        if (string.Equals(amount.Currency, baseCode, StringComparison.Ordinal))
        {
            return amount.Round(digits);
        }

        var rate = await ResolveRateAsync(db, amount.Currency, baseCode, date, cancellationToken).ConfigureAwait(false)
            ?? throw new ExchangeRateNotFoundException(amount.Currency, baseCode, date);

        return new Money(amount.Amount * rate, baseCode).Round(digits);
    }

    private static async Task<decimal?> ResolveRateAsync(
        LedgerlyDbContext db,
        string from,
        string to,
        DateOnly date,
        CancellationToken cancellationToken)
    {
        if (string.Equals(from, to, StringComparison.Ordinal))
        {
            return 1m;
        }

        // Rate for the date, else the most recent on/before it.
        var direct = await db.ExchangeRates.AsNoTracking()
            .Where(r => r.FromCode == from && r.ToCode == to && r.Date <= date)
            .OrderByDescending(r => r.Date)
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);
        if (direct is not null)
        {
            return direct.Rate;
        }

        // Fall back to the reciprocal of an inverse rate, if one exists.
        var inverse = await db.ExchangeRates.AsNoTracking()
            .Where(r => r.FromCode == to && r.ToCode == from && r.Date <= date)
            .OrderByDescending(r => r.Date)
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);
        if (inverse is not null && inverse.Rate != 0m)
        {
            return 1m / inverse.Rate;
        }

        return null;
    }

    private static async Task<int> GetDecimalDigitsAsync(
        LedgerlyDbContext db,
        string code,
        CancellationToken cancellationToken)
    {
        var currency = await db.Currencies.AsNoTracking()
            .FirstOrDefaultAsync(c => c.Code == code, cancellationToken)
            .ConfigureAwait(false);
        return currency?.DecimalDigits ?? FallbackDecimalDigits;
    }

    private static string Normalize(string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new ArgumentException("A currency code is required.", nameof(code));
        }

        return code.Trim().ToUpperInvariant();
    }
}
