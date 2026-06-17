using Ledgerly.Domain.Common;

namespace Ledgerly.Domain.Entities;

/// <summary>
/// A historical exchange rate (docs/04 §3.2). Rates are stored per date; conversion
/// picks the rate effective on the transaction date, falling back to the most recent
/// rate on or before it (docs/04 §3.3). Unique on (FromCode, ToCode, Date).
/// </summary>
public class ExchangeRate
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string FromCode { get; set; } = default!;

    public string ToCode { get; set; } = default!;

    /// <summary>Multiply an amount in <see cref="FromCode"/> by this to get <see cref="ToCode"/>.</summary>
    public decimal Rate { get; set; }

    public DateOnly Date { get; set; }

    public RateSource Source { get; set; } = RateSource.Manual;
}
