using System.Text;
using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class EncryptedFileStoreTests : IDisposable
{
    private const string Password = "filestore-tests-password";
    private const string Marker = "ATTACHMENT_PLAINTEXT_MARKER_5f3a";
    private readonly TempWorkspace _workspace = new();

    [Fact]
    public async Task SaveThenRead_RoundTrips_AndIsEncryptedAtRest()
    {
        await using var provider = _workspace.BuildProvider();
        await provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        var store = provider.GetRequiredService<IFileStore>();

        var data = Encoding.UTF8.GetBytes($"receipt bytes — {Marker}");
        var stored = await store.SaveAsync(data);

        // Round-trips.
        (await store.ReadAsync(stored.StoragePath)).Should().Equal(data);

        // SHA-256 is of the plaintext (dedupe/integrity, docs/04 §2.6).
        stored.Sha256.Should().Be(Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(data)));

        // The bytes on disk are encrypted — the marker must not appear in cleartext.
        var onDisk = await File.ReadAllBytesAsync(Path.Combine(_workspace.Directory, stored.StoragePath));
        Encoding.UTF8.GetString(onDisk).Should().NotContain(Marker);

        await store.DeleteAsync(stored.StoragePath);
        File.Exists(Path.Combine(_workspace.Directory, stored.StoragePath)).Should().BeFalse();
    }

    public void Dispose() => _workspace.Dispose();
}
