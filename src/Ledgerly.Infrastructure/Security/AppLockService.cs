using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Ledgerly.Application.Abstractions;
using Ledgerly.Infrastructure.Persistence;
using Ledgerly.Infrastructure.Persistence.Seeding;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Ledgerly.Infrastructure.Security;

/// <summary>
/// Master-password → KDF → database key gate (FR-SEC-01/02, docs/09 §3, plan Task 0.4).
/// </summary>
public sealed class AppLockService : IAppLock
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private readonly IEncryptionKeyProvider _keyProvider;
    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;
    private readonly IDatabaseSeeder _seeder;
    private readonly LedgerlyOptions _options;
    private readonly ILogger<AppLockService> _logger;

    public AppLockService(
        IEncryptionKeyProvider keyProvider,
        IDbContextFactory<LedgerlyDbContext> contextFactory,
        IDatabaseSeeder seeder,
        LedgerlyOptions options,
        ILogger<AppLockService> logger)
    {
        _keyProvider = keyProvider;
        _contextFactory = contextFactory;
        _seeder = seeder;
        _options = options;
        _logger = logger;
    }

    public bool IsInitialized =>
        File.Exists(_options.DatabasePath) && File.Exists(_options.SecurityConfigPath);

    public bool IsUnlocked => _keyProvider.HasKey;

    public async Task<bool> InitializeAsync(string password, CancellationToken cancellationToken = default)
    {
        ValidatePassword(password);

        if (IsInitialized)
        {
            _logger.LogWarning("InitializeAsync called but the app is already initialized.");
            return false;
        }

        Directory.CreateDirectory(_options.DataDirectory);

        var config = KdfConfig.CreateNew();
        var key = DeriveKey(password, config);
        _keyProvider.SetKey(key);
        CryptographicOperations.ZeroMemory(key);

        try
        {
            await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
            await db.Database.EnsureCreatedAsync(cancellationToken).ConfigureAwait(false);

            // Seed reference data (settings, currencies, ...) into the new encrypted DB.
            await _seeder.SeedAsync(db, cancellationToken).ConfigureAwait(false);

            // Persist KDF params only after the encrypted DB exists, so a failure
            // never leaves a config pointing at a non-existent database.
            await WriteConfigAsync(config, cancellationToken).ConfigureAwait(false);

            _logger.LogInformation("Initialized encrypted database at {Path}.", _options.DatabasePath);
            return true;
        }
        catch
        {
            _keyProvider.Clear();
            throw;
        }
    }

    public async Task<bool> UnlockAsync(string password, CancellationToken cancellationToken = default)
    {
        ValidatePassword(password);

        if (!IsInitialized)
        {
            _logger.LogWarning("UnlockAsync called before the app was initialized.");
            return false;
        }

        var config = await ReadConfigAsync(cancellationToken).ConfigureAwait(false);
        var key = DeriveKey(password, config);
        _keyProvider.SetKey(key);
        CryptographicOperations.ZeroMemory(key);

        try
        {
            // Force a real read; a wrong key surfaces as a SQLCipher decrypt failure.
            await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
            _ = await db.Settings.AsNoTracking().AnyAsync(cancellationToken).ConfigureAwait(false);
            return true;
        }
        catch (SqliteException ex)
        {
            _keyProvider.Clear();
            _logger.LogWarning(ex, "Unlock failed: the master password is incorrect.");
            return false;
        }
    }

    public async Task<bool> ChangePasswordAsync(
        string currentPassword,
        string newPassword,
        CancellationToken cancellationToken = default)
    {
        ValidatePassword(newPassword);

        if (!await UnlockAsync(currentPassword, cancellationToken).ConfigureAwait(false))
        {
            return false;
        }

        var newConfig = KdfConfig.CreateNew();
        var newKey = DeriveKey(newPassword, newConfig);

        try
        {
            var oldKeyHex = _keyProvider.GetKeyHex();
            var newKeyHex = Convert.ToHexString(newKey);

            await using (var connection = new SqliteConnection(BuildConnectionString(_options)))
            {
                await connection.OpenAsync(cancellationToken).ConfigureAwait(false);
                await using var command = connection.CreateCommand();
                command.CommandText = $"PRAGMA key = \"x'{oldKeyHex}'\"; PRAGMA rekey = \"x'{newKeyHex}'\";";
                await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }

            _keyProvider.SetKey(newKey);
            await WriteConfigAsync(newConfig, cancellationToken).ConfigureAwait(false);

            _logger.LogInformation("Master password changed; database re-keyed.");
            return true;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(newKey);
        }
    }

    public void Lock() => _keyProvider.Clear();

    internal static string BuildConnectionString(LedgerlyOptions options) =>
        new SqliteConnectionStringBuilder
        {
            DataSource = options.DatabasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            // Pooling off so the SQLCipher key is always applied to a fresh handle
            // as the first statement on the connection.
            Pooling = false,
        }.ConnectionString;

    private static byte[] DeriveKey(string password, KdfConfig config)
    {
        if (!string.Equals(config.Algorithm, KdfConfig.Pbkdf2Sha256, StringComparison.Ordinal))
        {
            throw new NotSupportedException($"Unsupported KDF algorithm '{config.Algorithm}'.");
        }

        return Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(password),
            config.GetSalt(),
            config.Iterations,
            HashAlgorithmName.SHA256,
            config.KeyLengthBytes);
    }

    private static void ValidatePassword(string password)
    {
        if (string.IsNullOrEmpty(password))
        {
            throw new ArgumentException("The master password must not be empty.", nameof(password));
        }
    }

    private async Task WriteConfigAsync(KdfConfig config, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_options.DataDirectory);
        await using var stream = File.Create(_options.SecurityConfigPath);
        await JsonSerializer.SerializeAsync(stream, config, JsonOptions, cancellationToken).ConfigureAwait(false);
    }

    private async Task<KdfConfig> ReadConfigAsync(CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(_options.SecurityConfigPath);
        var config = await JsonSerializer.DeserializeAsync<KdfConfig>(stream, JsonOptions, cancellationToken)
            .ConfigureAwait(false);
        return config ?? throw new InvalidOperationException("The security configuration file is corrupt or empty.");
    }
}
