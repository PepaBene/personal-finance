using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class CaptureServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "capture-tests-password";
    private static readonly DateOnly Day = new(2026, 6, 8);

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private ITransactionService _transactions = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _transactions = _provider.GetRequiredService<ITransactionService>();
    }

    [Fact]
    public async Task Create_WithMultiCategorySplit_PersistsAndConvertsToBase()
    {
        var (groceries, dining) = await GetCategoryIdsAsync("Groceries", "Dining");

        var created = await _transactions.CreateAsync(new CreateTransactionRequest
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

        created.LineItems.Should().HaveCount(2);
        created.BaseAmount.Should().Be(33.68m, "842.00 CZK * 0.04 rounded to 2 dp");
        created.ExchangeRate.Should().Be(0.04m);

        var reloaded = await _transactions.GetByIdAsync(created.Id);
        reloaded!.LineItems.Select(li => li.CategoryId).Distinct().Should().HaveCount(2);
    }

    [Fact]
    public async Task Create_WithUnbalancedLineItems_ThrowsReconciliation()
    {
        var (groceries, dining) = await GetCategoryIdsAsync("Groceries", "Dining");

        var act = async () => await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Expense,
            Date = Day,
            CurrencyCode = "EUR",
            TotalAmount = 100.00m,
            LineItems =
            [
                new LineItemRequest { Description = "A", LineAmount = 40.00m, CategoryId = groceries },
                new LineItemRequest { Description = "B", LineAmount = 50.00m, CategoryId = dining },
            ],
        });

        await act.Should().ThrowAsync<ReconciliationException>();
    }

    [Fact]
    public async Task Create_WithoutLineItems_MaterializesImplicitSingleLine()
    {
        var (misc, _) = await GetCategoryIdsAsync("Misc", "Misc");

        var created = await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Expense,
            Date = Day,
            CurrencyCode = "EUR",
            TotalAmount = 19.90m,
            Note = "Parking",
            CategoryId = misc,
        });

        created.LineItems.Should().ContainSingle();
        created.LineItems[0].LineAmount.Should().Be(19.90m);
        created.LineItems[0].CategoryId.Should().Be(misc);
    }

    [Fact]
    public async Task Delete_SoftDeletes_AndHidesFromList()
    {
        var (misc, _) = await GetCategoryIdsAsync("Misc", "Misc");
        var created = await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Expense,
            Date = Day,
            CurrencyCode = "EUR",
            TotalAmount = 5.00m,
            CategoryId = misc,
        });

        await _transactions.DeleteAsync(created.Id);

        (await _transactions.GetAllAsync()).Should().NotContain(t => t.Id == created.Id);
    }

    private async Task<(Guid First, Guid Second)> GetCategoryIdsAsync(string first, string second)
    {
        var factory = _provider.GetRequiredService<IDbContextFactory<LedgerlyDbContext>>();
        await using var db = await factory.CreateDbContextAsync();
        var firstId = (await db.Categories.FirstAsync(c => c.Name == first)).Id;
        var secondId = (await db.Categories.FirstAsync(c => c.Name == second)).Id;
        return (firstId, secondId);
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();
}
