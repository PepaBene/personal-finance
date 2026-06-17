using Ledgerly.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.UI.Xaml;
using Serilog;

namespace Ledgerly.App;

/// <summary>
/// Composition root (plan Task 0.2). Builds the generic host, wires Serilog with a
/// local rolling-file sink only (no network sink — NFR-04), and registers the
/// Infrastructure services. Exposes a <see cref="Services"/> accessor for views.
/// </summary>
public partial class App : Application
{
    private readonly IHost _host;
    private Window? _window;

    public App()
    {
        InitializeComponent();

        var options = LedgerlyOptions.Default();
        Directory.CreateDirectory(options.LogsDirectory);

        _host = Host.CreateDefaultBuilder()
            .UseSerilog((_, configuration) => configuration
                .MinimumLevel.Information()
                .WriteTo.File(
                    Path.Combine(options.LogsDirectory, "ledgerly-.log"),
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 14))
            .ConfigureServices(services => services.AddLedgerlyInfrastructure(options))
            .Build();

        Services = _host.Services;
    }

    /// <summary>Service provider for resolving services/view-models from views.</summary>
    public static IServiceProvider Services { get; private set; } = default!;

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.Activate();
    }
}
