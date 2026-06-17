using Ledgerly.Application.Abstractions;
using Ledgerly.Infrastructure.Persistence;
using Ledgerly.Infrastructure.Security;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.IO;

/// <inheritdoc />
public sealed class BackupService : IBackupService
{
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;
    private readonly IEncryptionKeyProvider _keyProvider;
    private readonly LedgerlyOptions _options;

    public BackupService(
        IDbContextFactory<LedgerlyDbContext> contextFactory,
        IEncryptionKeyProvider keyProvider,
        LedgerlyOptions options)
    {
        _contextFactory = contextFactory;
        _keyProvider = keyProvider;
        _options = options;
    }

    public async Task BackupAsync(string destinationPath, CancellationToken cancellationToken = default)
    {
        EnsureUnlocked();
        ArgumentException.ThrowIfNullOrWhiteSpace(destinationPath);

        // Fold the WAL into the main database file so a plain file copy is consistent.
        await CheckpointAsync(cancellationToken).ConfigureAwait(false);

        var directory = Path.GetDirectoryName(destinationPath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        File.Copy(_options.DatabasePath, destinationPath, overwrite: true);
    }

    public async Task RestoreAsync(string sourcePath, CancellationToken cancellationToken = default)
    {
        EnsureUnlocked();
        if (!File.Exists(sourcePath))
        {
            throw new FileNotFoundException("Backup file not found.", sourcePath);
        }

        // Refuse to overwrite unless the backup decrypts with the current key.
        await ValidateOpensWithCurrentKeyAsync(sourcePath, cancellationToken).ConfigureAwait(false);

        // Snapshot the current database before overwriting (NFR-05).
        await CheckpointAsync(cancellationToken).ConfigureAwait(false);
        var snapshotDirectory = Path.Combine(_options.DataDirectory, "backups", "auto");
        Directory.CreateDirectory(snapshotDirectory);
        var snapshot = Path.Combine(snapshotDirectory, $"pre-restore-{DateTime.UtcNow:yyyyMMddHHmmss}.db");
        File.Copy(_options.DatabasePath, snapshot, overwrite: true);

        File.Copy(sourcePath, _options.DatabasePath, overwrite: true);

        // Drop the live WAL/SHM sidecars so the restored file is authoritative.
        foreach (var suffix in new[] { "-wal", "-shm" })
        {
            var sidecar = _options.DatabasePath + suffix;
            if (File.Exists(sidecar))
            {
                File.Delete(sidecar);
            }
        }
    }

    private async Task CheckpointAsync(CancellationToken cancellationToken)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        await db.Database.ExecuteSqlRawAsync("PRAGMA wal_checkpoint(TRUNCATE);", cancellationToken).ConfigureAwait(false);
    }

    private async Task ValidateOpensWithCurrentKeyAsync(string path, CancellationToken cancellationToken)
    {
        var keyHex = _keyProvider.GetKeyHex();
        var connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = path,
            Mode = SqliteOpenMode.ReadOnly,
            Pooling = false,
        }.ConnectionString;

        await using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync(cancellationToken).ConfigureAwait(false);
        await using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA key = \"x'{keyHex}'\"; SELECT count(*) FROM sqlite_master;";
        try
        {
            await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (SqliteException ex)
        {
            throw new InvalidOperationException(
                "The backup could not be opened with the current master password.", ex);
        }
    }

    private void EnsureUnlocked()
    {
        if (!_keyProvider.HasKey)
        {
            throw new InvalidOperationException("The database must be unlocked before backup or restore.");
        }
    }
}
