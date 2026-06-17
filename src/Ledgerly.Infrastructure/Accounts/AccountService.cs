using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Accounts;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Accounts;

/// <inheritdoc />
public sealed class AccountService : IAccountService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;

    public AccountService(IDbContextFactory<LedgerlyDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    public async Task<AccountDto> CreateAsync(CreateAccountRequest request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            throw new ArgumentException("An account name is required.", nameof(request));
        }

        var account = new Account
        {
            Name = request.Name.Trim(),
            Kind = request.Kind,
            CurrencyCode = request.CurrencyCode.Trim().ToUpperInvariant(),
            OpeningBalance = request.OpeningBalance,
        };

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        db.Accounts.Add(account);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Map(account, account.OpeningBalance);
    }

    public async Task<IReadOnlyList<AccountDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var accounts = await db.Accounts.AsNoTracking()
            .Where(a => !a.IsArchived)
            .OrderBy(a => a.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var results = new List<AccountDto>(accounts.Count);
        foreach (var account in accounts)
        {
            var balance = await ComputeBalanceAsync(db, account, cancellationToken).ConfigureAwait(false);
            results.Add(Map(account, balance));
        }

        return results;
    }

    public async Task<AccountDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var account = await db.Accounts.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken)
            .ConfigureAwait(false);
        if (account is null)
        {
            return null;
        }

        var balance = await ComputeBalanceAsync(db, account, cancellationToken).ConfigureAwait(false);
        return Map(account, balance);
    }

    public async Task<decimal> GetBalanceAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var account = await db.Accounts.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken)
            .ConfigureAwait(false)
            ?? throw new ArgumentException($"Unknown account '{id}'.", nameof(id));

        return await ComputeBalanceAsync(db, account, cancellationToken).ConfigureAwait(false);
    }

    public async Task ArchiveAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == id, cancellationToken).ConfigureAwait(false);
        if (account is null)
        {
            return;
        }

        account.IsArchived = true;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Balance = opening + income − expense − transfers out + transfers in, over active
    /// transactions. Amounts are taken in the account's currency (multi-currency-per-account
    /// reconciliation is a later refinement). Summed client-side because SQLite stores
    /// decimals as TEXT and can't SUM them reliably; SQL rollups are a Phase 3 perf task.
    /// </summary>
    private static async Task<decimal> ComputeBalanceAsync(
        LedgerlyDbContext db,
        Account account,
        CancellationToken cancellationToken)
    {
        var rows = await db.Transactions.AsNoTracking()
            .Where(t => t.Status == TransactionStatus.Active
                && (t.AccountId == account.Id || t.CounterAccountId == account.Id))
            .Select(t => new { t.Type, t.TotalAmount, t.AccountId, t.CounterAccountId })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var balance = account.OpeningBalance;
        foreach (var row in rows)
        {
            if (row.AccountId == account.Id)
            {
                balance += row.Type switch
                {
                    TransactionType.Income => row.TotalAmount,
                    TransactionType.Expense => -row.TotalAmount,
                    TransactionType.Transfer => -row.TotalAmount,
                    _ => 0m,
                };
            }

            if (row.CounterAccountId == account.Id && row.Type == TransactionType.Transfer)
            {
                balance += row.TotalAmount;
            }
        }

        return balance;
    }

    private static AccountDto Map(Account account, decimal balance) => new(
        account.Id,
        account.Name,
        account.Kind,
        account.CurrencyCode,
        account.OpeningBalance,
        balance,
        account.IsArchived);
}
