using System.Data.Common;
using Ledgerly.Infrastructure.Security;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Ledgerly.Infrastructure.Persistence;

/// <summary>
/// Applies SQLCipher keying and connection PRAGMAs the moment a connection is
/// opened, before EF runs any command (docs/03, plan Task 0.3):
///   1. <c>PRAGMA key</c> — the raw 256-bit master key (must be the first op);
///   2. <c>PRAGMA foreign_keys = ON</c> — enforce referential integrity (docs/04 §5);
///   3. <c>PRAGMA journal_mode = WAL</c> — crash-safe concurrent reads (NFR-05).
///
/// Connection pooling is disabled (see <see cref="DependencyInjection"/>), so every
/// physical connection is freshly keyed here — avoiding the "key must be the first
/// statement" hazard of re-keying a pooled handle.
/// </summary>
internal sealed class SqlCipherConnectionInterceptor : DbConnectionInterceptor
{
    private readonly IEncryptionKeyProvider _keyProvider;

    public SqlCipherConnectionInterceptor(IEncryptionKeyProvider keyProvider)
    {
        _keyProvider = keyProvider;
    }

    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData)
    {
        ApplyPragmas(connection);
        base.ConnectionOpened(connection, eventData);
    }

    public override async Task ConnectionOpenedAsync(
        DbConnection connection,
        ConnectionEndEventData eventData,
        CancellationToken cancellationToken = default)
    {
        await ApplyPragmasAsync(connection, cancellationToken).ConfigureAwait(false);
        await base.ConnectionOpenedAsync(connection, eventData, cancellationToken).ConfigureAwait(false);
    }

    private void ApplyPragmas(DbConnection connection)
    {
        using var command = connection.CreateCommand();
        command.CommandText = BuildPragmaScript();
        command.ExecuteNonQuery();
    }

    private async Task ApplyPragmasAsync(DbConnection connection, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = BuildPragmaScript();
        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private string BuildPragmaScript()
    {
        // Hex (uppercase, [0-9A-F] only) — safe to interpolate into the raw-key PRAGMA.
        var keyHex = _keyProvider.GetKeyHex();
        return $"PRAGMA key = \"x'{keyHex}'\"; PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;";
    }
}
