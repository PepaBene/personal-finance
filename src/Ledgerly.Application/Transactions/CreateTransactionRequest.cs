using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Transactions;

/// <summary>Input for creating a transaction (Phase 0 minimal slice).</summary>
public sealed record CreateTransactionRequest
{
    public required TransactionType Type { get; init; }

    public required DateOnly Date { get; init; }

    /// <summary>Original currency (ISO 4217).</summary>
    public required string CurrencyCode { get; init; }

    /// <summary>Amount in the original currency.</summary>
    public required decimal TotalAmount { get; init; }

    /// <summary>Exchange rate (original → base). Defaults to 1 (already in base currency).</summary>
    public decimal ExchangeRate { get; init; } = 1m;

    public string? Note { get; init; }

    public TransactionSource Source { get; init; } = TransactionSource.Manual;
}
