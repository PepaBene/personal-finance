using Ledgerly.Application.Accounts;

namespace Ledgerly.Application.Abstractions;

/// <summary>Accounts and their balances (FR-ACC-01..03).</summary>
public interface IAccountService
{
    Task<AccountDto> CreateAsync(CreateAccountRequest request, CancellationToken cancellationToken = default);

    /// <summary>All non-archived accounts with their computed current balances.</summary>
    Task<IReadOnlyList<AccountDto>> GetAllAsync(CancellationToken cancellationToken = default);

    Task<AccountDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Current balance = opening balance + signed sum of transactions/transfers.</summary>
    Task<decimal> GetBalanceAsync(Guid id, CancellationToken cancellationToken = default);

    Task ArchiveAsync(Guid id, CancellationToken cancellationToken = default);
}
