using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Accounts;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class AccountServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "account-tests-password";
    private static readonly DateOnly Day = new(2026, 6, 8);

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private IAccountService _accounts = default!;
    private ITransactionService _transactions = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _accounts = _provider.GetRequiredService<IAccountService>();
        _transactions = _provider.GetRequiredService<ITransactionService>();
    }

    [Fact]
    public async Task NewAccount_BalanceStartsAtOpeningBalance()
    {
        var account = await _accounts.CreateAsync(new CreateAccountRequest
        {
            Name = "Cash",
            CurrencyCode = "EUR",
            Kind = AccountKind.Cash,
            OpeningBalance = 100m,
        });

        account.CurrentBalance.Should().Be(100m);
        (await _accounts.GetBalanceAsync(account.Id)).Should().Be(100m);
    }

    [Fact]
    public async Task ExpenseAndIncome_AdjustBalance()
    {
        var account = await _accounts.CreateAsync(new CreateAccountRequest
        {
            Name = "Bank",
            CurrencyCode = "EUR",
            Kind = AccountKind.Bank,
            OpeningBalance = 100m,
        });
        var misc = await GetCategoryIdAsync("Misc");
        var salary = await GetCategoryIdAsync("Salary");

        await _transactions.CreateAsync(NonTransfer(TransactionType.Expense, 30m, account.Id, misc));
        await _transactions.CreateAsync(NonTransfer(TransactionType.Income, 50m, account.Id, salary));

        (await _accounts.GetBalanceAsync(account.Id)).Should().Be(120m); // 100 - 30 + 50
    }

    [Fact]
    public async Task Transfer_MovesMoneyBetweenAccounts()
    {
        var from = await _accounts.CreateAsync(new CreateAccountRequest { Name = "From", CurrencyCode = "EUR", OpeningBalance = 200m });
        var to = await _accounts.CreateAsync(new CreateAccountRequest { Name = "To", CurrencyCode = "EUR", OpeningBalance = 0m });

        await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Transfer,
            Date = Day,
            CurrencyCode = "EUR",
            TotalAmount = 40m,
            AccountId = from.Id,
            CounterAccountId = to.Id,
        });

        (await _accounts.GetBalanceAsync(from.Id)).Should().Be(160m);
        (await _accounts.GetBalanceAsync(to.Id)).Should().Be(40m);
    }

    [Fact]
    public async Task Transfer_RequiresDistinctAccounts()
    {
        var account = await _accounts.CreateAsync(new CreateAccountRequest { Name = "Solo", CurrencyCode = "EUR" });

        var act = async () => await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Transfer,
            Date = Day,
            CurrencyCode = "EUR",
            TotalAmount = 10m,
            AccountId = account.Id,
            CounterAccountId = account.Id,
        });

        await act.Should().ThrowAsync<ArgumentException>();
    }

    private static CreateTransactionRequest NonTransfer(TransactionType type, decimal amount, Guid accountId, Guid categoryId) => new()
    {
        Type = type,
        Date = Day,
        CurrencyCode = "EUR",
        TotalAmount = amount,
        AccountId = accountId,
        CategoryId = categoryId,
    };

    private async Task<Guid> GetCategoryIdAsync(string name)
    {
        var factory = _provider.GetRequiredService<IDbContextFactory<LedgerlyDbContext>>();
        await using var db = await factory.CreateDbContextAsync();
        return (await db.Categories.FirstAsync(c => c.Name == name)).Id;
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();
}
