namespace Ledgerly.Application.Transactions;

/// <summary>Read model for a transaction's line item.</summary>
public sealed record LineItemDto(
    Guid Id,
    string Description,
    decimal Quantity,
    decimal? UnitPrice,
    decimal LineAmount,
    Guid CategoryId,
    int SortOrder);
