using System.Security.Cryptography;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Documents;
using Ledgerly.Infrastructure.Security;

namespace Ledgerly.Infrastructure.IO;

/// <summary>
/// AES-256-GCM encrypted file storage for attachments (FR-SCAN-08, docs/09 §2). The key
/// is the in-memory master key, so attachments are unreadable without the password. File
/// layout: [12-byte nonce][16-byte tag][ciphertext].
/// </summary>
public sealed class EncryptedFileStore : IFileStore
{
    private const int NonceSize = 12;
    private const int TagSize = 16;
    private const string AttachmentsFolder = "attachments";

    private readonly IEncryptionKeyProvider _keyProvider;
    private readonly LedgerlyOptions _options;

    public EncryptedFileStore(IEncryptionKeyProvider keyProvider, LedgerlyOptions options)
    {
        _keyProvider = keyProvider;
        _options = options;
    }

    public async Task<StoredFile> SaveAsync(byte[] data, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(data);

        var directory = Path.Combine(_options.DataDirectory, AttachmentsFolder);
        Directory.CreateDirectory(directory);

        var relativePath = Path.Combine(AttachmentsFolder, Guid.NewGuid().ToString("N") + ".bin");
        var fullPath = Path.Combine(_options.DataDirectory, relativePath);

        await File.WriteAllBytesAsync(fullPath, Encrypt(data), cancellationToken).ConfigureAwait(false);

        var sha256 = Convert.ToHexString(SHA256.HashData(data));
        return new StoredFile(relativePath, sha256, data.LongLength);
    }

    public async Task<byte[]> ReadAsync(string storagePath, CancellationToken cancellationToken = default)
    {
        var fullPath = Path.Combine(_options.DataDirectory, storagePath);
        var payload = await File.ReadAllBytesAsync(fullPath, cancellationToken).ConfigureAwait(false);
        return Decrypt(payload);
    }

    public Task DeleteAsync(string storagePath, CancellationToken cancellationToken = default)
    {
        var fullPath = Path.Combine(_options.DataDirectory, storagePath);
        if (File.Exists(fullPath))
        {
            File.Delete(fullPath);
        }

        return Task.CompletedTask;
    }

    private byte[] Encrypt(byte[] plaintext)
    {
        var key = GetKey();
        try
        {
            var nonce = RandomNumberGenerator.GetBytes(NonceSize);
            var ciphertext = new byte[plaintext.Length];
            var tag = new byte[TagSize];

            using (var aes = new AesGcm(key, TagSize))
            {
                aes.Encrypt(nonce, plaintext, ciphertext, tag);
            }

            var result = new byte[NonceSize + TagSize + ciphertext.Length];
            Buffer.BlockCopy(nonce, 0, result, 0, NonceSize);
            Buffer.BlockCopy(tag, 0, result, NonceSize, TagSize);
            Buffer.BlockCopy(ciphertext, 0, result, NonceSize + TagSize, ciphertext.Length);
            return result;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(key);
        }
    }

    private byte[] Decrypt(byte[] payload)
    {
        if (payload.Length < NonceSize + TagSize)
        {
            throw new InvalidOperationException("The attachment is corrupt or truncated.");
        }

        var key = GetKey();
        try
        {
            var nonce = payload[..NonceSize];
            var tag = payload[NonceSize..(NonceSize + TagSize)];
            var ciphertext = payload[(NonceSize + TagSize)..];
            var plaintext = new byte[ciphertext.Length];

            using (var aes = new AesGcm(key, TagSize))
            {
                aes.Decrypt(nonce, ciphertext, tag, plaintext);
            }

            return plaintext;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(key);
        }
    }

    private byte[] GetKey() => Convert.FromHexString(_keyProvider.GetKeyHex());
}
