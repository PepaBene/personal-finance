namespace Ledgerly.Application.Abstractions;

/// <summary>
/// Encrypted backup and restore (FR-DAT-02/03, docs/09 §6). The backup is the encrypted
/// SQLCipher database file, so it stays protected by the master password even off-box.
/// </summary>
public interface IBackupService
{
    /// <summary>Writes a consistent copy of the encrypted database to <paramref name="destinationPath"/>.</summary>
    Task BackupAsync(string destinationPath, CancellationToken cancellationToken = default);

    /// <summary>
    /// Restores from <paramref name="sourcePath"/>. Validates the backup opens with the
    /// current key and snapshots the current database to <c>backups/auto/</c> before
    /// overwriting (NFR-05/13). The app must be unlocked with the backup's password.
    /// </summary>
    Task RestoreAsync(string sourcePath, CancellationToken cancellationToken = default);
}
