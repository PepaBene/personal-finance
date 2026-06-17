using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class TagServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "tag-tests-password";

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private ITagService _tags = default!;
    private ITransactionService _transactions = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _tags = _provider.GetRequiredService<ITagService>();
        _transactions = _provider.GetRequiredService<ITransactionService>();
    }

    [Fact]
    public async Task Create_IsGetOrCreate()
    {
        var first = await _tags.CreateAsync("vacation-2026", "#FF0000");
        var second = await _tags.CreateAsync("vacation-2026");

        second.Id.Should().Be(first.Id);
        (await _tags.GetAllAsync()).Should().ContainSingle(t => t.Name == "vacation-2026");
    }

    [Fact]
    public async Task AddRemove_TagOnLineItem()
    {
        var lineItemId = await CreateLineItemAsync();
        var tag = await _tags.CreateAsync("groceries-run");

        await _tags.AddToLineItemAsync(lineItemId, tag.Id);
        await _tags.AddToLineItemAsync(lineItemId, tag.Id); // idempotent

        (await _tags.GetForLineItemAsync(lineItemId)).Should().ContainSingle(t => t.Id == tag.Id);

        await _tags.RemoveFromLineItemAsync(lineItemId, tag.Id);
        (await _tags.GetForLineItemAsync(lineItemId)).Should().BeEmpty();
    }

    private async Task<Guid> CreateLineItemAsync()
    {
        var factory = _provider.GetRequiredService<IDbContextFactory<LedgerlyDbContext>>();
        Guid miscId;
        await using (var db = await factory.CreateDbContextAsync())
        {
            miscId = (await db.Categories.FirstAsync(c => c.Name == "Misc")).Id;
        }

        var created = await _transactions.CreateAsync(new CreateTransactionRequest
        {
            Type = TransactionType.Expense,
            Date = new DateOnly(2026, 6, 8),
            CurrencyCode = "EUR",
            TotalAmount = 12.00m,
            CategoryId = miscId,
        });

        return created.LineItems[0].Id;
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();
}
