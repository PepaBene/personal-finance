namespace Ledgerly.Infrastructure.Security;

/// <summary>
/// Holds the 256-bit database master key in memory while the app is unlocked.
/// The key is set by <see cref="AppLockService"/> after KDF derivation and read by
/// the SQLCipher connection interceptor at connection-open time. It is never
/// persisted to disk in plaintext (docs/09 §3).
/// </summary>
public interface IEncryptionKeyProvider
{
    bool HasKey { get; }

    /// <summary>Stores a defensive copy of the derived key.</summary>
    void SetKey(byte[] key);

    /// <summary>Zeroes and drops the in-memory key.</summary>
    void Clear();

    /// <summary>Upper-case hex of the raw key for a SQLCipher <c>PRAGMA key = "x'...'"</c>.</summary>
    string GetKeyHex();
}
