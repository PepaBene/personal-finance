using Ledgerly.Domain.Common;
using Ledgerly.Domain.ValueObjects;

namespace Ledgerly.Application.Abstractions;

/// <summary>
/// Multi-currency / FX engine (FR-CUR-01..04/06, docs/04 §3). All analytics aggregate
/// on base-currency amounts, so conversion correctness is critical (ADR-005).
/// </summary>
public interface ICurrencyService
{
    /// <summary>The home/base currency used for all aggregated reporting (FR-CUR-01).</summary>
    Task<string> GetBaseCurrencyAsync(CancellationToken cancellationToken = default);

    /// <summary>The number of fractional digits for a currency (defaults to 2 if unknown).</summary>
    Task<int> GetDecimalDigitsAsync(string code, CancellationToken cancellationToken = default);

    /// <summary>Sets the base currency. Throws if the currency is unknown.</summary>
    Task SetBaseCurrencyAsync(string code, CancellationToken cancellationToken = default);

    /// <summary>Adds or updates the rate for (from, to, date) (FR-CUR-04). Unique per date.</summary>
    Task UpsertRateAsync(
        string fromCode,
        string toCode,
        decimal rate,
        DateOnly date,
        RateSource source = RateSource.Manual,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Resolves the rate (from → to) effective on <paramref name="date"/>: the rate for
    /// that date, else the most recent on/before it, else the reciprocal of an inverse
    /// rate, else <c>null</c> (FR-CUR-03, docs/04 §3.3). Same currency yields 1.
    /// </summary>
    Task<decimal?> GetRateAsync(
        string fromCode,
        string toCode,
        DateOnly date,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Converts <paramref name="amount"/> to the base currency using the rate effective on
    /// <paramref name="date"/>, rounded (banker's) to the base currency's decimal digits.
    /// Throws <see cref="Currency.ExchangeRateNotFoundException"/> if no rate is available.
    /// </summary>
    Task<Money> ConvertToBaseAsync(Money amount, DateOnly date, CancellationToken cancellationToken = default);
}
