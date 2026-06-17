using Ledgerly.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;

namespace Ledgerly.App;

/// <summary>
/// Composition root (plan Task 0.2). Builds the generic host, wires Serilog with a
/// local rolling-file sink only (no network sink — NFR-04), and registers the
/// Infrastructure services. Exposes a <see cref="Services"/> accessor for views/pages.
/// </summary>
// NOTE: base type is fully qualified — the unqualified name 'Application' would bind
// to the Ledgerly.Application namespace, not Microsoft.UI.Xaml.Application.
public partial class App : Microsoft.UI.Xaml.Application
{
    private readonly IHost _host;
    private Microsoft.UI.Xaml.Window? _window;

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

    /// <summary>Service provider for resolving services from views/pages.</summary>
    public static IServiceProvider Services { get; private set; } = default!;

    /// <summary>HWND of the main window, needed to initialize file pickers (unpackaged).</summary>
    public static nint WindowHandle { get; internal set; }

    protected override void OnLaunched(Microsoft.UI.Xaml.LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.Activate();
    }
}
