namespace Ledgerly.Application.Transactions;

/// <summary>
/// Thrown when a transaction's line items do not reconcile to its total within the
/// currency's rounding tolerance (FR-CAP-05, docs/04 §2.1).
/// </summary>
public sealed class ReconciliationException : Exception
{
    public ReconciliationException(decimal total, decimal lineSum, string currency)
        : base($"Line items sum to {lineSum} {currency} but the transaction total is {total} {currency}.")
    {
        Total = total;
        LineSum = lineSum;
        Currency = currency;
    }

    public decimal Total { get; }

    public decimal LineSum { get; }

    public string Currency { get; }
}
