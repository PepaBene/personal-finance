using System.Security.Cryptography;

namespace Ledgerly.Infrastructure.Security;

/// <inheritdoc />
public sealed class EncryptionKeyProvider : IEncryptionKeyProvider
{
    private readonly Lock _gate = new();
    private byte[]? _key;

    public bool HasKey
    {
        get
        {
            lock (_gate)
            {
                return _key is not null;
            }
        }
    }

    public void SetKey(byte[] key)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (key.Length == 0)
        {
            throw new ArgumentException("The encryption key must not be empty.", nameof(key));
        }

        lock (_gate)
        {
            ClearNoLock();
            _key = (byte[])key.Clone();
        }
    }

    public void Clear()
    {
        lock (_gate)
        {
            ClearNoLock();
        }
    }

    public string GetKeyHex()
    {
        lock (_gate)
        {
            if (_key is null)
            {
                throw new InvalidOperationException(
                    "The database is locked: no encryption key is available. Unlock with the master password first.");
            }

            return Convert.ToHexString(_key);
        }
    }

    private void ClearNoLock()
    {
        if (_key is not null)
        {
            CryptographicOperations.ZeroMemory(_key);
            _key = null;
        }
    }
}
