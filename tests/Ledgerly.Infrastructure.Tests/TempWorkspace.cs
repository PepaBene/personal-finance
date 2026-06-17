using Ledgerly.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

namespace Ledgerly.Infrastructure.Tests;

/// <summary>
/// A throwaway data directory plus a helper to build a fresh service provider over
/// it — simulating an app process. Building a second provider against the same
/// directory simulates restarting the app (used to prove data survives a restart).
/// </summary>
public sealed class TempWorkspace : IDisposable
{
    public TempWorkspace()
    {
        Directory = Path.Combine(Path.GetTempPath(), "ledgerly-tests", Guid.NewGuid().ToString("N"));
        System.IO.Directory.CreateDirectory(Directory);
    }

    public string Directory { get; }

    public LedgerlyOptions Options => new() { DataDirectory = Directory };

    public string DatabasePath => Options.DatabasePath;

    /// <summary>Builds a new service provider (a fresh "app session") over this directory.</summary>
    public ServiceProvider BuildProvider()
    {
        var services = new ServiceCollection();
        // Satisfy ILogger<T> dependencies without pulling in the full logging package.
        services.AddSingleton(typeof(ILogger<>), typeof(NullLogger<>));
        services.AddLedgerlyInfrastructure(Options);
        return services.BuildServiceProvider();
    }

    public void Dispose()
    {
        try
        {
            if (System.IO.Directory.Exists(Directory))
            {
                System.IO.Directory.Delete(Directory, recursive: true);
            }
        }
        catch (IOException)
        {
            // Best-effort cleanup; WAL/SHM handles may linger briefly on some runners.
        }
    }
}
