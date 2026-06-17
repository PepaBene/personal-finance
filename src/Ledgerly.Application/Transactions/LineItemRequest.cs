namespace Ledgerly.Application.Transactions;

/// <summary>A line item to create within a transaction (FR-CAP-03).</summary>
public sealed record LineItemRequest
{
    public required string Description { get; init; }

    /// <summary>Line total in the transaction's original currency.</summary>
    public required decimal LineAmount { get; init; }

    public required Guid CategoryId { get; init; }

    public decimal Quantity { get; init; } = 1m;

    public decimal? UnitPrice { get; init; }

    public decimal? TaxRate { get; init; }
}
