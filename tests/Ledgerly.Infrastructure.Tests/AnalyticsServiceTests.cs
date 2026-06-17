using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Accounts;
using Ledgerly.Application.Analytics;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class AnalyticsServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "analytics-tests-password";
    private static readonly DateOnly Day = new(2026, 6, 8);
    private static readonly AnalyticsFilter June = new()
    {
        From = new DateOnly(2026, 6, 1),
        To = new DateOnly(2026, 6, 30),
    };

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private IAnalyticsService _analytics = default!;
    private ITransactionService _transactions = default!;
    private IAccountService _accounts = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _analytics = _provider.GetRequiredService<IAnalyticsService>();
        _transactions = _provider.GetRequiredService<ITransactionService>();
        _accounts = _provider.GetRequiredService<IAccountService>();

        await SeedScenarioAsync();
    }

    [Fact]
    public async Task Totals_ExcludeTransfers_AndUseBaseCurrency()
    {
        var totals = await _analytics.GetTotalsAsync(June);

        totals.BaseCurrency.Should().Be("EUR");
        totals.Income.Should().Be(1000m);
        totals.Expense.Should().Be(33.68m);
        totals.Net.Should().Be(966.32m);
    }

    [Fact]
    public async Task SpendByCategory_IsLineLevel_InBaseCurrency()
    {
        var spend = await _analytics.GetSpendByCategoryAsync(June);

        spend.Should().HaveCount(2);
        spend.Single(s => s.CategoryName == "Groceries").Amount.Should().Be(16.00m); // 400 * 0.04
        spend.Single(s => s.CategoryName == "Dining").Amount.Should().Be(17.68m);    // 442 * 0.04
        spend.Sum(s => s.Share).Should().BeApproximately(1m, 0.0001m);
    }

    [Fact]
    public async Task OverTime_BucketsByMonth()
    {
        var series = await _analytics.GetOverTimeAsync(June, PeriodGrain.Month);

        series.Should().ContainSingle();
        series[0].PeriodStart.Should().Be(new DateOnly(2026, 6, 1));
        series[0].Income.Should().Be(1000m);
        series[0].Expense.Should().Be(33.68m);
    }

    private async Task SeedScenarioAsync()
    {
        var groceries = await GetCategoryIdAsync("Groceries");
        var dining = await GetCategoryIdAsync("Dining");
        var salary = await GetCategoryIdAsync("Salary");

        // Multi-category CZK expense; base EUR via rate 0.04 -> 33.68.
        await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Expense,
            Date = Day,
            CurrencyCode = "CZK",
            TotalAmount = 842.00m,
            ExchangeRate = 0.04m,
            LineItems =
            [
                new LineItemRequest { Description = "Groceries", LineAmount = 400.00m, CategoryId = groceries },
                new LineItemRequest { Description = "Dining", LineAmount = 442.00m, CategoryId = dining },
            ],
        });

        await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Income,
            Date = Day,
            CurrencyCode = "EUR",
            TotalAmount = 1000.00m,
            CategoryId = salary,
        });

        var a = await _accounts.CreateAsync(new CreateAccountRequest { Name = "A", CurrencyCode = "EUR", OpeningBalance = 100m });
        var b = await _accounts.CreateAsync(new CreateAccountRequest { Name = "B", CurrencyCode = "EUR" });
        await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Transfer,
            Date = Day,
            CurrencyCode = "EUR",
            TotalAmount = 50.00m,
            AccountId = a.Id,
            CounterAccountId = b.Id,
        });
    }

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
