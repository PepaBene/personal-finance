using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Accounts;

/// <summary>Read model for an account, including its computed current balance.</summary>
public sealed record AccountDto(
    Guid Id,
    string Name,
    AccountKind Kind,
    string CurrencyCode,
    decimal OpeningBalance,
    decimal CurrentBalance,
    bool IsArchived);
