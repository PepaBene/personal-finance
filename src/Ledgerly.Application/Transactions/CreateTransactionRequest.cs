using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Transactions;

/// <summary>Input for creating a transaction (FR-CAP-01..05).</summary>
public sealed record CreateTransactionRequest
{
    public required TransactionType Type { get; init; }

    public required DateOnly Date { get; init; }

    /// <summary>Original currency (ISO 4217).</summary>
    public required string CurrencyCode { get; init; }

    /// <summary>Amount in the original currency.</summary>
    public required decimal TotalAmount { get; init; }

    /// <summary>
    /// Optional explicit exchange rate (original → base). When supplied for a foreign
    /// currency it is recorded as a manual historical rate; otherwise the rate is looked
    /// up from the FX engine. Null/omitted means "look it up".
    /// </summary>
    public decimal? ExchangeRate { get; init; }

    public string? Note { get; init; }

    public TransactionSource Source { get; init; } = TransactionSource.Manual;

    /// <summary>
    /// Line items making up the transaction (FR-CAP-03). When empty, a single implicit
    /// line in <see cref="CategoryId"/> is created (FR-CAP-04).
    /// </summary>
    public IReadOnlyList<LineItemRequest> LineItems { get; init; } = [];

    /// <summary>Category for the implicit single line when no <see cref="LineItems"/> are given.</summary>
    public Guid? CategoryId { get; init; }

    /// <summary>Source account (FR-ACC-02).</summary>
    public Guid? AccountId { get; init; }

    /// <summary>Destination account — required when <see cref="Type"/> is Transfer (FR-ACC-03).</summary>
    public Guid? CounterAccountId { get; init; }

    public Guid? MerchantId { get; init; }
}
