using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class TransactionPersistenceTests : IDisposable
{
    private const string Password = "vertical-slice-password";
    private readonly TempWorkspace _workspace = new();

    [Fact]
    public async Task Transaction_PersistsEncrypted_AndSurvivesRestart()
    {
        Guid id;

        // Session 1: initialize and create one transaction.
        await using (var session1 = _workspace.BuildProvider())
        {
            await session1.GetRequiredService<IAppLock>().InitializeAsync(Password);
            var service = session1.GetRequiredService<ITransactionService>();

            var created = await service.CreateAsync(new CreateTransactionRequest
            {
                Type = TransactionType.Expense,
                Date = new DateOnly(2026, 6, 8),
                CurrencyCode = "CZK",
                TotalAmount = 842.00m,
                ExchangeRate = 0.04m,
                Note = "Albert groceries",
            });

            id = created.Id;
            created.BaseAmount.Should().Be(33.68m, "842.00 × 0.04 rounded to 4 dp");
        }

        // Session 2: a brand-new provider (simulated restart) must unlock and re-read it.
        await using (var session2 = _workspace.BuildProvider())
        {
            var appLock = session2.GetRequiredService<IAppLock>();
            (await appLock.UnlockAsync(Password)).Should().BeTrue();

            var service = session2.GetRequiredService<ITransactionService>();

            var all = await service.GetAllAsync();
            all.Should().ContainSingle(t => t.Id == id);

            var reloaded = await service.GetByIdAsync(id);
            reloaded.Should().NotBeNull();
            reloaded!.TotalAmount.Should().Be(842.00m);
            reloaded.CurrencyCode.Should().Be("CZK");
            reloaded.BaseAmount.Should().Be(33.68m);
            reloaded.Note.Should().Be("Albert groceries");
        }
    }

    public void Dispose() => _workspace.Dispose();
}
