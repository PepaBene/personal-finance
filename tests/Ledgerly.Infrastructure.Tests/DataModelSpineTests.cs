using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Ledgerly.Domain.Transactions;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class DataModelSpineTests : IDisposable
{
    private const string Password = "spine-tests-password";
    private readonly TempWorkspace _workspace = new();

    [Fact]
    public async Task DefaultCategories_AreSeeded_WithHierarchy()
    {
        await using var provider = _workspace.BuildProvider();
        await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        var factory = provider.GetRequiredService<IDbContextFactory<LedgerlyDbContext>>();

        await using var db = await factory.CreateDbContextAsync();

        (await db.Categories.CountAsync()).Should().BeGreaterThan(10);
        (await db.Categories.AnyAsync(c => c.Name == "Groceries" && c.ParentId != null))
            .Should().BeTrue("Groceries is a child of Food");
        (await db.Categories.AnyAsync(c => c.Name == "Income" && c.Kind == CategoryKind.Income))
            .Should().BeTrue();
    }

    [Fact]
    public async Task SplitTransaction_PersistsLineItems_ReconcilesAndCascades()
    {
        await using var provider = _workspace.BuildProvider();
        await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        var factory = provider.GetRequiredService<IDbContextFactory<LedgerlyDbContext>>();

        Guid transactionId;

        await using (var db = await factory.CreateDbContextAsync())
        {
            var groceries = await db.Categories.FirstAsync(c => c.Name == "Groceries");
            var dining = await db.Categories.FirstAsync(c => c.Name == "Dining");

            var now = DateTimeOffset.UtcNow;
            var transaction = new Transaction
            {
                Type = TransactionType.Expense,
                Date = new DateOnly(2026, 6, 8),
                CurrencyCode = "CZK",
                TotalAmount = 842.00m,
                ExchangeRate = 0.04m,
                BaseAmount = 33.68m,
                Source = TransactionSource.Manual,
                Status = TransactionStatus.Active,
                CreatedAt = now,
                UpdatedAt = now,
                LineItems =
                {
                    new LineItem { Description = "Weekly groceries", LineAmount = 400.00m, CategoryId = groceries.Id, SortOrder = 0 },
                    new LineItem { Description = "Lunch out", LineAmount = 442.00m, CategoryId = dining.Id, SortOrder = 1 },
                },
            };

            db.Transactions.Add(transaction);
            await db.SaveChangesAsync();
            transactionId = transaction.Id;
        }

        // Reload in a fresh context and verify the split round-trips and reconciles.
        await using (var db = await factory.CreateDbContextAsync())
        {
            var transaction = await db.Transactions
                .Include(t => t.LineItems)
                .FirstAsync(t => t.Id == transactionId);

            transaction.LineItems.Should().HaveCount(2);
            transaction.LineItems.Select(li => li.CategoryId).Distinct()
                .Should().HaveCount(2, "the bill is split across two categories");
            TransactionReconciler.Difference(transaction.TotalAmount, transaction.LineItems.Select(li => li.LineAmount))
                .Should().Be(0m);
        }

        // Deleting the transaction cascades to its line items (docs/04 §5).
        await using (var db = await factory.CreateDbContextAsync())
        {
            var transaction = await db.Transactions.FirstAsync(t => t.Id == transactionId);
            db.Transactions.Remove(transaction);
            await db.SaveChangesAsync();

            (await db.LineItems.CountAsync(li => li.TransactionId == transactionId)).Should().Be(0);
        }
    }

    public void Dispose() => _workspace.Dispose();
}
