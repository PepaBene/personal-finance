namespace Ledgerly.Infrastructure;

/// <summary>
/// Storage locations for the app (docs/03 §7). Defaults to
/// <c>%LOCALAPPDATA%\Ledgerly\</c>; tests override <see cref="DataDirectory"/>
/// with a temporary folder.
/// </summary>
public sealed class LedgerlyOptions
{
    public required string DataDirectory { get; init; }

    public string DatabaseFileName { get; init; } = "ledgerly.db";

    public string SecurityConfigFileName { get; init; } = "security.json";

    public string DatabasePath => Path.Combine(DataDirectory, DatabaseFileName);

    public string SecurityConfigPath => Path.Combine(DataDirectory, SecurityConfigFileName);

    public string LogsDirectory => Path.Combine(DataDirectory, "logs");

    /// <summary>Default location under the user's local app data.</summary>
    public static LedgerlyOptions Default() => new()
    {
        DataDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Ledgerly"),
    };
}
