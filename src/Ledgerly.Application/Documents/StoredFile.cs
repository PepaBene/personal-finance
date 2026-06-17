namespace Ledgerly.Application.Documents;

/// <summary>Metadata returned after storing an attachment (docs/04 §2.6).</summary>
public sealed record StoredFile(string StoragePath, string Sha256, long Size);
