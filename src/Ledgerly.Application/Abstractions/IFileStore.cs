using Ledgerly.Application.Documents;

namespace Ledgerly.Application.Abstractions;

/// <summary>
/// Encrypted storage for original documents (FR-SCAN-08, docs/09 §2). Files are
/// AES-256-GCM-encrypted with a key derived from the master key; the returned
/// <see cref="StoredFile.StoragePath"/> is relative to the app data directory.
/// </summary>
public interface IFileStore
{
    Task<StoredFile> SaveAsync(byte[] data, CancellationToken cancellationToken = default);

    Task<byte[]> ReadAsync(string storagePath, CancellationToken cancellationToken = default);

    Task DeleteAsync(string storagePath, CancellationToken cancellationToken = default);
}
