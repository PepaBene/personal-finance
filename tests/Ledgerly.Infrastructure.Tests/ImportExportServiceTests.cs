using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class ImportExportServiceTests : IDisposable
{
    private const string Password = "csv-tests-password";
    private static readonly DateOnly Day = new(2026, 6, 8);

    private readonly TempWorkspace _source = new();
    private readonly TempWorkspace _target = new();

    [Fact]
    public async Task ExportThenImport_RoundTripsAcrossDatabases()
    {
        string csv;
        await using (var source = _source.BuildProvider())
        {
            await source.GetRequiredService<IAppLock>().InitializeAsync(Password);
            var transactions = source.GetRequiredService<ITransactionService>();

            // Note contains a comma to exercise CSV quoting.
            await transactions.CreateAsync(new CreateTransactionRequest
            {
                Type = TransactionType.Expense,
                Date = Day,
                CurrencyCode = "EUR",
                TotalAmount = 10.00m,
                Note = "Coffee, large",
            });
            await transactions.CreateAsync(new CreateTransactionRequest
            {
                Type = TransactionType.Expense,
                Date = Day,
                CurrencyCode = "CZK",
                TotalAmount = 100.00m,
                ExchangeRate = 0.05m,
                Note = "Train",
            });

            csv = await source.GetRequiredService<IImportExportService>().ExportTransactionsCsvAsync();
        }

        await using var target = _target.BuildProvider();
        await target.GetRequiredService<IAppLock>().InitializeAsync(Password);

        var imported = await target.GetRequiredService<IImportExportService>().ImportTransactionsCsvAsync(csv);
        imported.Should().Be(2);

        var all = await target.GetRequiredService<ITransactionService>().GetAllAsync();
        all.Should().HaveCount(2);
        all.Should().Contain(t => t.Note == "Coffee, large" && t.CurrencyCode == "EUR" && t.TotalAmount == 10.00m);
        all.Should().Contain(t => t.Note == "Train" && t.CurrencyCode == "CZK" && t.TotalAmount == 100.00m);
    }

    public void Dispose()
    {
        _source.Dispose();
        _target.Dispose();
    }
}
