using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Transactions;

/// <summary>Read model returned to the presentation layer.</summary>
public sealed record TransactionDto(
    Guid Id,
    TransactionType Type,
    DateOnly Date,
    string CurrencyCode,
    decimal TotalAmount,
    decimal BaseAmount,
    decimal ExchangeRate,
    string? Note,
    TransactionSource Source,
    DateTimeOffset CreatedAt,
    IReadOnlyList<LineItemDto> LineItems);
