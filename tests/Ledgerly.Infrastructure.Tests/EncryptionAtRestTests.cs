using System.Text;
using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Transactions;
using Ledgerly.Domain.Common;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

/// <summary>
/// Proves the at-rest guarantees called out as "deep thinking required" in the plan:
/// the database file is genuinely encrypted and is unreadable without the key.
/// </summary>
public sealed class EncryptionAtRestTests : IDisposable
{
    private const string Password = "encryption-at-rest-password";
    private const string PlaintextMarker = "TOPSECRET_MARKER_2c1f9a7b_DO_NOT_LEAK";
    private readonly TempWorkspace _workspace = new();

    [Fact]
    public async Task DatabaseFile_IsEncrypted_AndKeyIsNotOnDisk()
    {
        await using (var provider = _workspace.BuildProvider())
        {
            await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
            var service = provider.GetRequiredService<ITransactionService>();

            await service.CreateAsync(new CreateTransactionRequest
            {
                Type = TransactionType.Expense,
                Date = new DateOnly(2026, 6, 17),
                CurrencyCode = "EUR",
                TotalAmount = 9.99m,
                Note = PlaintextMarker,
            });
        }

        var bytes = await File.ReadAllBytesAsync(_workspace.DatabasePath);

        // A plaintext SQLite DB starts with the ASCII header "SQLite format 3\0".
        // SQLCipher encrypts the header, so that signature must be absent.
        var header = Encoding.ASCII.GetString(bytes, 0, Math.Min(16, bytes.Length));
        header.Should().NotStartWith("SQLite format 3");

        // The note we wrote must not appear in cleartext anywhere in the file.
        IndexOf(bytes, Encoding.UTF8.GetBytes(PlaintextMarker))
            .Should().BeLessThan(0, "the note must be encrypted at rest");

        // The KDF config that lives next to the DB must not contain the password.
        var securityConfig = await File.ReadAllTextAsync(_workspace.Options.SecurityConfigPath);
        securityConfig.Should().NotContain(Password);
    }

    [Fact]
    public async Task OpeningWithoutKey_Fails()
    {
        await using (var provider = _workspace.BuildProvider())
        {
            await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        }

        var act = () =>
        {
            using var connection = new SqliteConnection(
                $"Data Source={_workspace.DatabasePath};Pooling=False");
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT count(*) FROM sqlite_master;";
            command.ExecuteScalar();
        };

        // Reading an encrypted database without the key surfaces as "file is not a database".
        act.Should().Throw<SqliteException>();
    }

    private static int IndexOf(byte[] haystack, byte[] needle)
    {
        if (needle.Length == 0 || haystack.Length < needle.Length)
        {
            return -1;
        }

        for (var i = 0; i <= haystack.Length - needle.Length; i++)
        {
            var match = true;
            for (var j = 0; j < needle.Length; j++)
            {
                if (haystack[i + j] != needle[j])
                {
                    match = false;
                    break;
                }
            }

            if (match)
            {
                return i;
            }
        }

        return -1;
    }

    public void Dispose() => _workspace.Dispose();
}
