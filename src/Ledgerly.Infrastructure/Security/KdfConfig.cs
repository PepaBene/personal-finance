using System.Security.Cryptography;

namespace Ledgerly.Infrastructure.Security;

/// <summary>
/// Non-secret key-derivation parameters persisted next to the database
/// (docs/09 §3: "Salt + KDF parameters stored in a small local config").
///
/// Phase 0 uses PBKDF2-HMAC-SHA256 with a high iteration count — no extra native
/// dependency and entirely in the BCL. Argon2id (the doc's preferred option) is
/// tracked as open question #4 and can be slotted in behind this same config in a
/// later phase by bumping <see cref="Version"/>.
/// </summary>
public sealed class KdfConfig
{
    public const string Pbkdf2Sha256 = "PBKDF2-HMAC-SHA256";

    private const int DefaultIterations = 600_000; // OWASP-aligned for PBKDF2-HMAC-SHA256
    private const int DefaultKeyLengthBytes = 32;   // 256-bit SQLCipher key
    private const int SaltLengthBytes = 16;

    public int Version { get; set; } = 1;

    public string Algorithm { get; set; } = Pbkdf2Sha256;

    /// <summary>Base64-encoded per-install random salt.</summary>
    public string Salt { get; set; } = string.Empty;

    public int Iterations { get; set; } = DefaultIterations;

    public int KeyLengthBytes { get; set; } = DefaultKeyLengthBytes;

    public static KdfConfig CreateNew() => new()
    {
        Salt = Convert.ToBase64String(RandomNumberGenerator.GetBytes(SaltLengthBytes)),
    };

    public byte[] GetSalt() => Convert.FromBase64String(Salt);
}
