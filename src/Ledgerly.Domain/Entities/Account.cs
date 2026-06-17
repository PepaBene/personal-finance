using Ledgerly.Domain.Common;

namespace Ledgerly.Domain.Entities;

/// <summary>
/// An account money sits in — cash, bank or card (docs/04 §2.5). Current balance is
/// computed as the opening balance plus the signed sum of its transactions/transfers.
/// </summary>
public class Account
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Name { get; set; } = default!;

    public AccountKind Kind { get; set; } = AccountKind.Cash;

    /// <summary>The account's native currency (ISO 4217).</summary>
    public string CurrencyCode { get; set; } = default!;

    public decimal OpeningBalance { get; set; }

    public bool IsArchived { get; set; }
}
