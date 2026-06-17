using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class BackupServiceTests : IDisposable
{
    private const string Password = "backup-tests-password";
    private static readonly DateOnly Day = new(2026, 6, 8);
    private readonly TempWorkspace _workspace = new();

    [Fact]
    public async Task BackupThenRestore_RevertsToBackupState()
    {
        await using var provider = _workspace.BuildProvider();
        await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        var transactions = provider.GetRequiredService<ITransactionService>();
        var backup = provider.GetRequiredService<IBackupService>();

        var original = await transactions.CreateAsync(Expense("ORIGINAL", 10m));
        var backupPath = Path.Combine(_workspace.Directory, "backup.db");
        await backup.BackupAsync(backupPath);

        var afterBackup = await transactions.CreateAsync(Expense("SECOND", 20m));
        (await transactions.GetAllAsync()).Should().HaveCount(2);

        await backup.RestoreAsync(backupPath);

        var restored = await transactions.GetAllAsync();
        restored.Should().ContainSingle(t => t.Id == original.Id);
        restored.Should().NotContain(t => t.Id == afterBackup.Id);
    }

    [Fact]
    public async Task Restore_MissingFile_Throws()
    {
        await using var provider = _workspace.BuildProvider();
        await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        var backup = provider.GetRequiredService<IBackupService>();

        var act = async () => await backup.RestoreAsync(Path.Combine(_workspace.Directory, "nope.db"));

        await act.Should().ThrowAsync<FileNotFoundException>();
    }

    private static CreateTransactionRequest Expense(string note, decimal amount) => new()
    {
        Type = TransactionType.Expense,
        Date = Day,
        CurrencyCode = "EUR",
        TotalAmount = amount,
        Note = note,
    };

    public void Dispose() => _workspace.Dispose();
}
