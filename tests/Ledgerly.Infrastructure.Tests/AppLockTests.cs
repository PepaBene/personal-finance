using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class AppLockTests : IDisposable
{
    private const string Password = "correct horse battery staple";
    private readonly TempWorkspace _workspace = new();

    [Fact]
    public async Task FreshWorkspace_IsNotInitialized()
    {
        await using var provider = _workspace.BuildProvider();
        var appLock = provider.GetRequiredService<IAppLock>();

        appLock.IsInitialized.Should().BeFalse();
        appLock.IsUnlocked.Should().BeFalse();
    }

    [Fact]
    public async Task Initialize_CreatesEncryptedDatabaseAndUnlocks()
    {
        await using var provider = _workspace.BuildProvider();
        var appLock = provider.GetRequiredService<IAppLock>();

        var initialized = await appLock.InitializeAsync(Password);

        initialized.Should().BeTrue();
        appLock.IsUnlocked.Should().BeTrue();
        appLock.IsInitialized.Should().BeTrue();
        File.Exists(_workspace.DatabasePath).Should().BeTrue();
    }

    [Fact]
    public async Task Initialize_WhenAlreadyInitialized_ReturnsFalse()
    {
        await using (var first = _workspace.BuildProvider())
        {
            await first.GetRequiredService<IAppLock>().InitializeAsync(Password);
        }

        await using var second = _workspace.BuildProvider();
        var result = await second.GetRequiredService<IAppLock>().InitializeAsync(Password);

        result.Should().BeFalse();
    }

    [Fact]
    public async Task Unlock_WithCorrectPassword_Succeeds()
    {
        await using (var setup = _workspace.BuildProvider())
        {
            await setup.GetRequiredService<IAppLock>().InitializeAsync(Password);
        }

        // New "process": only the password unlocks it.
        await using var session = _workspace.BuildProvider();
        var appLock = session.GetRequiredService<IAppLock>();

        var unlocked = await appLock.UnlockAsync(Password);

        unlocked.Should().BeTrue();
        appLock.IsUnlocked.Should().BeTrue();
    }

    [Fact]
    public async Task Unlock_WithWrongPassword_FailsAndStaysLocked()
    {
        await using (var setup = _workspace.BuildProvider())
        {
            await setup.GetRequiredService<IAppLock>().InitializeAsync(Password);
        }

        await using var session = _workspace.BuildProvider();
        var appLock = session.GetRequiredService<IAppLock>();

        var unlocked = await appLock.UnlockAsync("not the password");

        unlocked.Should().BeFalse();
        appLock.IsUnlocked.Should().BeFalse();
    }

    [Fact]
    public async Task ChangePassword_RekeysDatabase()
    {
        const string newPassword = "an entirely different secret";

        await using (var setup = _workspace.BuildProvider())
        {
            await setup.GetRequiredService<IAppLock>().InitializeAsync(Password);
        }

        await using (var change = _workspace.BuildProvider())
        {
            var changed = await change.GetRequiredService<IAppLock>()
                .ChangePasswordAsync(Password, newPassword);
            changed.Should().BeTrue();
        }

        await using var verify = _workspace.BuildProvider();
        var appLock = verify.GetRequiredService<IAppLock>();

        (await appLock.UnlockAsync(Password)).Should().BeFalse("the old password must no longer work");
        appLock.Lock();
        (await appLock.UnlockAsync(newPassword)).Should().BeTrue("the new password must unlock the re-keyed DB");
    }

    public void Dispose() => _workspace.Dispose();
}
