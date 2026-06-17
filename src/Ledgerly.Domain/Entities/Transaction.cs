using Ledgerly.Domain.Common;

namespace Ledgerly.Domain.Entities;

/// <summary>
/// Transaction header — a money event (docs/04 §2.1).
///
/// Phase 0 carries the minimal-but-real shape needed for the end-to-end vertical
/// slice: identity, type, date, original-currency amount, cached base-currency
/// amount, the FX rate used, an optional note, provenance and soft-delete state.
/// Line items, merchants and accounts arrive with the full data model in Phase 1
/// (docs/08), so no foreign keys are declared yet.
/// </summary>
public class Transaction
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public TransactionType Type { get; set; }

    /// <summary>Event date — drives the FX rate and the reporting period.</summary>
    public DateOnly Date { get; set; }

    /// <summary>Original currency (ISO 4217).</summary>
    public string CurrencyCode { get; set; } = "EUR";

    /// <summary>Amount in the original currency.</summary>
    public decimal TotalAmount { get; set; }

    /// <summary>Amount converted to the base currency (cached, docs/04 §3.3).</summary>
    public decimal BaseAmount { get; set; }

    /// <summary>Exchange rate (original → base) effective on <see cref="Date"/>.</summary>
    public decimal ExchangeRate { get; set; } = 1m;

    public string? Note { get; set; }

    public TransactionSource Source { get; set; } = TransactionSource.Manual;

    public TransactionStatus Status { get; set; } = TransactionStatus.Active;

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}
