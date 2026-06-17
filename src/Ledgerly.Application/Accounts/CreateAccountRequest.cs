using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Accounts;

/// <summary>Input for creating an account (FR-ACC-01).</summary>
public sealed record CreateAccountRequest
{
    public required string Name { get; init; }

    public required string CurrencyCode { get; init; }

    public AccountKind Kind { get; init; } = AccountKind.Cash;

    public decimal OpeningBalance { get; init; }
}
