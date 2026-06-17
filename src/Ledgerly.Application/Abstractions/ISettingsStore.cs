namespace Ledgerly.Application.Abstractions;

/// <summary>Simple key/value settings persisted in the encrypted database (docs/04 §4.4).</summary>
public interface ISettingsStore
{
    Task<string?> GetAsync(string key, CancellationToken cancellationToken = default);

    Task SetAsync(string key, string value, CancellationToken cancellationToken = default);
}
