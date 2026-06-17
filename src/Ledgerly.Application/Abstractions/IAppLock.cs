namespace Ledgerly.Application.Abstractions;

/// <summary>
/// The single gate that turns the user's master password into the database
/// encryption key and holds it in memory only while unlocked (FR-SEC-01/02,
/// docs/09 §3). The derived key is never written to disk in plaintext.
/// </summary>
public interface IAppLock
{
    /// <summary>True once a database and its KDF parameters exist (i.e. not first run).</summary>
    bool IsInitialized { get; }

    /// <summary>True while the master key is held in memory.</summary>
    bool IsUnlocked { get; }

    /// <summary>
    /// First-run setup: chooses KDF parameters, derives the key from
    /// <paramref name="password"/>, creates the encrypted database and unlocks it.
    /// Returns false if the app is already initialized.
    /// </summary>
    Task<bool> InitializeAsync(string password, CancellationToken cancellationToken = default);

    /// <summary>
    /// Derives the key from <paramref name="password"/> and verifies it can decrypt
    /// the database. Returns false (and stays locked) if the password is incorrect.
    /// </summary>
    Task<bool> UnlockAsync(string password, CancellationToken cancellationToken = default);

    /// <summary>
    /// Re-keys the database from <paramref name="currentPassword"/> to
    /// <paramref name="newPassword"/> (SQLCipher <c>PRAGMA rekey</c>). Returns false
    /// if the current password is incorrect.
    /// </summary>
    Task<bool> ChangePasswordAsync(string currentPassword, string newPassword, CancellationToken cancellationToken = default);

    /// <summary>Drops the in-memory key; the database can no longer be read until unlocked again.</summary>
    void Lock();
}
